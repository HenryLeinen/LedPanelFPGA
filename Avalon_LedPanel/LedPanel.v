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


module LedPanel(
    input wire CLK,			//	This shall be a 200 MHz signal
    input wire RST,
    output wire [1:0] RED,
    output wire [1:0] GREEN,
    output wire [1:0] BLUE,
    output reg [3:0] ADDR,
    output reg CLK_LED,
    output reg BLANK,
    output reg LATCH,
    
    input wire[DISPLAY_ROWS_LINES + DISPLAY_COLS_LINES:0]   memAddrIn,             //  This gives the address of column and row. PLease note that it does not include front or backbuffer information. That has to be handled externally.
    input wire [23:0]   memDataIn,       														//  Data for the given address for the upper display part
	 input wire				memWrite,																//	This signal indicates valid data on memAddrIn and memDataIn
    
    output reg          v_sync,             //  This output pulses as soon as the last row and column has been taken from memory. It signals that the framebuffers can be switched.
    input  wire			backbuffer				// this signal indicates which backbuffer to use
    );
	 
	 parameter COLOR_BITS = 8;
	 parameter DISPLAY_ROWS_LINES = 4;			//	This is to address 16 lines (we have to address upper and lower by separate memories)
	 parameter DISPLAY_COLS_LINES = 6;			//	This is to address 64 columns
    
    //  50 MHz Clock generation out of 200 MHz clock
    reg [1:0]           clkReg;
    wire                CLK_50 = clkReg[1];
    
    //  Implement the access to memory and the led ids
    reg [DISPLAY_COLS_LINES-1:0]           col;            //  The actual column in use
    reg [DISPLAY_ROWS_LINES-1:0]           row;            //  The actual row in use (actually there are always two rows in use, one in the upper part and the other one in the lower part
    reg [2:0]           bitplane;       //  The actual bitplane currently in use
    
    wire [COLOR_BITS-1:0]          redUpper, redLower, greenUpper, greenLower, blueUpper, blueLower;
    wire [3*COLOR_BITS-1:0]			memDataUpper, memDataLower;
	wire [DISPLAY_COLS_LINES+DISPLAY_ROWS_LINES-1:0]	memAddr;
	 
    assign redUpper         = memDataUpper[COLOR_BITS-1:0];
    assign redLower         = memDataLower[COLOR_BITS-1:0];
    assign greenUpper       = memDataUpper[2*COLOR_BITS-1:COLOR_BITS];
    assign greenLower       = memDataLower[2*COLOR_BITS-1:COLOR_BITS];
    assign blueUpper        = memDataUpper[3*COLOR_BITS-1:2*COLOR_BITS];
    assign blueLower        = memDataLower[3*COLOR_BITS-1:2*COLOR_BITS];
    
    assign RED[0]   = redUpper[bitplane];
    assign RED[1]   = redLower[bitplane];
    assign GREEN[0] = greenUpper[bitplane];
    assign GREEN[1] = greenLower[bitplane];
    assign BLUE[0]  = blueUpper[bitplane];
    assign BLUE[1]  = blueLower[bitplane];


    localparam          s_00      = 2'b00,
                        s_01      = 2'b01,
                        s_10      = 2'b10,
                        s_11      = 2'b11;

    localparam          s_UNBLANK = 3'b000,
                        s_WAIT    = 3'b001,
                        s_BLANK   = 3'b010,
                        s_LATCH   = 3'b011,
                        s_DELATCH = 3'b100;

    reg [2:0]           state;
    reg                 sig_shifting_ready;
    reg                 shifting_ena;           //  enable shift register
    reg [13:0]          display_counter;                        
    reg [DISPLAY_ROWS_LINES-1:0]           old_addr;

    assign              memAddr = {row, col};
    
	 wire						memUpperCS = (!memAddrIn[DISPLAY_ROWS_LINES+DISPLAY_COLS_LINES] && memWrite) ? 1'b1 : 1'b0;
	 wire						memLowerCS = ( memAddrIn[DISPLAY_ROWS_LINES+DISPLAY_COLS_LINES] && memWrite) ? 1'b1 : 1'b0;
	 
	 //	Instantiate the memories
	 LedPanelMemory	#(
		.ADDR_LINES(DISPLAY_ROWS_LINES + DISPLAY_COLS_LINES+1), 
		.DATA_LINES(3*COLOR_BITS)
	 ) UpperMemory (
		.clock(CLK),
		.reset(RST),
		
		.Address_a({backbuffer, memAddrIn[DISPLAY_ROWS_LINES+DISPLAY_COLS_LINES-1:0]}),
		.DataIn_a(memDataIn),
		.Write_a(memUpperCS),
		
		.Address_b({!backbuffer, memAddr}),
		.DataOut_b(memDataUpper)
	 );

	 LedPanelMemory	#(
		.ADDR_LINES(DISPLAY_ROWS_LINES + DISPLAY_COLS_LINES+1), 
		.DATA_LINES(3*COLOR_BITS)
	 ) LowerMemory (
		.clock(CLK),
		.reset(RST),
		
		.Address_a({backbuffer, memAddrIn[DISPLAY_ROWS_LINES+DISPLAY_COLS_LINES-1:0]}),
		.DataIn_a(memDataIn),
		.Write_a(memLowerCS),
		
		.Address_b({!backbuffer, memAddr}),
		.DataOut_b(memDataLower)
	 );
	 
	 
    //  Generate the 50 MHz clock signal for the state machine, but phase shift the edges, so that we get new memory data a little delayed
    always @(negedge CLK)   
        begin
            case (clkReg)
                2'b00:      clkReg = 2'b01;
                2'b01:      clkReg = 2'b10;
                2'b10:      clkReg = 2'b11;
                2'b11:      clkReg = 2'b00;
                default:    clkReg = 2'b00;
            endcase
        end

    //  Implement the shift register
    always @(posedge CLK_50)
        begin
            if (RST) begin
                col = {DISPLAY_COLS_LINES{1'b0}};
                row = {DISPLAY_ROWS_LINES{1'b0}};
                CLK_LED <= 0;
                bitplane = 3'b000;
                sig_shifting_ready <= 0;
                v_sync <= 0;
            end else begin
                CLK_LED <= 0;
                v_sync <= 0;
                if (state == s_WAIT) begin
                    if ((shifting_ena == 1) && (sig_shifting_ready == 0) ) begin        //  only run in WAIT mode
                        if (CLK_LED == 1) begin
                            //  Advance to next column
                            col = col + 1;
                            if (col == 0) begin
                                sig_shifting_ready <= 1;
                                //  All columns clocked, so advance to next bitplane
                                bitplane = bitplane + 1;
                                if (bitplane == 0) begin
                                    //  All bitplanes clocked, so advance to next row
                                    row = row + 1;
                                    if (row == 0) begin
                                        //  Full frame displayed, indicate that
                                        v_sync <= 1;
                                    end                            
                                end
                            end
                        end
                        CLK_LED <= ~CLK_LED;
                    end
                end else sig_shifting_ready <= 0;

            end
        end
        
    //  Implement the BLANK signal
    always @(posedge CLK_50)
        begin
            if (RST) begin
                BLANK <= 0;
                ADDR = {DISPLAY_ROWS_LINES{1'b0}};
                old_addr = 0;
            end else begin
                if (state == s_BLANK) begin 
                    BLANK <= 1;
                    ADDR = old_addr;
                    old_addr = row;
                end else if (state == s_UNBLANK) begin
                    BLANK <= 0;
                end
            end
        end

    //  Implement the LATCH signal
    always @(posedge CLK_50)
        begin
            if (RST)
                LATCH <= 1'b1;
            else begin
                if (state == s_LATCH)
                    LATCH <= 1'b1;
                else if (state == s_DELATCH)
                    LATCH <= 1'b0;
            end
        end
                
    reg sig_wait_done;
    
    //  Implement the wait counter to display a single line of LEDs
    always @(posedge CLK_50)
        begin
            if (RST) begin
                display_counter <= 123;		//	counter setting for @200Hz
                shifting_ena <= 0;
                sig_wait_done <= 0;
            end else if (state == s_WAIT) begin
                if (display_counter != 0) begin
                    display_counter <= display_counter - 1;
                end else if (sig_shifting_ready) begin
                        shifting_ena <= 0;
                        sig_wait_done <= 1;
                end 
            end else if (state == s_UNBLANK) begin
                case (bitplane)
                    0:  display_counter = 122 << 7;     //  valid @ 200MHz
                    1:  display_counter = 122 << 0;
                    2:  display_counter = 122 << 1;
                    3:  display_counter = 122 << 2;
                    4:  display_counter = 122 << 3;
                    5:  display_counter = 122 << 4;
                    6:  display_counter = 122 << 5;
                    7:  display_counter = 122 << 6;
                    default: display_counter = 122 << 0;
                endcase
                shifting_ena <= 1;
            end else sig_wait_done <= 0;
        end
        
    //  Implement the state maching
    always @(posedge CLK_50)
        begin
            if (RST) begin  state <= s_UNBLANK;
            end else begin
                case    (state)
                    s_UNBLANK:  state <= s_WAIT;
                        
                    s_WAIT:     if (sig_wait_done == 1) state <= s_BLANK;
                        
                    s_BLANK:    state <= s_LATCH;
                    
                    s_LATCH:    state <= s_DELATCH;
                        
                    s_DELATCH:  state <= s_UNBLANK;
                endcase
            end 
        end
endmodule
