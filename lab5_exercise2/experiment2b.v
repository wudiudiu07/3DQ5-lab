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

module experiment2b (
		input logic CLOCK_I,
		input logic RESETN_I,
		output logic [8:0] READ_ADDRESS_O,
		output logic [8:0] WRITE_ADDRESS_O,		
		output logic [7:0] READ_DATA_A_O [1:0],
		output logic [7:0] READ_DATA_B_O [1:0],
		output logic [7:0] WRITE_DATA_B_O [1:0],
		output logic WRITE_ENABLE_B_O [1:0]			
);

enum logic [1:0] {
	S_READ,
	S_WRITE,
	S_IDLE
} state;

logic [8:0] read_address, write_address;
logic [7:0] write_data_b [1:0];
logic write_enable_b [1:0];
logic [7:0] read_data_a [1:0];
logic [7:0] read_data_b [1:0];
logic [7:0] y_array, z_array;
logic [7:0] abs_pos_test [1:0];

// Creating a function taking in 8 bit signed input and return its absolute value
// Formula: do 2's complement to data_in, which is ~data_in + 1
function logic [7:0] abs;
	input logic [7:0] data_in;
	return (data_in[7] == 1) ? (~data_in + 1'b1) : data_in;
endfunction

// Instantiate RAM1
dual_port_RAM1 dual_port_RAM_inst1 (
	.address_a ( read_address ),
	.address_b ( write_address ),
	.clock ( CLOCK_I ),
	.data_a ( 8'h00 ),
	.data_b ( write_data_b[1] ),
	.wren_a ( 1'b0 ),
	.wren_b ( write_enable_b[1] ),
	.q_a ( read_data_a[1] ),
	.q_b ( read_data_b[1] )
	);

// Instantiate RAM0
dual_port_RAM0 dual_port_RAM_inst0 (
	.address_a ( read_address ),
	.address_b ( write_address ),
	.clock ( CLOCK_I ),
	.data_a ( 8'h00 ),
	.data_b ( write_data_b[0] ),
	.wren_a ( 1'b0 ),
	.wren_b ( write_enable_b[0] ),
	.q_a ( read_data_a[0] ),
	.q_b ( read_data_b[0] )
	);

// The adder and substractor for the write port of the RAMs
//assign write_data_b[0] = read_data_a[0] + read_data_a[1];
//assign write_data_b[1] = read_data_a[0] - read_data_a[1];

assign write_data_b[0] = y_array;
assign write_data_b[1] = z_array;

// For waveform output debug purposes
assign abs_pos_test[0] = abs(read_data_a[0]);
assign abs_pos_test[1] = abs(read_data_a[1]);

always_comb
begin
	if (read_data_a[0][7] == read_data_a[1][7]) begin
		y_array = read_data_a[0] - read_data_a[1];
	end else begin
		y_array = read_data_a[0] + read_data_a[1];
	end
	if (write_address < 9'd256) begin
		// Find |W[i]| - |X[i]|
		z_array = abs(read_data_a[0]) - abs(read_data_a[1]);
	end else begin
		// Find (|W[i]| + |X[i]|)/2, the average
		z_array = (abs(read_data_a[0]) + abs(read_data_a[1]))/2;
	end
end

// FSM to control the read and write sequence
always_ff @ (posedge CLOCK_I or negedge RESETN_I) begin
	if (RESETN_I == 1'b0) begin
		read_address <= 9'h000;
		write_address <= 9'h000;		
		write_enable_b[0] <= 1'b0;
		write_enable_b[1] <= 1'b0;
		state <= S_READ;
	end else begin
		case (state)
		S_WRITE: begin	
			// One clock cycle for reading and writing data		
			state <= S_READ;
		end
		S_READ: begin
			if (write_address < 9'd511) begin		
				// Prepare address to read for next clock cycle
				read_address <= read_address + 9'd1;
				write_address <= read_address;

				// Write data in next clock cycle
				write_enable_b[0] <= 1'b1;
				write_enable_b[1] <= 1'b1;
			end else begin
				// Finish writing 512 addresses
				write_enable_b[0] <= 1'b0;
				write_enable_b[1] <= 1'b0;

				state <= S_IDLE;
			end			
		end
		endcase
	end
end

assign READ_ADDRESS_O = read_address;
assign WRITE_ADDRESS_O = write_address;
assign READ_DATA_A_O = read_data_a;

assign READ_DATA_B_O = read_data_b;
assign WRITE_ENABLE_B_O = write_enable_b;
assign WRITE_DATA_B_O = write_data_b;

endmodule
