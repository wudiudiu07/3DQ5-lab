/*
Copyright by Henry Ko and Nicola Nicolici
Developed for the Digital Systems Design course (COE3DQ4)
Department of Electrical and Computer Engineering
McMaster University
Ontario, Canada
*/

`timescale 1ns/100ps

`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

module convert_hex_to_seven_segment (
	input logic [3:0] hex_value,
	output logic [6:0] converted_value
);

always_comb begin
	case(hex_value)
		4'h1: converted_value = 7'b1111001;
		4'h2: converted_value = 7'b0100100;
		4'h3: converted_value = 7'b0110000;
		4'h4: converted_value = 7'b0011001;
		4'h5: converted_value = 7'b0010010;
		4'h6: converted_value = 7'b0000010;
		4'h7: converted_value = 7'b1111000;
		4'h8: converted_value = 7'b0000000;
		4'h9: converted_value = 7'b0011000;
		4'ha: converted_value = 7'b0001000;
		4'hb: converted_value = 7'b0000011;
		4'hc: converted_value = 7'b1000110;
		4'hd: converted_value = 7'b0100001;
		4'he: converted_value = 7'b0000110;
		4'hf: converted_value = 7'b0001110;
		4'h0: converted_value = 7'b1000000;
	endcase
end
	
endmodule
