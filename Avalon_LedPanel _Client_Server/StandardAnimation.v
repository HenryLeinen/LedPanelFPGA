`timescale 1ns / 1ns
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.05.2017 19:09:05
// Design Name: 
// Module Name: StandardAnimation
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
//  This module knows 4 types of animations :
//      1. Step On/Off  --> Switches on with input, switches off with input
//      2. Dim On/Off --> Dimms the area on with input, dimms the are off with input, <DimmingSlope> is a parameter, which specifies how fast dimming on and off is
//      3. Slide On/Off --> Slides from outside into the area with input on, slides to outside with input off, <SlideDirection>, <DimmingSlope> and <SlidingSpeed> are parameters
//      4. Pulsing  --> Pulses while input is on, <PulseFrequency>, <DimmingSlope> are parameters
//      5. Waving --> Waves while input is on, <SlideDirection>, <PulseFrequency> are parameters
//////////////////////////////////////////////////////////////////////////////////


module StandardAnimation #(
        parameter   NUM_REGIONS = 5,
		parameter	DISPLAY_ROWS_LINES = 4,			//	16 columns on top and 16 on bottom
		parameter	DISPLAY_COLS_LINES = 6,			//	64 columns per default
		parameter	COLOR_BITS		   = 8
    ) (
    input wire              clock_clk,
    input wire              v_sync,           //  This is the v_sync and gives the timebasis for the animations
    input wire              reset_rst,

    //  This is the avalon MM interface for the registers
    input wire [2:0]        s0_address,
    input wire              s0_read,
    output reg [31:0]       s0_readdata,
    input wire              s0_write,
    input wire [31:0]       s0_writedata,

    //  The trigger input(s)
    input wire [NUM_REGIONS-1:0]    event_trigger,

    input wire [DISPLAY_COLS_LINES-1:0]             col1,
    input wire [DISPLAY_ROWS_LINES-1:0]             row1,
    input wire [3:0]                                bitplane1,
    output reg                                      red1,
    output reg                                      green1,
    output reg                                      blue1,

    input wire [DISPLAY_COLS_LINES-1:0]             col2,
    input wire [DISPLAY_ROWS_LINES-1:0]             row2,
    input wire [3:0]                                bitplane2,
    output reg                                      red2,
    output reg                                      green2,
    output reg                                      blue2

);

    ////////////////////////////////////////////
    //  Register layout:
    // --------------------
    //  $00:    <StartColumn>, <EndColumn>, <StartRow>, <EndRow>
    //  $01:    <LightColorB>, <LightColorG>, <LightColorR>
    //  $02:    <AnimationType>
    //  $03:    <ParameterSlope>
    //  $04:    <ParameterFrequency>
    //  $05:    <ParameterDirection>
    //  $06:    <ParameterSpeed>
    reg [7:0]           RegStartColumn, RegEndColumn, RegStartRow, RegEndRow;
    reg [7:0]           RegLightColorR, RegLightColorG, RegLightColorB;
    reg [7:0]           RegAnimationType;
    reg [31:0]          RegParameterSlope;
    reg [31:0]          RegParameterFrequency;
    reg [31:0]          RegParameterDirection;
    reg [31:0]          RegParameterSpeed;


    // Implement Avalon MM Register access (aaaaaand I'm doing it the complicated way :-( )
    always @(posedge clock_clk) 
        begin
            if (reset_rst) begin
                RegStartColumn  <= 8'b0;
                RegEndColumn    <= 8'b0;
                RegStartRow     <= 8'b0;
                RegEndRow       <= 8'b0;
                RegLightColorB  <= 8'b0;
                RegLightColorG  <= 8'b0;
                RegLightColorR  <= 8'b0;
                RegAnimationType<= 8'b0;
                RegParameterSlope <= 32'b0;
                RegParameterFrequency <= 32'b0;
                RegParameterSpeed <= 32'b0;
                RegParameterDirection <= 32'b0;
            end else begin
                if (s0_write) begin
                    case (s0_address)
                        3'd0:   
                            begin
                                RegStartColumn      <= s0_writedata[31:24]; 
                                RegEndColumn        <= s0_writedata[23:16]; 
                                RegStartRow         <= s0_writedata[15:8]; 
                                RegEndRow           <= s0_writedata[7:0];
                            end
                        3'd1:
                            begin
                                RegLightColorR      <= s0_writedata[7:0];
                                RegLightColorG      <= s0_writedata[15:8];
                                RegLightColorB      <= s0_writedata[23:16];
                            end
                        3'd2:
                            begin
                                RegAnimationType    <= s0_writedata[7:0];
                            end
                        3'd3:
                            begin
                                RegParameterSlope   <= s0_writedata;
                            end
                        3'd4:
                            begin
                                RegParameterFrequency <= s0_writedata;
                            end
                        3'd5:
                            begin
                                RegParameterDirection <= s0_writedata;
                            end
                        3'd6:
                            begin
                                RegParameterSpeed   <= s0_writedata;                              
                            end
                    endcase
                end
            end
        end

    always @(posedge clock_clk) 
        begin
            if (reset_rst) begin
                s0_readdata <= 32'b0;
            end else begin
                s0_readdata <= 32'b0;
                if (s0_read) begin
                    case (s0_address)
                        3'd0:   s0_readdata <= {RegStartColumn, RegEndColumn, RegStartRow, RegEndRow};
                        3'd1:   s0_readdata <= {8'b0, RegLightColorB, RegLightColorG, RegLightColorR};
                        3'd2:   s0_readdata <= {24'b0, RegAnimationType};
                        3'd3:   s0_readdata <= RegParameterSlope;
                        3'd4:   s0_readdata <= RegParameterFrequency;
                        3'd5:   s0_readdata <= RegParameterDirection;
                        3'd6:   s0_readdata <= RegParameterSpeed;
                        default:    s0_readdata <= 32'b0;
                    endcase
                end
            end
      
        end

    //////////////////////////////////////////////////////////////////
    //  Functional implementation
    //  the function waits for a v_sync positive edge.
    //  After the positive edge is detected, the system will activate the right function
    //  The function will iterate through
    reg [7:0]           RegStartColumn_q, RegEndColumn_q, RegStartRow_q, RegEndRow_q;
    reg [7:0]           RegLightColorR_q, RegLightColorG_q, RegLightColorB_q;
    reg [7:0]           FrameCount_d, FrameCount_q;
    reg [1:0]           v_sync_edge_detect_d,v_sync_edge_detect_q;

    wire                cs_col1, cs_row1;
    assign              cs_col1 = (col1 >= RegStartColumn_q) && (col1 <= RegEndColumn_q);
    assign              cs_row1 = (row1 >= RegStartRow_q   ) && (row1 <= RegEndRow_q);
    wire                cs1 = cs_col1 && cs_row1;
    wire                cs_col2, cs_row2;
    assign              cs_col2 = (col2 >= RegStartColumn_q) && (col2 <= RegEndColumn_q);
    assign              cs_row2 = (row2 >= RegStartRow_q   ) && (row2 <= RegEndRow_q);
    wire                cs2 = cs_col2 && cs_row2;

//  Implement the v_sync_edge detector
    always @(*)
        begin
            if (reset_rst) begin
                v_sync_edge_detect_d <= 2'b0;
            end else begin
                v_sync_edge_detect_d <= {v_sync_edge_detect_q[0], v_sync};
            end
        end

    always @(posedge clock_clk)
        begin
            if (reset_rst) begin
                v_sync_edge_detect_q <= 2'b0;
            end else begin
                v_sync_edge_detect_q <= v_sync_edge_detect_d;
            end
        end

//  Implement the frame counter, the frame counter starts to count forward, if the event is high.
//  Count will be implemented with each edge of v_sync
    always @(*)
        begin
            if (reset_rst) begin
                FrameCount_d <= 0;
            end else begin
                FrameCount_d <= FrameCount_q;
                if (v_sync_edge_detect_q == 2'b01) begin
                    if (event_trigger[0]) begin
                            FrameCount_d <= FrameCount_q + 1;
                    end else begin
                        if (FrameCount_q !=0) 
                            FrameCount_d <= FrameCount_q - 1;
                    end
                end
            end
        end

    always @(posedge clock_clk)
        begin
            if (reset_rst) begin
                FrameCount_q <= 0;
            end else begin
                FrameCount_q <= FrameCount_d;
            end
        end

    always @(posedge clock_clk) 
        begin
            if (reset_rst) begin
            end else begin
                if (v_sync) begin   //   during the 'high' phase of v_sync, copy the new parameters
                    RegStartColumn_q    <= RegStartColumn;
                    RegEndColumn_q      <= RegEndColumn;
                    RegStartRow_q       <= RegStartRow;
                    RegEndRow_q         <= RegEndRow;
                    RegLightColorB_q    <= RegLightColorB;
                    RegLightColorG_q    <= RegLightColorG;
                    RegLightColorR_q    <= RegLightColorR;
                end else begin
                end 
            end
        end

`ifdef (0)
/////////////// ANIMATION 01: STEP ON / STEP OFF
    always @(posedge clock_clk) 
        begin
            if (reset_rst) begin
                red1 <= 0;
                green1 <= 0;
                blue1 <= 0; 
            end else begin
                red1 <= 0;
                green1 <= 0;
                blue1 <= 0;
                if (cs1) begin       //  This region has been activated
                    if (event_trigger[0]) begin
                        red1 <= RegLightColorR_q[bitplane1];
                        green1 <= RegLightColorG_q[bitplane1];
                        blue1 <= RegLightColorB_q[bitplane1];
                    end 
                end 
            end
        end

    always @(posedge clock_clk) 
        begin
            if (reset_rst) begin
                red2 <= 0;
                green2 <= 0;
                blue2 <= 0;
            end else begin
                red2 <= 0;
                green2 <= 0;
                blue2 <= 0;
                if (cs2) begin      //  This region has been activated
                    if (event_trigger[0]) begin
                        red2 <= RegLightColorR_q[bitplane2];
                        green2 <= RegLightColorG_q[bitplane2];
                        blue2 <= RegLightColorB_q[bitplane2];
                    end
                end
            end
        end
`endif

/////////////// ANIMATION 02: DIM ON / DIM OFF
    always @(posedge clock_clk) 
        begin
            if (reset_rst) begin
                red1 <= 0;
                green1 <= 0;
                blue1 <= 0; 
            end else begin
                red1 <= 0;
                green1 <= 0;
                blue1 <= 0;
                if (cs1) begin       //  This region has been activated
                    if (event_trigger[0]) begin
                        red1 <= RegLightColorR_q[bitplane1];
                        green1 <= RegLightColorG_q[bitplane1];
                        blue1 <= RegLightColorB_q[bitplane1];
                    end 
                end 
            end
        end

    always @(posedge clock_clk) 
        begin
            if (reset_rst) begin
                red2 <= 0;
                green2 <= 0;
                blue2 <= 0;
            end else begin
                red2 <= 0;
                green2 <= 0;
                blue2 <= 0;
                if (cs2) begin      //  This region has been activated
                    if (event_trigger[0]) begin
                        red2 <= RegLightColorR_q[bitplane2];
                        green2 <= RegLightColorG_q[bitplane2];
                        blue2 <= RegLightColorB_q[bitplane2];
                    end
                end
            end
        end
endmodule
