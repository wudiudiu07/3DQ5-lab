// Copyright by Adam Kinsman and Henry Ko and Nicola Nicolici
// Developed for the Digital Systems Design course (COE3DQ4)
// Department of Electrical and Computer Engineering
// McMaster University
// Ontario, Canada

`timescale 1ns/100ps

`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

`include "define_state.h"

// This module generates the address for reading the SRAM
// in order to display the image on the screen
module VGA_SRAM_interface (
   input  logic            Clock,
   input  logic            Resetn,
   
   input  logic            VGA_enable,
   input  logic   [17:0]   SRAM_base_address,
   output logic   [17:0]   SRAM_address,
   input  logic   [15:0]   SRAM_read_data,

   output logic            VGA_CLOCK_O,
   output logic            VGA_HSYNC_O,
   output logic            VGA_VSYNC_O,
   output logic            VGA_BLANK_O,
   output logic            VGA_SYNC_O,
   output logic   [9:0]    VGA_RED_O,
   output logic   [9:0]    VGA_GREEN_O,
   output logic   [9:0]    VGA_BLUE_O
);

parameter 
   VIEW_AREA_LEFT = 160,
   VIEW_AREA_RIGHT = 480,
   VIEW_AREA_TOP = 120,
   VIEW_AREA_BOTTOM = 360;
		
VGA_SRAM_state_type VGA_SRAM_state;

// For VGA
logic    [9:0]    VGA_red, VGA_green, VGA_blue;
logic    [9:0]    pixel_X_pos;
logic    [9:0]    pixel_Y_pos;

logic    [15:0]   VGA_sram_data [2:0];

// VGA unit
VGA_Controller VGA_unit(
	.Clock(Clock),
	.Resetn(Resetn),

	.iRed(VGA_red),
	.iGreen(VGA_green),
	.iBlue(VGA_blue),
	.oCoord_X(pixel_X_pos),
	.oCoord_Y(pixel_Y_pos),
	
	//	VGA Side
	.oVGA_R(VGA_RED_O),
	.oVGA_G(VGA_GREEN_O),
	.oVGA_B(VGA_BLUE_O),
	.oVGA_H_SYNC(VGA_HSYNC_O),
	.oVGA_V_SYNC(VGA_VSYNC_O),
	.oVGA_SYNC(VGA_SYNC_O),
	.oVGA_BLANK(VGA_BLANK_O),
	.oVGA_CLOCK(VGA_CLOCK_O)
);

always_ff @ (posedge Clock or negedge Resetn) begin
	if (Resetn == 1'b0) begin
		VGA_SRAM_state <= S_VS_WAIT_NEW_PIXEL_ROW;
		VGA_red <= 10'd0;
		VGA_green <= 10'd0;
		VGA_blue <= 10'd0;	
		
		SRAM_address <= 18'd0;
		
		VGA_sram_data[2] <= 16'd0;
		VGA_sram_data[1] <= 16'd0;
		VGA_sram_data[0] <= 16'd0;				
	end else begin
		if (~VGA_enable) begin
			VGA_red <= 10'd0;
 			VGA_green <= 10'd0;
	   		VGA_blue <= 10'd0;								
		end else begin
			case (VGA_SRAM_state)
			S_VS_WAIT_NEW_PIXEL_ROW: begin
				if (pixel_Y_pos >= VIEW_AREA_TOP && pixel_Y_pos < VIEW_AREA_BOTTOM) begin
					if (pixel_X_pos == (VIEW_AREA_LEFT - 3)) begin
						if (pixel_Y_pos == VIEW_AREA_TOP) 
							// Start a new frame
							// Provide address for data 1
							SRAM_address <= SRAM_base_address;
						else 
							// Start a new row of pixels
							// Provide address for data 1
							SRAM_address <= SRAM_address - 18'd4;
						
						VGA_SRAM_state <= S_VS_NEW_PIXEL_ROW_DELAY_1;
					end
				end
				
				VGA_red <= 10'd0;
				VGA_green <= 10'd0;
				VGA_blue <= 10'd0;								
			end
			S_VS_NEW_PIXEL_ROW_DELAY_1: begin	
				// Provide address for data 2
				SRAM_address <= SRAM_address + 18'h00001;				
				VGA_SRAM_state <= S_VS_NEW_PIXEL_ROW_DELAY_2;		
			end
			S_VS_NEW_PIXEL_ROW_DELAY_2: begin	
				// Provide address for data 3
				SRAM_address <= SRAM_address + 18'h00001;		
				VGA_SRAM_state <= S_VS_NEW_PIXEL_ROW_DELAY_3;		
			end
			S_VS_NEW_PIXEL_ROW_DELAY_3: begin		
				// Buffer data 1
				VGA_sram_data[2] <= SRAM_read_data;			
						
				VGA_SRAM_state <= S_VS_NEW_PIXEL_ROW_DELAY_4;
			end
			S_VS_NEW_PIXEL_ROW_DELAY_4: begin
				// Provide address for data 1
				SRAM_address <= SRAM_address + 18'h00001;
				
				// Buffer data 2
				VGA_sram_data[1] <= SRAM_read_data;			
				
				VGA_SRAM_state <= S_VS_NEW_PIXEL_ROW_DELAY_5;			
			end
			S_VS_NEW_PIXEL_ROW_DELAY_5: begin
				// Provide address for data 2
				SRAM_address <= SRAM_address + 18'h00001;
			
				// Buffer data 3
				VGA_sram_data[0] <= SRAM_read_data;
						
				VGA_SRAM_state <= S_VS_FETCH_PIXEL_DATA_0;			
			end
			S_VS_FETCH_PIXEL_DATA_0: begin
				// Provide address for data 3
				SRAM_address <= SRAM_address + 18'h00001;
						
				// Provide RGB data
				VGA_red <= {VGA_sram_data[2][15:8], 2'b00};
				VGA_green <= {VGA_sram_data[2][7:0], 2'b00};
				VGA_blue <= {VGA_sram_data[1][15:8], 2'b00};			
				
				VGA_SRAM_state <= S_VS_FETCH_PIXEL_DATA_1;			
			end
			S_VS_FETCH_PIXEL_DATA_1: begin		
				// Buffer data 1
				VGA_sram_data[2] <= SRAM_read_data;
						
				VGA_SRAM_state <= S_VS_FETCH_PIXEL_DATA_2;
			end
			S_VS_FETCH_PIXEL_DATA_2: begin				
				// Provide address for data 1
				SRAM_address <= SRAM_address + 18'h00001;
				
				// Buffer data 2
				VGA_sram_data[1] <= SRAM_read_data;
				
				// Provide RGB data
				VGA_red <= {VGA_sram_data[1][7:0], 2'b00};
				VGA_green <= {VGA_sram_data[0][15:8], 2'b00};
				VGA_blue <= {VGA_sram_data[0][7:0], 2'b00};
				
				VGA_SRAM_state <= S_VS_FETCH_PIXEL_DATA_3;
			end
			S_VS_FETCH_PIXEL_DATA_3: begin 
				// Provide address for data 2
				SRAM_address <= SRAM_address + 18'h00001;			
				
				// Buffer data 3
				VGA_sram_data[0] <= SRAM_read_data;
							
				if (pixel_X_pos < (VIEW_AREA_RIGHT - 2))
					// Still within one row
					VGA_SRAM_state <= S_VS_FETCH_PIXEL_DATA_0;
				else
					VGA_SRAM_state <= S_VS_WAIT_NEW_PIXEL_ROW;
			end	
			default: VGA_SRAM_state <= S_VS_WAIT_NEW_PIXEL_ROW;
			endcase
		end
		// To generate a border
		if (pixel_Y_pos == 10'd0 || pixel_Y_pos == 10'd479
		 || pixel_X_pos == 10'd0 || pixel_X_pos == 10'd639) begin
			VGA_red <= 10'h3FF;
			VGA_green <= 10'h3FF;
			VGA_blue <= 10'h3FF;
		end
	end
end

endmodule
