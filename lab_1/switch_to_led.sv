/*
Copyright by Henry Ko and Nicola Nicolici
Developed for the Digital Systems Design course (COE3DQ4)
Department of Electrical and Computer Engineering
McMaster University
Ontario, Canada
*/

`timescale 1ns/100ps
`default_nettype none

// This module is to convert a 4 bits hex number into a 7-bit value for 7-segment display
module switch_to_led (
	input logic [4:0] switch_in,
	output logic [2:0] led_out
);

always_comb begin
	led_out[2] = |switch_in[4:0];
	led_out[1] = &switch_in[4:0];
	led_out[0] = ^switch_in[4:0];
end
	
endmodule
