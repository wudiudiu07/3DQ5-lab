// Copyright by Adam Kinsman and Henry Ko and Nicola Nicolici
// Developed for the Digital Systems Design course (COE3DQ5)
// Department of Electrical and Computer Engineering
// McMaster University
// Ontario, Canada

/*
Updated testbench coded by Jason Thong, 2012

This testbench was adapated from experiment4a from lab 5. Make sure
instantiation names match that of your project (e.g. replace "experiment4a"
everywhere with "project" or whatever your top level is called).

There are many debug hooks already placed in the code (messages will print
when "something bad" happens), it is recommended you modify these as well as
add your own.

The verification strategy here is to watch data being written back to the
SRAM. It is assumed that all values being written are the final values.
If you are using the SRAM as temporary storage (strongly NOT advisable),
you will get false errors, so use the original testbench instead.
*/ 

`timescale 1ns/100ps
`default_nettype none

// This is the top testbench file

`define FEOF 32'hFFFFFFFF
`define MAX_MISMATCHES 10

// file for output
// this is only useful if decoding is done all the way through (e.g. milestone 1 is used)
`define OUTPUT_FILE_NAME "motorcycle_tb.ppm"

// file for comparison
// to test milestone 2 independently, use the .sram_d1 file to check the output
`define VERIFICATION_FILE_NAME "motorcycle.sram_d2"

//// for milestone 1
//`define INPUT_FILE_NAME "motorcycle.sram_d1"

//// for milestone 2
//`define INPUT_FILE_NAME "motorcycle.sram_d2"

//// for milestone 3 (completed project)
`define INPUT_FILE_NAME "motorcycle.mic13"

module tb_project_v2;

logic Clock_50;
logic [17:0] Switches;
logic [3:0] Push_buttons;
logic [8:0] LED_Green;
logic [6:0] seven_segment_n [7:0];

logic VGA_clock;
logic VGA_Hsync;
logic VGA_Vsync;
logic VGA_blank;
logic VGA_sync;
logic [7:0] VGA_red;
logic [7:0] VGA_green;
logic [7:0] VGA_blue;

wire [15:0] SRAM_data_io;
logic [15:0] SRAM_write_data, SRAM_read_data;
logic [19:0] SRAM_address;
logic SRAM_UB_N;
logic SRAM_LB_N;
logic SRAM_WE_N;
logic SRAM_CE_N;
logic SRAM_OE_N;

logic SRAM_resetn;

parameter VIEW_AREA_LEFT = 160,
		  VIEW_AREA_RIGHT = 480,
		  VIEW_AREA_TOP = 120,
		  VIEW_AREA_BOTTOM = 360;

// Internal variables
integer validation_file;
integer validation_mismatches;
integer VGA_temp;
logic [7:0] VGA_file_data;
logic [7:0] expected_red, expected_green, expected_blue;
logic [9:0] VGA_row, VGA_col;
logic VGA_en;
logic VGA_display_enable;
logic UART_TX_O;

// a very software-ish way of emulating the sram
logic [17:0] SRAM_ARRAY[262143:0];
integer SRAM_ARRAY_write_count[262143:0];
integer num_mismatches;
integer warn_writing_out_of_region;
integer warn_multiple_writes_to_same_location;


// Instantiate the unit under test
project uut (
		.CLOCK_50_I(Clock_50),
		.SWITCH_I(Switches),
		.PUSH_BUTTON_I(Push_buttons),		

		.SEVEN_SEGMENT_N_O(seven_segment_n),
		.LED_GREEN_O(LED_Green),

		.VGA_CLOCK_O(VGA_clock),
		.VGA_HSYNC_O(VGA_Hsync),
		.VGA_VSYNC_O(VGA_Vsync),
		.VGA_BLANK_O(VGA_blank),
		.VGA_SYNC_O(VGA_sync),
		.VGA_RED_O(VGA_red),
		.VGA_GREEN_O(VGA_green),
		.VGA_BLUE_O(VGA_blue),
		
		.SRAM_DATA_IO(SRAM_data_io),
		.SRAM_ADDRESS_O(SRAM_address),
		.SRAM_UB_N_O(SRAM_UB_N),
		.SRAM_LB_N_O(SRAM_LB_N),
		.SRAM_WE_N_O(SRAM_WE_N),
		.SRAM_CE_N_O(SRAM_CE_N),
		.SRAM_OE_N_O(SRAM_OE_N),
		
		.UART_RX_I(1'b1),
		.UART_TX_O(UART_TX_O)
);

// The emulator for the external SRAM during simulation
tb_SRAM_Emulator SRAM_component (
	.Clock_50(Clock_50),
	.Resetn(SRAM_resetn),
	
	.SRAM_data_io(SRAM_data_io),
	.SRAM_address(SRAM_address[17:0]),
	.SRAM_UB_N(SRAM_UB_N),
	.SRAM_LB_N(SRAM_LB_N),
	.SRAM_WE_N(SRAM_WE_N),
	.SRAM_CE_N(SRAM_CE_N),
	.SRAM_OE_N(SRAM_OE_N)
);

// Generate a 50 MHz clock
always begin
	# 10;
	Clock_50 = ~Clock_50;
end


task init_sram;
	integer file_ptr, file_data, i;
	logic [15:0] buffer;
begin
	$write("Opening file \"%s\" for initializing SRAM\n\n", `INPUT_FILE_NAME);
	file_ptr = $fopen(`INPUT_FILE_NAME, "rb");
	for (i=0; i<262144; i=i+1) begin
		file_data = $fgetc(file_ptr);
		buffer[15:8] = file_data & 8'hFF;
		file_data = $fgetc(file_ptr);
		buffer[7:0] = file_data & 8'hFF;
		SRAM_component.SRAM_data[i] = buffer;
	end
	$fclose(file_ptr);
	
	$write("Opening file \"%s\" to get SRAM verification data\n\n", `VERIFICATION_FILE_NAME);
	file_ptr = $fopen(`VERIFICATION_FILE_NAME, "rb");
	for (i=0; i<262144; i=i+1) begin
		file_data = $fgetc(file_ptr);
		buffer[15:8] = file_data & 8'hFF;
		file_data = $fgetc(file_ptr);
		buffer[7:0] = file_data & 8'hFF;
		SRAM_ARRAY[i] = buffer;
		SRAM_ARRAY_write_count[i] = 0;
	end
	$fclose(file_ptr);
	
	num_mismatches = 0;
	warn_writing_out_of_region = 0;
	warn_multiple_writes_to_same_location = 0;
end
endtask

task check_sram_write_counts;
	integer i, error_count;
begin
	error_count = 0;
	
	//NOTE: this is for milestone 1, in different milestones we will be
	//writing to different regions so modify as needed
	//for (i=146944; i<262144; i=i+1) begin
	for (i=76800; i<230400; i=i+1) begin
		if (SRAM_ARRAY_write_count[i]==0) begin
			if (error_count < `MAX_MISMATCHES) begin
				$write("error: did not write to location %d (%x hex)\n", i, i);
				error_count = error_count + 1;
			end
		end
	end

end
endtask



// Task for generating master reset
task master_reset;
begin
	wait (Clock_50 !== 1'bx);
	@ (posedge Clock_50);
	$write("Applying global reset...\n\n");
	Switches[17] = 1'b1;
	// Activate reset for 2 clock cycles
	@ (posedge Clock_50);
	@ (posedge Clock_50);	
	Switches[17] = 1'b0;	
	$write("Removing global reset...\n\n");	
end
endtask

task write_PPM_file; 
	integer i, output_file;
	logic [7:0] high_byte, low_byte;
begin
	$write("Writing SRAM contents to file \"%s\"\n\n", `OUTPUT_FILE_NAME);
	output_file = $fopen(`OUTPUT_FILE_NAME, "wb");
	
	// Write file header
	$fwrite(output_file, "P6%c320 240%c255%c", 8'h0A, 8'h0A, 8'h0A); 

	// Write RGB main data
	for (i = 0; i < 3*320*240/2; i = i + 1) begin
		high_byte = (SRAM_component.SRAM_data[i+uut.VGA_base_address] >> 8) & 8'hFF;
		low_byte = SRAM_component.SRAM_data[i+uut.VGA_base_address] & 8'hFF;

		// $fwrite can't support the 8'h00 = "\0" character, so offset it to 
		// 8'h01. The output image will not be numerically identical, but it 
		// will be visually indistiguishable from the software model output
		// thus we only use this output PPM as a visual check
		if (high_byte == 8'h00) high_byte = 8'h01;
		if (low_byte == 8'h00) low_byte = 8'h01;

		$fwrite(output_file, "%c%c", high_byte, low_byte);
	end

	$fclose(output_file);
end endtask

// Initialize signals
initial begin
	// This is for setting the time format
	$timeformat(-9, 0, " ns", 10);
	
	$write("Simulation started at %t\n\n", $realtime);
	Clock_50 = 1'b0;
	Switches = 18'd0;
	SRAM_resetn = 1'b1;
	VGA_display_enable = 1'b0;
	validation_mismatches = 0;
	
	// Apply master reset
	master_reset;
	Push_buttons = 4'hF;
	
	@ (posedge Clock_50);
	// Clear SRAM
	SRAM_resetn = 1'b0;
	
	@ (posedge Clock_50);
	SRAM_resetn = 1'b1;
	
	@ (posedge Clock_50);
	@ (posedge Clock_50);	

	init_sram;
	$write("SRAM is now filled at %t\n\n", $realtime);

	//when the uart timer "times-out" after not receiving data for a while, your state machine
	//should move out of receiving uart data to decoding the data
	//in hardware, we would have to wait 1 second, but in simulation 50 million clocks is kind of slow
	//so just force the timer to a value that is nearly that of the "time-out"
	@ (posedge Clock_50);	
	uut.UART_timer = 26'd49999990;
	wait (uut.top_state != 0);	//this assumes S_IDLE is the first in the list where the states are enumerated
	$write("Starting Decoder at %t\n\n", $realtime);
	
	wait (uut.top_state == 0);	//this assumes we go back to S_IDLE when we are done
//	wait (uut.done == 1);		//otherwise change as needed, could use a done signal

	@ (posedge Clock_50);		//let sram writes finish, not sure if this is really needed...
	@ (posedge Clock_50);
	@ (posedge Clock_50);
	
	check_sram_write_counts;	//this task checks that we've written to all the locations that we were supposed to
	
	write_PPM_file;

	$write("Decoding finished at %t\n\n", $realtime);
	$write("No mismatch found...\n\n");
	$stop;
end


//monitor the write enable signal on the SRAM
//if the incoming data does not match the expected data
//then stop simulating and print debug info
always @ (posedge Clock_50) begin
	if (uut.SRAM_we_n == 1'b0) begin	//signal names within project (instantiated as uut) should match here, assuming names from experiment4a
	
		//IMPORTANT: this is the "no write" memory region for milestone 1, change region for different milestones
		if (uut.SRAM_address < 76800) begin
			if (warn_writing_out_of_region < `MAX_MISMATCHES) begin
				$write("critical warning: writing outside of the RGB data region, may corrupt source data in SRAM\n");
				$write("  writing value %d (%x hex) to location %d (%x hex), sim time %t\n", 
					uut.SRAM_write_data, uut.SRAM_write_data, uut.SRAM_address, uut.SRAM_address, $realtime);
				warn_writing_out_of_region = warn_writing_out_of_region + 1;
			end
		end
	
		if (SRAM_ARRAY[uut.SRAM_address] != uut.SRAM_write_data) begin
			$write("error: wrote value %d (%x hex) to location %d (%x hex), should be value %d (%x hex)\n",
				uut.SRAM_write_data, uut.SRAM_write_data, uut.SRAM_address, uut.SRAM_address,
				SRAM_ARRAY[uut.SRAM_address], SRAM_ARRAY[uut.SRAM_address]);
			$write("sim time %t\n", $realtime);
			$write("print some useful debug info here...\n");
		//	$write("m1 state %d\n", uut.m1.state);
			$write("...or take a look at the last few clock cycles in the waveforms that lead up to this error\n");
			num_mismatches = num_mismatches + 1;
			if (num_mismatches == `MAX_MISMATCHES) $stop;
		end
		
		SRAM_ARRAY_write_count[uut.SRAM_address] = SRAM_ARRAY_write_count[uut.SRAM_address] + 1;
		if (SRAM_ARRAY_write_count[uut.SRAM_address] != 1 && warn_multiple_writes_to_same_location < `MAX_MISMATCHES) begin
			$write("warning: written %d times to location %d (%x hex), sim time %t\n",
				SRAM_ARRAY_write_count[uut.SRAM_address], uut.SRAM_address, uut.SRAM_address, $realtime);
			warn_multiple_writes_to_same_location = warn_multiple_writes_to_same_location + 1;
		end
	end
end

endmodule
