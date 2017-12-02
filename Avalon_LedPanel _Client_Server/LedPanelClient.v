`timescale 1ns / 1ns
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.05.2017 19:09:05
// Design Name: 
// Module Name: LedPanel
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module LedPanelClient(
    input   wire        CLK,			//	This shall be a 200 MHz signal
    input   wire        RST,
    output  wire [1:0]  RED,
    output  wire [1:0]  GREEN,
    output  wire [1:0]  BLUE,
    output  wire [3:0]  ADDR,
    output  wire        CLK_LED,
    output  wire        BLANK,
    output  wire        LATCH,
    
    input   wire [DISPLAY_ROWS_LINES + DISPLAY_COLS_LINES:0]   memAddrIn,             //  This gives the address of column and row. PLease note that it does not include front or backbuffer information. That has to be handled externally.
    input   wire [23:0] memDataIn,       														//  Data for the given address for the upper display part
	input   wire		memWrite,																//	This signal indicates valid data on memAddrIn and memDataIn

    input   wire [COLOR_BITS-1:0]   gammaAddrIn,
    input   wire [3*COLOR_BITS-1:0]   gammaDataIn,
    output  wire [3*COLOR_BITS-1:0]   gammaDataOut,
    input   wire                    gammaWrite,
    input   wire                    gammaRead,

    input  wire			backbufferMst,				// this signal indicates which backbuffer to use
    input  wire  [DISPLAY_ROWS_LINES + DISPLAY_COLS_LINES-1:0]  memAddrMst,
    input  wire [2:0]    bitplaneMst,

    //  Re-wire signals from the master
    input  wire [3:0]    ADDR_MST,
    input  wire          CLK_LED_MST,
    input  wire          BLANK_MST,
    input  wire          LATCH_MST
    );
	 
	parameter COLOR_BITS = 8;
	parameter DISPLAY_ROWS_LINES = 4;			//	This is to address 16 lines (we have to address upper and lower by separate memories)
	parameter DISPLAY_COLS_LINES = 6;			//	This is to address 64 columns
    
    wire [COLOR_BITS-1:0]   redUpper, redLower, greenUpper, greenLower, blueUpper, blueLower;
	 
    assign RED[0]   = redUpper[bitplaneMst];
    assign RED[1]   = redLower[bitplaneMst];
    assign GREEN[0] = greenUpper[bitplaneMst];
    assign GREEN[1] = greenLower[bitplaneMst];
    assign BLUE[0]  = blueUpper[bitplaneMst];
    assign BLUE[1]  = blueLower[bitplaneMst];


	wire						memUpperCS = (!memAddrIn[DISPLAY_ROWS_LINES+DISPLAY_COLS_LINES] && memWrite) ? 1'b1 : 1'b0;
	wire						memLowerCS = ( memAddrIn[DISPLAY_ROWS_LINES+DISPLAY_COLS_LINES] && memWrite) ? 1'b1 : 1'b0;

    //  Forward the master signals
    assign ADDR  = ADDR_MST;
    assign CLK_LED = CLK_LED_MST;
    assign BLANK = BLANK_MST;
    assign LATCH = LATCH_MST;


	 //	Instantiate the memories
	 LedPanelMemory	#(
		.ADDR_LINES(DISPLAY_ROWS_LINES + DISPLAY_COLS_LINES+1), 
		.COLOR_BITS(COLOR_BITS)
	 ) UpperMemory (
		.clock(CLK),
		.reset(RST),
		
		.Address_a({backbufferMst, memAddrIn[DISPLAY_ROWS_LINES+DISPLAY_COLS_LINES-1:0]}),
		.DataIn_a(memDataIn),
		.Write_a(memUpperCS),

        .Address_gamma(gammaAddrIn),
        .DataIn_gamma(gammaDataIn),
        .DataOut_gamma(gammaDataOut),
        .Write_gamma(gammaWrite),
        .Read_gamma(gammaRead),
		
		.Address_b({!backbufferMst, memAddrMst}),
        .RedOut_b(redUpper),
        .GreenOut_b(greenUpper),
        .BlueOut_b(blueUpper)
	 );

	 LedPanelMemory	#(
		.ADDR_LINES(DISPLAY_ROWS_LINES + DISPLAY_COLS_LINES+1), 
		.COLOR_BITS(COLOR_BITS)
	 ) LowerMemory (
		.clock(CLK),
		.reset(RST),
		
		.Address_a({backbufferMst, memAddrIn[DISPLAY_ROWS_LINES+DISPLAY_COLS_LINES-1:0]}),
		.DataIn_a(memDataIn),
		.Write_a(memLowerCS),

        .Address_gamma(gammaAddrIn),
        .DataIn_gamma(gammaDataIn),
        .DataOut_gamma(),
        .Write_gamma(gammaWrite),
        .Read_gamma(1'b0),

		.Address_b({!backbufferMst, memAddrMst}),
        .RedOut_b(redLower),
        .GreenOut_b(greenLower),
        .BlueOut_b(blueLower)
	 );
	 
endmodule
