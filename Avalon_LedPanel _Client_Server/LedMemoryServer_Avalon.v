`timescale 1ns / 1ns
module LedPanelServer_Avalon #(
		//	These are the parameters for configuration of the Led Panel Geometry
		parameter	DISPLAY_ROWS_LINES = 4,			//	16 columns on top and 16 on bottom
		parameter	DISPLAY_COLS_LINES = 6,			//	64 columns per default
		parameter	COLOR_BITS		   = 8
	) (
		/* This is the avalon write port */
		input 	wire				clock,
		input	wire				reset,

		//	The s0 System allows access to the control register of the LED panel
		input	wire	[1:0]		s0_address,
		input	wire				s0_write,
		input	wire	[31:0]		s0_writedata,
		input	wire				s0_read,
		output	reg		[31:0]		s0_readdata,
		
		output	wire				irq,
		
		/* This is an additional optional debug clock input @ 200 MHz */
		input 	wire				ext_clock200,

		/* This is the conduit part, chich connects to any clients/slaves */
		output	wire [DISPLAY_COLS_LINES+DISPLAY_ROWS_LINES-1:0]				memAddrMst,
		output	wire [2:0]			bitplaneMst,
		output 	wire 				backbufferMst,

		output	wire [3:0] 			ADDR_MST,
		output  wire				LATCH_MST,
		output  wire				CLK_LED_MST,
		output 	wire				BLANK_MST
	);

	localparam			major_version = 1;
	localparam			minor_version = 5;

	
	//	The vertical sync signal originating from the LedPanel component, will be used to
	//	flip the back buffer and to raise an interrupt request
	//	The backbuffer. Will be used to determine to which portion of the memory to write and read.
	//	Write operations will always be done into the backbuffer, where read operations always acces
	//	the front buffer.
	//	When the software writes a '1' into flip_backbuffer, the hardware will switch the backbuffer at the
	// next v_sync event. In the same moment, the flip_backbuffer flag will be cleared automatically.
	//	Register Map:
	//					| 3 3 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1 
	//	ADDRESS			| 1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0 |	DESCRIPTION
	//	----------------+-----------------------------------------------------------------+------------------------------------------------------------------------------------------
	//	 				|                                                 				  | F = Flip backbuffer command bit, will be 0 after back and front buffers have been flipped
	//		$00			|												  F 0 0 0 0 0 B V | B = Indicates which buffer is currently the backbuffer (read-only)
	//					|																  | V = Will be one after the last scan line has been latched for display (read-only)
	//	----------------+-----------------------------------------------------------------+------------------------------------------------------------------------------------------
	//					|												  I				I |
	//		$01			|												  E 0 0 0 0 0 0 F | IE = Interrupt enable bit
	//					|																  | IL = Interrupt flag (read-only, will be cleared on any write attempt of this register)
	//	----------------+-----------------------------------------------------------------+------------------------------------------------------------------------------------------
	//					| 																  | C = Number of values per color channel supported
	//		$02			| C C C C C C C C C C C C C C C C R R R R R R R R S S S S S S S S | R = Number of rows per pixel panel
	//					|																  | S = Number of columns per pixel panel
	//	----------------+-----------------------------------------------------------------+------------------------------------------------------------------------------------------
	//					|																  |
	//		$03			| H H H H H H H H L L L L L L L L                                 | H = Major version number of this IP
	//					|																  | L = Minor version number of this IP
	//	----------------+-----------------------------------------------------------------+------------------------------------------------------------------------------------------
	reg								backbuffer;
	reg								flip_backbuffer;
	wire							v_sync;
	reg								v_sync_q;
	wire	[7:0]					reg_stat = {flip_backbuffer, 5'b00000, backbuffer, v_sync_q};		// bit 0: v_sync, bit 1: backbuffer, bit 7: flip_backbuffer
	
	//	The interrupt register
	reg		[7:0]					reg_irq;
	wire							irq_ena		= reg_irq[7];
	wire							irq_latch	= reg_irq[0];

	//	V_Sync edge detector
	reg		[1:0]					v_sync_edge_detect;
	reg 							req_backbuffer_flip;
	
	assign 	irq = irq_ena && irq_latch;	//	Only set interrupt if it is enabled

	//	Provide signals to the clients
	assign 	backbufferMst = backbuffer;

	//	Handler for the interrupt request register
	//	Handler for the status register
	always @(posedge clock)
		begin
			if (reset) begin
				backbuffer <= 1'b0;
				flip_backbuffer <= 1'b0;
				reg_irq  <= 8'h00;
			end else begin
				//	if address 1 is being written to, clear the IRQ_LATCH bit and overwrite the IRQ_ENA
				if (s0_address == 2'b01) begin
					if (s0_read) begin
						s0_readdata <= {24'b0, reg_irq};
					end else if (s0_write) begin
						reg_irq[7] 	 <= s0_writedata[7];
						reg_irq[0] <= 1'b0;					//	remove latch on write
					end
				end else if (s0_address == 2'b00) begin
					//	if address 0 is being written, just write to the backbuffer bit
					if (s0_read) begin
						s0_readdata <= {24'b0, reg_stat};
					end else if (s0_write) begin
						flip_backbuffer <= s0_writedata[7];	//	only write backbuffer_flip request (the rest of the register is read only)
					end
				end else if (s0_address == 2'b10) begin
					//	Read out the number of columns and the number of rows per each panel
					if (s0_read) begin
						s0_readdata[7:0] <= 2**DISPLAY_COLS_LINES;
						s0_readdata[15:8]<= 2**DISPLAY_ROWS_LINES;
						s0_readdata[31:16]<= 2**COLOR_BITS;
					end
				end else begin
					if (s0_read) begin
						s0_readdata[31:24] <= major_version;
						s0_readdata[23:16] <= minor_version;
					end
				end
				//	if a v_sync has been detected, write the IRQ_LATCH register
				if (v_sync_edge_detect == 2'b01) begin
					reg_irq[0] <= 1'b1;						//	Set the latch when the vsync is detected
				end
				//	if a backbuffer flip request was filed, and the v_sync occured, flip the backbuffer and remove the backbuffer flip request
				if (req_backbuffer_flip) begin
					backbuffer <= ~backbuffer;
					flip_backbuffer <= 0;
				end
			end
		end
	
		//	Process the automatic backbuffer flipping request, on each positive v_sync edge, only if the 'flip_backbuffer' flag is set
		always @(posedge ext_clock200)
			begin
				if (reset) begin
					req_backbuffer_flip <= 1'b0;
					v_sync_q <= 1'b0;
					v_sync_edge_detect <= 2'b00;
				end else begin
					v_sync_q <= v_sync;
					//	Perform edge detection on v_sync signal
					v_sync_edge_detect <= {v_sync_edge_detect[0], v_sync_q};
					if ((v_sync_edge_detect == 2'b01) && (flip_backbuffer) ) begin
							req_backbuffer_flip <= 1'b1;
					end else if (req_backbuffer_flip && !flip_backbuffer) begin
						req_backbuffer_flip <= 1'b0;
					end
				end
			end
	
		LedPanelServer #(
			.COLOR_BITS(COLOR_BITS),
			.DISPLAY_ROWS_LINES(DISPLAY_ROWS_LINES),
			.DISPLAY_COLS_LINES(DISPLAY_COLS_LINES)
		)		panel(
		.CLK(ext_clock200),
		.RST(reset),
	
		.ADDR_MST(ADDR_MST),
		.CLK_LED_MST(CLK_LED_MST),
		.BLANK_MST(BLANK_MST),
		.LATCH_MST(LATCH_MST),
		
		.v_sync(v_sync),
		.memAddrMst(memAddrMst),
		.bitplaneMst(bitplaneMst)
	);



endmodule
