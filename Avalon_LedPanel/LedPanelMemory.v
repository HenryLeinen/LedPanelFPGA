module LedPanelMemory(
	input wire		clock,
	input wire		reset,
	
	input wire	[ADDR_LINES-1:0]		Address_a,
	input wire	[DATA_LINES-1:0]		DataIn_a,
	input wire								Write_a,
	
	input wire	[ADDR_LINES-1:0]		Address_b,
	output reg [DATA_LINES-1:0]		DataOut_b
);

	parameter ADDR_LINES	= 10;
	parameter DATA_LINES = 24;
	
	
	//	The memory
	reg	[DATA_LINES-1:0]		memory[(1<<ADDR_LINES)-1:0];
	
	
	always @(posedge clock)
		begin
			if (reset) begin
				DataOut_b <= {DATA_LINES{1'bZ}};
			end else begin
				if (Write_a) begin
					memory[Address_a] <= DataIn_a;
				end
				DataOut_b <=  memory[Address_b];
			end
		end
	

endmodule
