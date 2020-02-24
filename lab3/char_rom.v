/*
Copyright by Henry Ko and Nicola Nicolici
Developed for the Digital Systems Design course (COE3DQ4)
Department of Electrical and Computer Engineering
McMaster University
Ontario, Canada
*/

`timescale 1ns/100ps
`default_nettype none

module char_rom (
	input logic Clock,
	input logic [5:0] Character_address,
	input logic [2:0] Font_row,
	input logic [2:0] Font_col,	
	
	output logic Rom_mux_output
);

logic [7:0] char_rom_data;

char_gen_rom	char_gen_rom_inst (
	.address ( {Character_address, Font_row} ),
	.clock ( Clock ),
	.q ( char_rom_data )
	);

assign Rom_mux_output = char_rom_data[~(Font_col-1'b1)];

endmodule
