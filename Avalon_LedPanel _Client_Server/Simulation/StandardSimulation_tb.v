`timescale 1ns/1ns
module StandardAnimation_tb ();

	reg			clock_clk;
	reg			reset_rst;
	reg			v_sync;

	reg [2:0]	s0_address;
	reg			s0_write;
	reg			s0_read;
	wire [31:0]	s0_readdata;
	reg [31:0]	s0_writedata;

	reg [1:0]	event_trigger;

	wire 		red1, red2, green1, green2, blue1, blue2;
	reg [5:0]	col1, col2;
	reg [3:0]	row1, row2;
	reg [3:0]	bitplane1, bitplane2;

	//	Instantiate the DUT
	StandardAnimation	#(
		.NUM_REGIONS(2),
		.DISPLAY_ROWS_LINES(4),
		.DISPLAY_COLS_LINES(6),
		.COLOR_BITS(8)
	) DUT(
		.clock_clk(clock_clk),
		.reset_rst(reset_rst),
		.v_sync(v_sync),
		
		.s0_address(s0_address),
		.s0_read(s0_read),
		.s0_readdata(s0_readdata),
		.s0_write(s0_write),
		.s0_writedata(s0_writedata),

		.event_trigger(event_trigger),

		.col1(col1),
		.row1(row1),
		.bitplane1(bitplane1),
		.red1(red1),
		.green1(green1),
		.blue1(blue1),
		.col2(col2),
		.row2(row2),
		.bitplane2(bitplane2),
		.red2(red2),
		.green2(green2),
		.blue2(blue2)
	);

	task writeAvalonMM;
		input  [3:0]	addr;
		input  [31:0]	val;

		begin
			@(negedge clock_clk);
			s0_address = addr;
			s0_write = 1;
			s0_writedata = val;
			@(posedge clock_clk);
			s0_write = 0;
		end
	endtask


	initial
		begin
			reset_rst = 1;
			clock_clk = 0;
			v_sync = 0;
			s0_address = 0;
			s0_write = 0;
			s0_read = 0;
			s0_writedata = 0;
			event_trigger = 2'b0;
		end

	initial
		begin
			forever #2.5 clock_clk = ~clock_clk;
		end

	initial
		begin
			repeat (5) @(posedge clock_clk);

			reset_rst = 0;

			repeat (5) @(posedge clock_clk);

			writeAvalonMM(0, {8'd3, 8'd9, 8'd2, 8'd5});	// Columns: (Start=3, End=9), Rows: (Start=2, End=5)
			writeAvalonMM(1, {8'd0, 8'h55, 8'haa, 8'd255});	// RGB = hFFAA55

			col1 = 0;
			col2 = 0;
			row1 = 0;
			row2 = 3;
			bitplane1 = 0;
			bitplane2 = 0;

			//	Check to see that the FrameCounter will not be changed with inactive event_trigger signal
			event_trigger[0] = 0;
			repeat (5) @(posedge clock_clk);
			v_sync = 1;
			repeat (2) @(posedge clock_clk);
			v_sync = 0;
			repeat (5) @(posedge clock_clk);

			//	Now activate the event trigger signal and initiate two v_sync pulses
			event_trigger[0] = 1;
			repeat (15) @(posedge clock_clk);
			v_sync = 1;
			repeat (2) @(posedge clock_clk);
			v_sync = 0;
			repeat (5) @(posedge clock_clk);
			v_sync = 1;
			repeat (2) @(posedge clock_clk);
			v_sync = 0;
			repeat (5) @(posedge clock_clk);
			
			//	deassert the event_trigger and initiate the v_sync signal three times. THe frame counter should not exceed the
			//	value zero
			event_trigger[0] = 0; 
			repeat (15) @(posedge clock_clk);
			v_sync = 1;
			repeat (2) @(posedge clock_clk);
			v_sync = 0;
			repeat (5) @(posedge clock_clk);
			v_sync = 1;
			repeat (2) @(posedge clock_clk);
			v_sync = 0;
			repeat (5) @(posedge clock_clk);
			v_sync = 1;
			repeat (2) @(posedge clock_clk);
			v_sync = 0;
			repeat (16) @(posedge clock_clk);

//			$print (DUT.FrameCounter_q);
			//	Now start the scanning
			$stop;
		end

	always @(posedge clock_clk) 
		begin
			if (!v_sync) begin
				
			end
		end
endmodule

