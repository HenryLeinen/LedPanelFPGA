`timescale 1ns / 1ns
//////////////////////////////////////////////////////////////////////////////////
// Company:     Henry Leinen - individual
// Engineer:    Henry Leinen
// 
// Create Date: 09.05.2017 19:09:05
// Design Name: RearLights.v
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


module RearLights #(

) (
    input   wire            clock200_clk,
    input   wire            reset_reset,

    //  Avalon MM interface, register which control current activity
    input   wire [3:0]      s0_address,
    input   wire            s0_read,
    input   wire            s0_write,
    input   wire [31:0]     s0_writedata,
    output  reg [31:0]      s0_readdata,

);




