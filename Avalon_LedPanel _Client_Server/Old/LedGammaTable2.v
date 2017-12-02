// new_component.v

// This file was auto-generated as a prototype implementation of a module
// created in component editor.  It ties off all outputs to ground and
// ignores all inputs.  It needs to be edited to make it do something
// useful.
// 
// This file will not be automatically regenerated.  You should check it in
// to your version control system if you want to keep it.

`timescale 1 ns / 1 ns
module GammaTable #(
		parameter COLOR_BITS_IN  = 8,
		parameter COLOR_BITS_OUT = 8,
		parameter NUMBER_CLIENTS = 1
	) (
		input  wire [COLOR_BITS_IN-1:0] avalon_slave_address,   // avalon_slave.address
		input  wire       avalon_slave_read,      //             .read
		output wire [COLOR_BITS_OUT-1:0] avalon_slave_readdata,  //             .readdata
		input  wire       avalon_slave_write,     //             .write
		input  wire [COLOR_BITS_OUT-1:0] avalon_slave_writedata, //             .writedata
		input  wire       reset_reset,            //        reset.reset
		input  wire       clock_clk,              //        clock.clk

		input  wire [3*COLOR_BITS_IN-1:0] rgb1_in,                 // conduit_set1.rgb_in
		input  wire [3*COLOR_BITS_OUT-1:0] rgb1_out,                 //             .rgb_out

		input  wire [3*COLOR_BITS_IN-1:0] rgb2_in,                 // conduit_set2.rgb_in
		input  wire [3*COLOR_BITS_OUT-1:0] rgb2_out                 //             .rgb_out
	);

	//	Implement the look up table
	reg 	[COLOR_BITS_OUT-1:0]			lut[(1<<COLOR_BITS_IN)-1:0];

	//	Static logic for RGB1 (conduit_set1)
	wire	[COLOR_BITS_IN-1:0]		red1_in, green1_in, blue1_in;
	wire	[COLOR_BITS_OUT-1:0]	red1_out, green1_out, blue1_out;
	assign red1_in = rgb1_in[COLOR_BITS-1:0];
	assign green1_in = rgb1_in[2*COLOR_BITS-1:COLOR_BITS];
	assign blue1_in = rgb1_in[3*COLOR_BITS-1:2*COLOR_BITS];
	assign red1_out = lut[red1_in];
	assign green1_out = lut[green1_in];
	assign blue1_out = lut[blue1_in];
	assign rgb1_out = {blue1_out, green1_out, red1_out};

	//	Static logic for RGB2 (conduit_set2)
	wire	[COLOR_BITS_IN-1:0]		red2_in, green2_in, blue2_in;
	wire	[COLOR_BITS_OUT-1:0]	red2_out, green2_out, blue2_out;
	assign red2_in = rgb2_in[COLOR_BITS-1:0];
	assign green2_in = rgb2_in[2*COLOR_BITS-1:COLOR_BITS];
	assign blue2_in = rgb2_in[3*COLOR_BITS-1:2*COLOR_BITS];
	assign red2_out = lut[red2_in];
	assign green2_out = lut[green2_in];
	assign blue2_out = lut[blue2_in];
	assign rgb2_out = {blue2_out, green2_out, red2_out};

	//	Implement avalon MM memory access
	always @(posedge clock_clk)
		begin
			if (reset_reset) begin
			  	avalon_slave_readdata <= {COLOR_BITS_OUT{1'bZ}};
			end else begin

				if (avalon_slave_read)
					avalon_slave_readdata <= lut[avalon_slave_address];
				else begin
					avalon_slave_readdata <= {COLOR_BITS_OUT{1'bZ}};
				end
				if (avalon_slave_write) begin
					lut[avalon_slave_address] <= avalon_slave_writedata;
				end
			end
		end
endmodule
