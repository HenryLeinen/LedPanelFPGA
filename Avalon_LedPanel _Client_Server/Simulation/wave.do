onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /PwmOut_Avalon_tb/DUT/clock_clk
add wave -noupdate /PwmOut_Avalon_tb/DUT/reset_reset
add wave -noupdate /PwmOut_Avalon_tb/DUT/s0_command_address
add wave -noupdate /PwmOut_Avalon_tb/DUT/s0_command_read
add wave -noupdate /PwmOut_Avalon_tb/DUT/s0_command_readdata
add wave -noupdate /PwmOut_Avalon_tb/DUT/s0_command_write
add wave -noupdate -radix decimal /PwmOut_Avalon_tb/DUT/s0_command_writedata
add wave -noupdate /PwmOut_Avalon_tb/DUT/pwm
add wave -noupdate -radix decimal /PwmOut_Avalon_tb/DUT/clock_counter
add wave -noupdate -radix decimal /PwmOut_Avalon_tb/DUT/prescaler
add wave -noupdate /PwmOut_Avalon_tb/DUT/clock
add wave -noupdate -expand /PwmOut_Avalon_tb/DUT/pwm_d
add wave -noupdate /PwmOut_Avalon_tb/DUT/PWM_DEFAULT_OUTPUT_VALUE
add wave -noupdate /PwmOut_Avalon_tb/DUT/PWM_PRESCALER
add wave -noupdate -expand /PwmOut_Avalon_tb/DUT/PWM_REG_FREQ
add wave -noupdate -expand /PwmOut_Avalon_tb/DUT/PWM_DUTY_CYCLE
add wave -noupdate -expand /PwmOut_Avalon_tb/DUT/pwm_frequency
add wave -noupdate -expand /PwmOut_Avalon_tb/DUT/pwm_counter
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {22707500 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 304
configure wave -valuecolwidth 202
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {17290759 ps} {23300487 ps}
