module LedPanel_Avalon (
	/* This is the avalon write port */
	input 	wire				clock200,
	input		wire				reset,

	//	The s0 System allows access to the control register of the LED panel
	input		wire				s0_address,
	input		wire				s0_write,
	input		wire	[31:0]	s0_writedata,
	input		wire				s0_read,
	output	reg	[31:0]	s0_readdata,
	
	output	wire				irq,
	
	//	The s1 system allow write only access to the LedPanel memory
	//	When the MSB of the address is set, the Upper Part of the display is addressed, otherwise the lower part is addressed
	input		wire 	[DISPLAY_ROWS_LINES+DISPLAY_COLS_LINES:0]	s1_address,
	input		wire				s1_write,
	input		wire	[31:0]	s1_writedata,

	
	/* Here comes the external signals to the LED */
	output	wire	[1:0]		led_red,
	output	wire	[1:0]		led_green,
	output	wire	[1:0]		led_blue,
	output	wire	[3:0]		led_addr,
	output	wire 				led_clock,
	output	wire				led_blank,
	output	wire				led_latch,

	/* This is an additional optional debug clock input @ 200 MHz */
	input 	wire				debug_clock
);

	//	These are the parameters for configuration of the Led Panel Geometry
	parameter	DISPLAY_ROWS_LINES = 4;			//	16 columns on top and 16 on bottom
	parameter	DISPLAY_COLS_LINES = 6;			//	64 columns per default
	parameter	COLOR_BITS			 = 8;

	
	//	The vertical sync signal originating from the LedPanel component, will be used to
	//	flip the back buffer and to raise an interrupt request
	//	The backbuffer. Will be used to determine to which portion of the memory to write and read.
	//	Write operations will always be done into the backbuffer, where read operations always acces
	//	the front buffer.
	//	When the software writes a '1' into flip_backbuffer, the hardware will switch the backbuffer at the
	// next v_sync event. In the same moment, the flip_backbuffer flag will be cleared automatically.
	reg							backbuffer;
	reg							flip_backbuffer;
	wire							v_sync;
	wire	[7:0]					reg_stat = {flip_backbuffer, 5'b00000, backbuffer, v_sync};		// bit 0: v_sync, bit 1: backbuffer, bit 7: flip_backbuffer
	
	//	The interrupt register
	reg	[7:0]					reg_irq;
	wire	irq_ena		= reg_irq[7];
	wire	irq_latch	= reg_irq[0];

	//	V_Sync edge detector
	reg	[1:0]					v_sync_edge_detect;
	reg 							req_backbuffer_flip;
	
	assign irq = irq_ena && irq_latch;	//	Only set interrupt if it is enabled
	
	//	Handler for the interrupt request register
	//	Handler for the status register
	always @(posedge clock200)
		begin
			if (reset) begin
				backbuffer <= 1'b0;
				flip_backbuffer <= 1'b0;
				reg_irq  <= 8'h00;
				v_sync_edge_detect <= 2'b00;
			end else begin
				//	Perform edge detection on v_sync signal
				v_sync_edge_detect <= {v_sync_edge_detect[0], v_sync};
				//	if address 1 is being written to, clear the IRQ_LATCH bit and overwrite the IRQ_ENA
				if (s0_address) begin
					if (s0_read) begin
						s0_readdata <= {24'b0, reg_irq};
					end else if (s0_write) begin
						reg_irq[7] 	 <= s0_writedata[7];
						reg_irq[0] <= 1'b0;					//	remove latch on write
					end
				end else begin
					//	if address 0 is being written, just write to the backbuffer bit
					if (s0_read) begin
						s0_readdata <= {24'b0, reg_stat};
					end else if (s0_write) begin
						flip_backbuffer <= s0_writedata[7];	//	only write backbuffer_flip request (the rest of the register is read only)
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
		always @(posedge debug_clock)
			begin
				if (reset) begin
					req_backbuffer_flip <= 1'b0;
				end else begin
					if ((v_sync_edge_detect == 2'b01) && (flip_backbuffer) ) begin
							req_backbuffer_flip <= 1'b1;
					end else req_backbuffer_flip <= 1'b0;
				end
			end
	
		LedPanel #(
			.COLOR_BITS(COLOR_BITS),
			.DISPLAY_ROWS_LINES(DISPLAY_ROWS_LINES),
			.DISPLAY_COLS_LINES(DISPLAY_COLS_LINES)
		)		panel(
		.CLK(debug_clock),
		.RST(reset),
	
		.RED(led_red),
		.GREEN(led_green),
		.BLUE(led_blue),
		.ADDR(led_addr),
		.CLK_LED(led_clock),
		.BLANK(led_blank),
		.LATCH(led_latch),
		
		.memAddrIn(s1_address),
		.memDataIn(s1_writedata[23:0]),
		.memWrite(s1_write),
		.v_sync(v_sync),
		.backbuffer(backbuffer)
	);



endmodule
