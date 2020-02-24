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

`ifdef SIMULATION 
   `define RX_CLOCK_RATE 10'd6
`else
   `define RX_CLOCK_RATE 10'd434
`endif

`include "define_state.h"

// This module monitors the UART_RX pin, and assembles the serial data when enabled
module UART_Receive_Controller (
	input logic Clock_50,
	input logic Resetn,
	
	input logic Enable,
	input logic Unload_data,
	
	output logic [7:0] RX_data,
	output logic Empty,
	output logic Overrun,
	output logic [3:0] Frame_error,

	// UART pin	
	input logic UART_RX_I
);

RX_Controller_state_type RXC_state;

logic [7:0] data_buffer;
logic [9:0] clock_count;
logic [2:0] data_count;
logic RX_data_in;

// UART RX Logic
always_ff @ (posedge Clock_50 or negedge Resetn) begin
	if (!Resetn) begin
		data_buffer <= 8'h00;
		RX_data <= 8'h00;
		clock_count <= 10'h000;
		data_count <= 3'h0;
		Frame_error <= 4'd0;
		Overrun <= 1'b0;
		Empty <= 1'b1;
		RXC_state <= S_RXC_IDLE;
		RX_data_in <= 1'b0;
	end else begin
		// Synchronize the asynch signal
		RX_data_in <= UART_RX_I;
		
		// Unload the data
		if (Unload_data) Empty <= 1'b1;

		case (RXC_state)
		S_RXC_IDLE : begin
			if (Enable) begin
				// Uart receiver is enabled
				if (RX_data_in == 1'b0) begin
					// Start bit detected
					RXC_state <= S_RXC_SYNC;
					clock_count <= 10'h000;
					data_count <= 3'h0;
					Frame_error  <= 4'd0;
					Overrun   <= 1'b0;
				end
			end
		end
		S_RXC_SYNC: begin
			// Sync the counter for the correct time to sample for UART data on the serial interface
			if (clock_count == (`RX_CLOCK_RATE/2 - 2) && RX_data_in == 1'b0) begin
				// Finish sync process
				clock_count <= 10'h000;
				data_count <= 3'h0;
				data_buffer <= 8'h00;
				RXC_state <= S_RXC_ASSEMBLE_DATA;
			end else begin
				// If the Start bit does not stay on 1'b0 during synchronization
				// it will fail this sync process			
				if (RX_data_in == 1'b0) clock_count <= clock_count + 10'h001;
				else RXC_state <= S_RXC_IDLE;
			end
		end
		S_RXC_ASSEMBLE_DATA: begin
			// Assembling the 8 bit serial data onto data buffer
			if (clock_count == (`RX_CLOCK_RATE-1)) begin
				// Only sample the data at the middle of transmission
				data_buffer <= {RX_data_in, data_buffer[7:1]};
				clock_count <= 10'h000; 
				if (data_count == 3'h7) 
					// Finish assembling the 8 bit data
					RXC_state <= S_RXC_STOP_BIT;
				else data_count <= data_count + 3'h1;   
			end else 
				clock_count <= clock_count + 10'h001;
		end
		S_RXC_STOP_BIT: begin
			// Sample for stop bit here
			if (clock_count == (`RX_CLOCK_RATE-1)) begin
				RXC_state <= S_RXC_IDLE;
				if (RX_data_in == 1'b0) begin
					// If stop bit is not 1'b1, this 8 bit data is corrupted
					Frame_error <= Frame_error + 4'd1;
				end else begin
					Empty <= 1'b0;
//					Frame_error <= 1'b0;

					// Check if last data has been unloaded or not
					Overrun  <= (Empty) ? 1'b0 : 1'b1;
					
					// Put the new data to the output
					RX_data  <= data_buffer;
				end
			end else 
				clock_count <= clock_count + 10'h001;
		end
		default: RXC_state <= S_RXC_IDLE;
		endcase
	end
end

endmodule
