// new_component.v

// This file was auto-generated as a prototype implementation of a module
// created in component editor.  It ties off all outputs to ground and
// ignores all inputs.  It needs to be edited to make it do something
// useful.
// 
// This file will not be automatically regenerated.  You should check it in
// to your version control system if you want to keep it.

`timescale 1 ns / 1 ps
module PwmOut_Avalon #(
		parameter NUMBER_OUTPUTS = 1
	) (
		input  wire        clock_clk,            //      clock.clk
		input  wire        reset_reset,          //      reset.reset
		input  wire [4:0]  s0_command_address,   // s0_command.address
		input  wire        s0_command_read,      //           .read
		output reg  [31:0] s0_command_readdata,  //           .readdata
		input  wire        s0_command_write,     //           .write
		input  wire [31:0] s0_command_writedata, //           .writedata
		output reg  [NUMBER_OUTPUTS-1:0]  pwm                   //    pwm_out.pwm_out
	);

    //  implement the clock divider basis which is common for all channels
    reg   [31:0]        clock_counter;
    reg   [31:0]        prescaler;
    reg                 clock;

    //  For each output channel implement the counter, the value and the configuration information
    reg   [15:0]        pwm_frequency[NUMBER_OUTPUTS-1:0];              //  The max value for the PWM counter, where the counter will be reset and the output will be switched into the default value
    reg   [15:0]        pwm_counter[NUMBER_OUTPUTS-1:0];                //  The actual PWM counter value which will be incremented on each clock
    reg   [15:0]        pwm_duty_cycle[NUMBER_OUTPUTS-1:0];             //  The PWM duty cycle value. When the counter reaches this value the output will be flipped
    reg                 pwm_default_output_value[NUMBER_OUTPUTS-1:0];   //  This is the default value for the output
    reg   [NUMBER_OUTPUTS-1:0]  pwm_d;

    //  The "writeable" register latches --> register values will be taken over only when the pwm_counter reaches the actual maximum (frequency value) in order to avoid errors on the outputs
    reg    [15:0]       PWM_REG_FREQ[NUMBER_OUTPUTS-1:0];
    reg    [15:0]       PWM_DUTY_CYCLE[NUMBER_OUTPUTS-1:0];
    reg    [31:0]       PWM_DEFAULT_OUTPUT_VALUE;
    reg    [31:0]       PWM_PRESCALER;

    //  REGISTER LAYOUT:
    //                          | 3 3 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1                     |
    //           Address        | 1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0 | Description
    //  ------------------------+-----------------------------------------------------------------+------------------------------------------------------------------
    //              $00         |                                                                 |
    //               -          |       < CHxDutyCycle15..0 >           < CHxFrequency15..0>      | CHxFrequency15..0 = 16 Bit max counter value
    //      $(NUMBER_OUTPUTS-1) |                                                                 | CHxDutyCycle15..0 = 16 Bit max counter value
    //  ------------------------+-----------------------------------------------------------------+------------------------------------------------------------------
    //                          |                                                                 |
    //             $10          |               <CHx Default Outputs 31..0>                       | CHx Default Output state (status of the output at counter value 0)
    //                          |                                                                 |  each bit represents one channel
    //  ------------------------+-----------------------------------------------------------------+------------------------------------------------------------------
    //                          |                                                                 |
    //             $11          |                     <PRESCALER 31..0>                           | Prescaler for the clock. This affects all channels
    //                          |                                                                 |  
    //  ------------------------+-----------------------------------------------------------------+------------------------------------------------------------------
    
    //  Generate the clock division
    always @(posedge clock_clk)
        begin
            if (reset_reset) begin
                    clock_counter <= 32'b0;
                    prescaler <= 32'b00000000000000000000000000001111;
                    clock <= 1'b0;
            end else begin
                if (clock_counter == prescaler) begin
                    clock <= ~clock;
                    clock_counter <= 32'b0;
                    prescaler <= PWM_PRESCALER;                     //  Take over new prescaler value only upon reset of the clock
                end else begin
                    clock_counter <= clock_counter + 32'b1;
                end
            end
        end


    genvar i;
    generate 
        for (i = 0 ; i < NUMBER_OUTPUTS ; i = i + 1 ) begin: test

            always @(posedge clock_clk)
                begin
                    if (reset_reset)    pwm[i] <= 0;
                    else pwm[i] <= pwm_d[i];
                end

            //  Implement the PWM functionality
            always @(posedge clock or posedge reset_reset) 
                begin
                    if (reset_reset) begin
                        pwm_counter[i] <= 16'b0;
                        pwm_frequency[i] <= 16'b0000000000001111;
                        pwm_duty_cycle[i] <= 16'b0000000000000011;
                        pwm_default_output_value[i] <= 1'b0;
                        pwm_d[i] <= 1'b0;
                    end else begin
                        pwm_counter[i] <= pwm_counter[i] + 16'b0000000000000001;
                        if (pwm_counter[i] == pwm_duty_cycle[i]) begin
                            pwm_d[i] <= ~pwm_default_output_value[i];                         //  upon reaching the the duty cycle value, the output will be inverted
                        end else if (pwm_counter[i] == pwm_frequency[i]) begin
                            pwm_d[i] <= PWM_DEFAULT_OUTPUT_VALUE[i];
                            pwm_counter[i] <= 16'b0000000000000000;
                            //  Take over any new register values
                            pwm_frequency[i] <= PWM_REG_FREQ[i];
                            pwm_duty_cycle[i] <= PWM_DUTY_CYCLE[i];
                            pwm_default_output_value[i] <= PWM_DEFAULT_OUTPUT_VALUE[i];
                        end
                    end
                end

            always @(posedge clock_clk) 
                begin
                    if (reset_reset) begin
                        PWM_REG_FREQ[i] <= 16'b1111111111111111;
                        PWM_DUTY_CYCLE[i] <= 16'b0000000011111111;
                    end else begin
                        if (s0_command_write) begin
                            if (s0_command_address == i) begin
                                PWM_REG_FREQ[i] <= s0_command_writedata[15:0];
                                PWM_DUTY_CYCLE[i] <= s0_command_writedata[31:16];
                            end
                        end
                    end              
                end
        end
    endgenerate

    //  Implement register access by avalon interface
    always @(posedge clock_clk)
        begin
            if (reset_reset) begin
                PWM_DEFAULT_OUTPUT_VALUE <= 32'b0;
                PWM_PRESCALER <= 32'b00000000000000000000000000001111;
            end else begin
                if (s0_command_write) begin
                    if (s0_command_address == 16) begin
                        PWM_DEFAULT_OUTPUT_VALUE <= s0_command_writedata[NUMBER_OUTPUTS-1:0];
                    end else if (s0_command_address == 17) begin
                        PWM_PRESCALER <= s0_command_writedata;
                    end
                end else if (s0_command_read) begin
                    if (s0_command_read == 16) begin
                        s0_command_readdata <= {{(32-NUMBER_OUTPUTS){1'b0}}, PWM_DEFAULT_OUTPUT_VALUE};
                    end else if (s0_command_address == 17) begin
                        s0_command_readdata <= prescaler;
                    end else if (s0_command_address < 16) begin
                        s0_command_readdata <= {PWM_DUTY_CYCLE[s0_command_address], PWM_REG_FREQ[s0_command_address]};
                    end
                end
            end
        end
endmodule
