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

module tb_experiment2b;

logic Clock_50;
logic Resetn;

logic [8:0] Read_address, Write_address;
logic [7:0] Read_data_A [1:0];
logic [7:0] Read_data_B [1:0];
logic [7:0] Write_data_B [1:0];
logic Write_enable_B [1:0];

// Instantiate the unit under test
experiment2b uut (
		.CLOCK_I(Clock_50),
		.RESETN_I(Resetn),
		.READ_ADDRESS_O(Read_address),
		.WRITE_ADDRESS_O(Write_address),		
		.READ_DATA_A_O(Read_data_A),
		.READ_DATA_B_O(Read_data_B),
		.WRITE_DATA_B_O(Write_data_B),
		.WRITE_ENABLE_B_O(Write_enable_B)
);

// Generate a 50 MHz clock
always begin
	# 10;
	Clock_50 = ~Clock_50;
end

task master_reset;
begin
	wait (Clock_50 !== 1'bx);
	@ (posedge Clock_50);
	Resetn = 1'b0;
	// Activate reset for 2 clock cycles
	@ (posedge Clock_50);
	@ (posedge Clock_50);	
	Resetn = 1'b1;	
end
endtask

// Initialize signals
initial begin
	Clock_50 = 1'b0;
	Resetn = 1'b1;
	
	// Apply master reset
	master_reset;
	
	// run simulation for 25 us
	# 25000;
	$stop;
end

endmodule
