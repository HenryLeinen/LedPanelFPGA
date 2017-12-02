`timescale 1ns / 1ns
//	This module implements the client logic of an LED panel.
//	THe image will be stored externally to this module and the pixel data will be read via avalon MM interfaces s1.
//	Please note that any gamma processing must be inserted between the image memory and this component.
module LedPanelClient_Avalon #(
		//	These are the parameters for configuration of the Led Panel Geometry
		parameter	DISPLAY_ROWS_LINES = 4,			//	16 columns on top and 16 on bottom
		parameter	DISPLAY_COLS_LINES = 6,			//	64 columns per default
		parameter	COLOR_BITS		   = 8
	) 
	(
		/* This is the avalon write port */
		input 	wire				clock,
		input	wire				reset,

		//	This is the Avalon MM slave interface to the  memory for the image data
		input	wire 	[DISPLAY_ROWS_LINES+DISPLAY_COLS_LINES:0]	s1_address,
		input	wire				s1_write,
		input	wire	[31:0]		s1_writedata,

		//	This is the Avalon MM slave interface to the gamma table
		input	wire 	[COLOR_BITS-1:0]	s2_address,
		input	wire				s2_write,
		input	wire	[31:0]		s2_writedata,

		/* Here comes the external signals to the LED */
		output	reg 	[1:0]		led_red,
		output	reg 	[1:0]		led_green,
		output	reg 	[1:0]		led_blue,
		output	reg 	[3:0]		led_addr,
		output	reg  				led_clock,
		output	reg 				led_blank,
		output	reg 				led_latch,

		/* This is an additional optional debug clock input @ 200 MHz */
		input 	wire				ext_clock200,

		/* THis is the condit which connects to the master */
		input wire [DISPLAY_ROWS_LINES+DISPLAY_COLS_LINES-1:0]		memAddrMst,
		input wire [2:0]			bitplaneMst,
		input wire					backbufferMst,

		input wire [3:0]			ADDR_MST,
		input wire					LATCH_MST,
		input wire					CLK_LED_MST,
		input wire					BLANK_MST
);

	//	Internal wires
	wire 	[31:0]				rgb_upper, rgb_lower;
	wire	[COLOR_BITS-1:0]	red_upper, red_lower, green_upper, green_lower, blue_upper, blue_lower;
	reg 	[COLOR_BITS-1:0]	red_upper_q, red_lower_q, green_upper_q, green_lower_q, blue_upper_q, blue_lower_q;
	wire	[COLOR_BITS-1:0]	red_upper_gamma, red_lower_gamma, green_upper_gamma, green_lower_gamma, blue_upper_gamma, blue_lower_gamma;
	wire 	[1:0]				led_red_s, led_green_s, led_blue_s;
	wire	[3:0]				led_addr_s;
	wire						led_clock_s, led_blank_s, led_latch_s;

	//	Second stage buffers to compensate the gamma retrieval
	reg		[1:0]				led_red_q, led_green_q, led_blue_q;
	reg 	[3:0]				led_addr_q;
	reg							led_clock_q, led_blank_q, led_latch_q;

	//	The image memory can be addressed from the avalon MM interface s1. The upper part will be activated upon the zero in the MSB and the lower
	//	image part will be activted upon the one in the MSB. Writing is only possible into the backbuffer.
	wire	wren_upper	= !s1_address[DISPLAY_COLS_LINES+DISPLAY_ROWS_LINES] & s1_write;
	wire	wren_lower	=  s1_address[DISPLAY_COLS_LINES+DISPLAY_ROWS_LINES] & s1_write;

	onchipmem	#(.ADRESS_WIDTH(11)) upper_memory(
		.wrclock(clock),
		.wren(wren_upper),
		.wraddress({backbufferMst, s1_address[DISPLAY_COLS_LINES+DISPLAY_ROWS_LINES-1:0]}),
		.data(s1_writedata),

		.rdclock(ext_clock200),
		.rdaddress({!backbufferMst,memAddrMst}),
		.q(rgb_upper)
	);

	onchipmem	#(.ADRESS_WIDTH(11)) lower_memory(
		.wrclock(clock),
		.wren(wren_lower),
		.wraddress({backbufferMst, s1_address[DISPLAY_COLS_LINES+DISPLAY_ROWS_LINES-1:0]}),
		.data(s1_writedata),

		.rdclock(ext_clock200),
		.rdaddress({!backbufferMst,memAddrMst}),
		.q(rgb_lower)
	);


	//	redirect the memory values to the gamma inputs
	assign	red_upper 		= rgb_upper[COLOR_BITS-1:0];
	assign	red_lower		= rgb_lower[COLOR_BITS-1:0];
	assign	green_upper		= rgb_upper[2*COLOR_BITS-1:COLOR_BITS];
	assign	green_lower		= rgb_lower[2*COLOR_BITS-1:COLOR_BITS];
	assign	blue_upper		= rgb_upper[3*COLOR_BITS-1:2*COLOR_BITS];
	assign 	blue_lower		= rgb_lower[3*COLOR_BITS-1:2*COLOR_BITS];

	//	Instantiate all the gamma values
	onchipmem	#(.ADRESS_WIDTH(COLOR_BITS))	gamma_red_upper(
			.wrclock(clock),
			.wren(s2_write),
			.wraddress(s2_address),
			.data(s2_writedata[COLOR_BITS-1:0]),

			.rdclock(ext_clock200),
			.rdaddress(red_upper),
			.q(red_upper_gamma)
	);
	onchipmem	#(.ADRESS_WIDTH(COLOR_BITS)) gamma_green_upper(
			.wrclock(clock),
			.wren(s2_write),
			.wraddress(s2_address),
			.data(s2_writedata[COLOR_BITS-1:0]),

			.rdclock(ext_clock200),
			.rdaddress(green_upper),
			.q(green_upper_gamma)
	);
	onchipmem	#(.ADRESS_WIDTH(COLOR_BITS))	gamma_blue_upper(
			.wrclock(clock),
			.wren(s2_write),
			.wraddress(s2_address),
			.data(s2_writedata[COLOR_BITS-1:0]),

			.rdclock(ext_clock200),
			.rdaddress(blue_upper),
			.q(blue_upper_gamma)
	);
	onchipmem	#(.ADRESS_WIDTH(COLOR_BITS))	gamma_red_lower(
			.wrclock(clock),
			.wren(s2_write),
			.wraddress(s2_address),
			.data(s2_writedata[COLOR_BITS-1:0]),

			.rdclock(ext_clock200),
			.rdaddress(red_lower),
			.q(red_lower_gamma)
	);
	onchipmem	#(.ADRESS_WIDTH(COLOR_BITS)) gamma_green_lower(
			.wrclock(clock),
			.wren(s2_write),
			.wraddress(s2_address),
			.data(s2_writedata[COLOR_BITS-1:0]),

			.rdclock(ext_clock200),
			.rdaddress(green_lower),
			.q(green_lower_gamma)
	);
	onchipmem	#(.ADRESS_WIDTH(COLOR_BITS))	gamma_blue_lower(
			.wrclock(clock),
			.wren(s2_write),
			.wraddress(s2_address),
			.data(s2_writedata[COLOR_BITS-1:0]),

			.rdclock(ext_clock200),
			.rdaddress(blue_lower),
			.q(blue_lower_gamma)
	);


//	assign	led_red_s		= {red_lower_gamma[bitplaneMst], red_upper_gamma[bitplaneMst]};
//	assign	led_green_s		= {green_lower_gamma[bitplaneMst], green_upper_gamma[bitplaneMst]};
//	assign	led_blue_s 		= {blue_lower_gamma[bitplaneMst], blue_upper_gamma[bitplaneMst]};


	//	put the LED shiftregister values on the bus with the rising edge of the CLK_LED_MST, actual CLK_LED will be delayed by one clock cycle.
	always @(posedge CLK_LED_MST)
		begin
			led_red		<= {red_lower_gamma[bitplaneMst], red_upper_gamma[bitplaneMst]};
			led_green	<= {green_lower_gamma[bitplaneMst], green_upper_gamma[bitplaneMst]};
			led_blue	<= {blue_lower_gamma[bitplaneMst], blue_upper_gamma[bitplaneMst]};
		end

	always @(posedge ext_clock200)
		begin
			if (reset) begin
//				led_red <= 2'b0;
//				led_green <= 2'b0;
//				led_blue <= 2'b0;
				led_addr <= 4'b0;
				led_latch <= 1'b0;
				led_blank <= 1'b1;
				led_clock <= 1'b0;
				led_red_q <= 2'b0;
				led_green_q <= 2'b0;
				led_blue_q <= 2'b0;
				led_latch_q <= 1'b0;
				led_clock_q <= 1'b0;
				led_blank_q <= 1'b0;
			end else  begin
//				led_red <= led_red_s;
//				led_green <= led_green_s;
//				led_blue <= led_blue_s;
				led_addr_q <= ADDR_MST;
				led_clock_q <= CLK_LED_MST;
				led_blank_q <= BLANK_MST;
				led_latch_q <= LATCH_MST;
//				led_red_q	<= {red_lower_gamma[bitplaneMst], red_upper_gamma[bitplaneMst]};
//				led_green_q	<= {green_lower_gamma[bitplaneMst], green_upper_gamma[bitplaneMst]};
//				led_blue_q	<= {blue_lower_gamma[bitplaneMst], blue_upper_gamma[bitplaneMst]};
//				led_red <= led_red_q;
//				led_green <= led_green_q;
//				led_blue <= led_blue_q;
				led_addr <= led_addr_q;
				led_blank <= led_blank_q;
				led_latch <= led_latch_q;
				led_clock <= led_clock_q;
			end
		end

endmodule
