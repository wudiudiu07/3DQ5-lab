/*
Copyright by Henry Ko and Nicola Nicolici
Developed for the Digital Systems Design course (COE3DQ4)
Department of Electrical and Computer Engineering
McMaster University
Ontario, Canada
*/

`timescale 1ns/100ps
`default_nettype none

module convert_hex_to_char_rom_address (
	input logic [3:0] hex_value,
	output logic [5:0] char_rom_address
);

always_comb begin
	char_rom_address = 6'd0;
	case (hex_value)
		4'h0: char_rom_address = 6'o60;
		4'h1: char_rom_address = 6'o61;
		4'h2: char_rom_address = 6'o62;
		4'h3: char_rom_address = 6'o63;
		4'h4: char_rom_address = 6'o64;
		4'h5: char_rom_address = 6'o65;
		4'h6: char_rom_address = 6'o66;
		4'h7: char_rom_address = 6'o67;
		4'h8: char_rom_address = 6'o70;
		4'h9: char_rom_address = 6'o71;
		4'ha: char_rom_address = 6'o72;
		4'hb: char_rom_address = 6'o73;
		4'hc: char_rom_address = 6'o74;
		4'hd: char_rom_address = 6'o75;
		4'he: char_rom_address = 6'o76;														
		default: char_rom_address = 6'o77;
	endcase
end

endmodule
