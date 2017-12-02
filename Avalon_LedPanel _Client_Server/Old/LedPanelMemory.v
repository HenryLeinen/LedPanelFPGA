`timescale 1ns / 1ns
module LedPanelMemory(
	input wire							clock,
	input wire							reset,
	
	input wire	[ADDR_LINES-1:0]		Address_a,
	input wire	[3*COLOR_BITS-1:0]		DataIn_a,
	input wire							Write_a,
	
	input wire  [COLOR_BITS-1:0]		Address_gamma,
	input wire  [3*COLOR_BITS-1:0]		DataIn_gamma,
	output reg  [3*COLOR_BITS-1:0]		DataOut_gamma,
	input wire							Write_gamma,
	input wire							Read_gamma,

	input wire	[ADDR_LINES-1:0]		Address_b,

	output reg   [COLOR_BITS-1:0]		RedOut_b,
	output reg   [COLOR_BITS-1:0]		GreenOut_b,
	output reg   [COLOR_BITS-1:0]		BlueOut_b
);

	parameter ADDR_LINES = 10;
	parameter COLOR_BITS = 8;
	
	
	//	The memory
	reg	[3*COLOR_BITS-1:0]		memory[(1<<ADDR_LINES)-1:0];

	//	The gamma table
	reg [COLOR_BITS-1:0]		gamma_red  [(1<<COLOR_BITS)-1:0];
	reg [COLOR_BITS-1:0]		gamma_green[(1<<COLOR_BITS)-1:0];
	reg [COLOR_BITS-1:0]		gamma_blue [(1<<COLOR_BITS)-1:0];

	//	For testing purposes, the memory will be filled with zeros
	integer k;
	initial 
		begin
			for(k=0;k< (1<<ADDR_LINES); k = k + 1)
				memory[k] = k;
		end	
	initial
		begin
			for(k=0; k< (1<<COLOR_BITS); k = k + 1)
				begin
					gamma_red[k] = k;
					gamma_blue[k] = k;
					gamma_green[k] = k;
				end
		end

//	wire [3*COLOR_BITS-1:0] rgb;
	reg [3*COLOR_BITS-1:0] rgb;
//	wire [COLOR_BITS-1:0] red, green, blue;

//	assign rgb = memory[Address_b];
//	assign red = rgb[COLOR_BITS-1:0];
//	assign green = rgb[2*COLOR_BITS-1:COLOR_BITS];
//	assign blue = rgb[3*COLOR_BITS-1:2*COLOR_BITS];

//	assign RedOut_b = gamma_red[red];
//	assign GreenOut_b = gamma_green[green];
//	assign BlueOut_b = gamma_blue[blue];

	always @(posedge clock)
		begin
			if (reset) begin
				RedOut_b = {COLOR_BITS{1'b0}};
				BlueOut_b = {COLOR_BITS{1'b0}};
				GreenOut_b = {COLOR_BITS{1'b0}};
			end else begin
				if (Write_a) begin
					memory[Address_a] = DataIn_a;
				end
				rgb = memory[Address_b];
				RedOut_b = gamma_red[rgb[COLOR_BITS-1:0]];
				GreenOut_b = gamma_green[rgb[2*COLOR_BITS-1:COLOR_BITS]];
				BlueOut_b = gamma_blue[rgb[3*COLOR_BITS-1:2*COLOR_BITS]];
			end
		end

	//	Implement access to gamma memory
	always @(posedge clock)
		begin
			if (reset) begin
				DataOut_gamma <= {COLOR_BITS{1'bZ}};
			end else begin
				if (Write_gamma)
					begin
						gamma_red[Address_gamma[COLOR_BITS-1:0]] <= DataIn_gamma[COLOR_BITS-1:0];
						gamma_green[Address_gamma[COLOR_BITS-1:0]] <= DataIn_gamma[(2*COLOR_BITS)-1:COLOR_BITS];
						gamma_blue[Address_gamma[COLOR_BITS-1:0]] <= DataIn_gamma[(3*COLOR_BITS)-1:2*COLOR_BITS];
					end
				if (Read_gamma)
					DataOut_gamma <= {gamma_blue[Address_gamma[COLOR_BITS-1:0]], gamma_green[Address_gamma[COLOR_BITS-1:0]], gamma_red[Address_gamma[COLOR_BITS-1:0]]};
				else
					DataOut_gamma <= {COLOR_BITS{1'bZ}};
			end
		end	

endmodule
