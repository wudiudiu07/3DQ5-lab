/*
Copyright by Henry Ko and Nicola Nicolici
Developed for the Digital Systems Design course (COE3DQ4)
Department of Electrical and Computer Engineering
McMaster University
Ontario, Canada
*/

`timescale 1ns/100ps
`default_nettype none

// This is the top module
// It assembles the serial data from the PS2 device, and output the assembled PS2 code
module PS2_controller (
	input logic Clock_50,
	input logic Resetn,
	
	input logic PS2_clock,
	input logic PS2_data,
	
	output logic [7:0] PS2_code,
	output logic PS2_code_ready,
	output logic PS2_make_code,	
	output logic PS2_upper_lower
);

enum logic [1:0] {
	S_PS2_IDLE,
	S_PS2_ASSEMBLE_CODE,
	S_PS2_PARITY,
	S_PS2_STOP
} PS2_state;

logic PS2_clock_sync, PS2_clock_buf;
logic [7:0] PS2_shift_reg;
logic [2:0] PS2_bit_count;
logic PS2_parity;

always_ff @ (posedge Clock_50 or negedge Resetn) begin
	if (Resetn == 1'b0) begin
		PS2_clock_buf <= 1'b0;		
		PS2_clock_sync <= 1'b0;		
		PS2_state <= S_PS2_IDLE;
		PS2_bit_count <= 3'd0;
		PS2_code_ready <= 1'b0;
		PS2_code <= 8'd0;
		PS2_upper_lower <= 1'b0;
		PS2_parity <= 1'b0;
		PS2_make_code <= 1'b0;
		PS2_shift_reg <= 8'd0;		
	end else begin
		// Synchronize the data
		PS2_clock_sync <= PS2_clock;
		PS2_clock_buf <= PS2_clock_sync;
		
		// Edge detection for PS2 clock
		if (PS2_clock_sync && ~PS2_clock_buf) begin	
			case (PS2_state)
			S_PS2_IDLE: begin
				if (PS2_data == 1'b0) begin
					// Start bit detected
					PS2_state <= S_PS2_ASSEMBLE_CODE;
					PS2_shift_reg <= 8'd0;
					PS2_bit_count <= 3'd0;
					PS2_code_ready <= 1'b0;		
				end
			end
			S_PS2_ASSEMBLE_CODE: begin
				// Shift in data
				PS2_shift_reg <= {PS2_data, PS2_shift_reg[7:1]};		
				if (PS2_bit_count < 3'd7) begin
					PS2_bit_count <= PS2_bit_count + 3'd1;
				end else begin
					PS2_state <= S_PS2_PARITY;
				end
			end
			S_PS2_PARITY: begin
				// Get parity bit
				PS2_parity <= PS2_data;
				PS2_state <= S_PS2_STOP;			
			end
			S_PS2_STOP: begin
				if (PS2_data == 1'b1) begin
					// Stop bit detected
					// Check for make or break code
					if (PS2_code == 8'hF0 || PS2_shift_reg == 8'hF0) 
						PS2_make_code <= 1'b0;
					else 
						PS2_make_code <= 1'b1;
					
					if(PS2_shift_reg <= 8'h12) begin
						PS2_upper_lower <= 1'b1;
						PS2_make_code <= 1'b0;
					end
					if (PS2_shift_reg == 8'h59) begin
						PS2_upper_lower <= 1'b0;
						PS2_make_code <= 1'b0;
					end
					
					PS2_code <= PS2_shift_reg;
					PS2_code_ready <= 1'b1;
				end
				PS2_state <= S_PS2_IDLE;
			end
			default: PS2_state <= S_PS2_IDLE;
			endcase
		end
	end
end

endmodule
