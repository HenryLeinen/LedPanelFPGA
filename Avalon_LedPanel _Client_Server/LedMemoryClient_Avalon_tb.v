`timescale 1ns / 1ns

module LedMemoryClient_Avalon_tb ();

    //  Registers to drive the circuit
    reg                                 clock50, clock200;
    reg                                 reset;
    reg [10:0]                          s1_address;
    reg [31:0]                          s1_writedata;
    reg                                 s1_write;

    wire [1:0]                          led_red, led_green, led_blue;
    wire [3:0]                          led_addr;
    wire                                led_clock;
    wire                                led_blank;
    wire                                led_latch;

    reg  [9:0]                          memAddrMst;
    reg  [2:0]                          bitplane;
    reg                                 backbuffer;
    reg  [3:0]                          ADDR_MST;
    reg                                 LATCH_MST;
    reg                                 CLK_LED_MST;
    reg                                 BLANK_MST;


    //  Instantiate the DUT
    LedPanelClient_Avalon #(
        .DISPLAY_ROWS_LINES(4),
        .DISPLAY_COLS_LINES(6),
        .COLOR_BITS(8)
    )           DUT (
        .clock(clock50),
        .reset(reset),
        .ext_clock200(clock200),

        .s1_address(s1_address),
        .s1_write(s1_write),
        .s1_writedata(s1_writedata),

        .led_red(led_red),
        .led_green(led_green),
        .led_blue(led_blue),
        .led_addr(led_addr),
        .led_clock(led_clock),
        .led_blank(led_blank),
        .led_latch(led_latch),

        .memAddrMst(memAddrMst),
        .bitplaneMst(bitplane),
        .backbufferMst(backbuffer),

        .ADDR_MST(ADDR_MST),
        .LATCH_MST(LATCH_MST),
        .CLK_LED_MST(CLK_LED_MST),
        .BLANK_MST(BLANK_MST)
    );



    //  Initialize all 
    initial begin
      clock50 = 0;
      clock200 = 0;
      reset = 1;

      ADDR_MST = 0;
      LATCH_MST = 0;
      BLANK_MST = 1;
      CLK_LED_MST = 0;

      memAddrMst = 0;
      bitplane = 0;
      backbuffer = 0;
      s1_address = 0;
      s1_write = 0;
      s1_writedata = 0;
    end


    //  Generating the 200 MHz clock
    initial forever #2.5 clock200 = ~clock200;

    //  Generate the 50 MHz clock
    always @(posedge clock200) clock50 = ~clock50;

    initial  
        begin
            //  Release reset after 10ns
            #10 reset = 0;

            repeat (5) @(posedge clock50) ;

            //  Now set to Column 5 and Row 4
            memAddrMst[5:0] = 5;
            memAddrMst[9:6] = 4;
            $stop;
        end


endmodule