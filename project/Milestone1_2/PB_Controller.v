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

module PB_Controller (
	input logic Clock_50,
	input logic Resetn,
	
	input logic [3:0] PB_signal,
	
	output logic [3:0] PB_pushed
);

logic [15:0] clock_1kHz_div_count;
logic clock_1kHz, clock_1kHz_buf;

logic [9:0] debounce_shift_reg [3:0];
logic [3:0] push_button_status;
logic [3:0] push_button_status_buf;

// Clock division for 1 kHz clock
always_ff @ (posedge Clock_50 or negedge Resetn) begin
	if (Resetn == 1'b0) begin
		clock_1kHz_div_count <= 16'h0000;
	end else begin
		if (clock_1kHz_div_count < 'd24999) begin
			clock_1kHz_div_count <= clock_1kHz_div_count + 16'd1;
		end else 
			clock_1kHz_div_count <= 16'h0000;		
	end
end

always_ff @ (posedge Clock_50 or negedge Resetn) begin
	if (Resetn == 1'b0) begin
		clock_1kHz <= 1'b1;
	end else begin
		if (clock_1kHz_div_count == 'd0) clock_1kHz <= ~clock_1kHz;
	end
end

always_ff @ (posedge Clock_50 or negedge Resetn) begin
	if (Resetn == 1'b0) begin
		clock_1kHz_buf <= 1'b1;	
	end else begin
		clock_1kHz_buf <= clock_1kHz;
	end
end

// Shift register for debouncing the push buttons
always_ff @ (posedge Clock_50 or negedge Resetn) begin
	if (Resetn == 1'b0) begin
		debounce_shift_reg[0] <= 8'd0;
		debounce_shift_reg[1] <= 8'd0;
		debounce_shift_reg[2] <= 8'd0;
		debounce_shift_reg[3] <= 8'd0;						
	end else begin
		if (clock_1kHz_buf == 1'b0 && clock_1kHz == 1'b1) begin
			debounce_shift_reg[0] <= {debounce_shift_reg[0][8:0], ~PB_signal[0]};
			debounce_shift_reg[1] <= {debounce_shift_reg[1][8:0], ~PB_signal[1]};
			debounce_shift_reg[2] <= {debounce_shift_reg[2][8:0], ~PB_signal[2]};
			debounce_shift_reg[3] <= {debounce_shift_reg[3][8:0], ~PB_signal[3]};									
		end
	end
end

// OR gate for debouncing the push buttons
always_ff @ (posedge Clock_50 or negedge Resetn) begin
	if (Resetn == 1'b0) begin
		push_button_status <= 4'h0;
		push_button_status_buf <= 4'h0;
	end else begin
		push_button_status[0] <= |debounce_shift_reg[0];
		push_button_status[1] <= |debounce_shift_reg[1];
		push_button_status[2] <= |debounce_shift_reg[2];
		push_button_status[3] <= |debounce_shift_reg[3];						
		
		push_button_status_buf <= push_button_status;
	end
end

// change 4'b0000 to indicate level or edge detection (1 for level, 0 for edge)
assign PB_pushed = push_button_status & (~push_button_status_buf | 4'b0000); 

endmodule
