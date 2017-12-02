`timescale 1 ns / 1 ps
module PwmOut_Avalon_tb ();

    //  Generate register logic and wires required to drive and test the DUT
    reg                     clock;
    reg                     reset;
    reg   [31:0]            s0_writedata;
    reg   [4:0]             s0_address;
    wire  [31:0]            s0_readdata;
    reg                     s0_write;
    reg                     s0_read;

    wire  [3:0]             pwm;


    //  Instantiate the DUT
    PwmOut_Avalon  #(.NUMBER_OUTPUTS(3)) DUT(
        .clock_clk(clock),
        .reset_reset(reset),

        .s0_command_address(s0_address),
        .s0_command_read(s0_read),
        .s0_command_write(s0_write),
        .s0_command_readdata(s0_readdata),
        .s0_command_writedata(s0_writedata),

        .pwm(pwm)
    );

    task SetPrescaler;
        input [31:0]    prescaler;

        begin
            @(posedge clock);
            s0_address = 17;
            s0_writedata = prescaler;
            s0_write = 1;
            @(posedge clock);
            s0_write = 0;
        end
    endtask

    task SetPwm;
        input [3:0] channel;
        input [15:0] frequency;
        input [15:0] duty_cycle;

        begin
            @(posedge clock);
            s0_address = channel;
            s0_writedata = {duty_cycle, frequency};
            s0_write = 1;
            @(posedge clock);
            s0_write = 0;
        end
    endtask

    initial begin
        clock = 0;
        reset = 0;
    end

    //  Generate the clock
    initial forever #2.5 clock = ~clock;

    //  start the test
    initial begin
        reset = 1;
        s0_write = 0;
        s0_read = 0;
        s0_writedata = 0;

        #10 reset = 0;

        @(posedge clock);

        SetPrescaler(1);

        SetPwm(0, 1000, 10);
        SetPwm(1, 1000, 20);
        SetPwm(2, 1000, 30);
        SetPwm(3, 1000, 40);

        @(negedge pwm[3]);

        $stop;
    end

endmodule
