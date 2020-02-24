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

`include "define_state.h"

// This is the top module of the testbench

module tb_experiment2a;

logic Clock_50;
logic [17:0] Switches;
logic [3:0] Push_buttons;

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

parameter NUM_ROW_RECTANGLE = 8,
		  NUM_COL_RECTANGLE = 8,
		  RECT_WIDTH = 40,
		  RECT_HEIGHT = 30,
		  VIEW_AREA_LEFT = 160,
		  VIEW_AREA_RIGHT = 480,
		  VIEW_AREA_TOP = 120,
		  VIEW_AREA_BOTTOM = 360;

// Internal variables
logic RAM_filled;

// Instantiate the unit under test
experiment2a uut (
		.CLOCK_50_I(Clock_50),
		.SWITCH_I(Switches),
		.PUSH_BUTTON_I(Push_buttons),		

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
		.SRAM_OE_N_O(SRAM_OE_N)
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

// Initialize signals
initial begin
	// This is for setting the time format
	$timeformat(-3, 2, " ms", 10);
	
	RAM_filled = 1'b0;
	
	Clock_50 = 1'b0;
	Switches = 18'd0;
	SRAM_resetn = 1'b1;
	
	// Apply master reset
	master_reset;
	
	@ (posedge Clock_50);
	// Clear SRAM
	SRAM_resetn = 1'b0;
	
	@ (posedge Clock_50);
	SRAM_resetn = 1'b1;
	
	@ (posedge Clock_50);
	@ (posedge Clock_50);	
	
	// Activate Push button 0
	$write("Start signal issued for PB0...\n\n");
	Push_buttons[0] = 1'b0;
		
	@ (posedge uut.PB_pushed[0]);
	$write("Pulse generated for PB0...\n\n");
	Push_buttons[0] = 1'b1;
	
	$write("Waiting for SRAM to be filled.\n\n");
	@ (posedge RAM_filled);
		
	$write("Simulating one frame for 640x480 @ 60 Hz...\n\n");
	
	@ (negedge VGA_Vsync);
	$write("\nFinish simulating one frame for 640x480 @ 60 Hz at %t...\n", $realtime);
	$write("No mismatch found...\n\n");
	$stop;
end

// Check if RAM is already filled
always @ (posedge Clock_50) begin
	if (uut.state == S_FINISH_FILL_SRAM) begin
		$write("SRAM is now filled.\n\n");
		RAM_filled <= 1'b1;
	end
end

logic [7:0] expected_red, expected_green, expected_blue;
logic [2:0] color;
logic [2:0] current_row, current_col;
logic [9:0] VGA_row, VGA_col;
logic VGA_en;
   
always @ (posedge Clock_50) begin
	if (~VGA_Vsync) begin
		VGA_en <= 1'b0;
		VGA_row <= 10'h000;
		VGA_col <= 10'h000;
	end else begin
		VGA_en <= ~VGA_en;
		// In 640x480 @ 60 Hz mode, data is provided at every other clock cycle when using 50 MHz clock
		if (VGA_en) begin
			// Delay pixel_X_pos and pixel_Y_pos to match the VGA controller
			VGA_row <= uut.pixel_Y_pos;
			VGA_col <= uut.pixel_X_pos;
			
			if (RAM_filled == 1'b1) begin
				if (VGA_row == VIEW_AREA_TOP && VGA_col == VIEW_AREA_LEFT) $write("Entering 320x240 display area...\n\n");
				if (VGA_row == VIEW_AREA_BOTTOM && VGA_col == VIEW_AREA_RIGHT) $write("Leaving 320x240 display area...\n\n");
				
				// In display area
				if ((VGA_row >= VIEW_AREA_TOP && VGA_row < VIEW_AREA_BOTTOM)
	 			 && (VGA_col >= VIEW_AREA_LEFT && VGA_col < VIEW_AREA_RIGHT)) begin
	 			
	 				// Calculate expected data from the pixel counters
	 				
	 				// Find row of rectangle
					current_row = (VGA_row - VIEW_AREA_TOP) / RECT_HEIGHT;
					
					// Find col of rectangle
					current_col = (VGA_col - VIEW_AREA_LEFT) / RECT_WIDTH;
					
					// Get color of the rectangle
					color = current_col + current_row;		
	
					expected_red = {8{color[2]}};
					expected_green = {8{color[1]}};
					expected_blue = {8{color[0]}};
		
					if (VGA_red != expected_red) begin
						$write("Red   mismatch at pixel (%d, %d): expect=%x, got=%x\n", 
							VGA_col, 
							VGA_row, 
							expected_red, 
							VGA_red);
						$stop;
					end
					if (VGA_green != expected_green) begin
						$write("Green mismatch at pixel (%d, %d): expect=%x, got=%x\n", 
							VGA_col, 
							VGA_row, 
							expected_green, 
							VGA_green);
						$stop;
					end			
					if (VGA_blue != expected_blue) begin
						$write("Blue  mismatch at pixel (%d, %d): expect=%x, got=%x\n", 
							VGA_col, 
							VGA_row, 
							expected_blue, 
							VGA_blue);
						$stop;
					end		
				end
			end
		end
	end
end

endmodule
