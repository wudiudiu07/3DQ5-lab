/*
Copyright by Henry Ko and Nicola Nicolici
Developed for the Digital Systems Design course (COE3DQ4)
Department of Electrical and Computer Engineering
McMaster University
Ontario, Canada
*/

`timescale 1ns/100ps
`default_nettype none

module lab3 (
		/////// board clocks                      ////////////
		input logic CLOCK_50_I,                   // 50 MHz clock

		/////// pushbuttons/switches              ////////////
		input logic[3:0] PUSH_BUTTON_I,           // pushbuttons
		input logic[17:0] SWITCH_I,               // toggle switches
		
		/////// PS2 interface                     ////////////
		input logic PS2_DATA_I,                   // PS2 data
		input logic PS2_CLOCK_I,                   // PS2 clock

		/////// 7 segment displays/LEDs           ////////////
		output logic[6:0] SEVEN_SEGMENT_N_O[7:0], // 8 seven segment displays
		output logic[8:0] LED_GREEN_O,            // 9 green LEDs
		output logic[17:0] LED_RED_O,             // 18 red LEDs

		/////// VGA interface                     ////////////
		output logic VGA_CLOCK_O,                 // VGA clock
		output logic VGA_HSYNC_O,                 // VGA H_SYNC
		output logic VGA_VSYNC_O,                 // VGA V_SYNC
		output logic VGA_BLANK_O,                 // VGA BLANK
		output logic VGA_SYNC_O,                  // VGA SYNC
		output logic[7:0] VGA_RED_O,              // VGA red
		output logic[7:0] VGA_GREEN_O,            // VGA green
		output logic[7:0] VGA_BLUE_O              // VGA blue
);

`include "VGA_Param.h"

logic system_resetn;

logic Clock_50, Clock_25, Clock_25_locked;

// For Push button
logic [3:0] PB_pushed;

// For VGA
logic [9:0] VGA_red, VGA_green, VGA_blue;
logic [9:0] pixel_X_pos;
logic [9:0] pixel_Y_pos;
logic VGA_vsync_buf;

// For Character ROM
logic [5:0] character_address;
logic rom_mux_output;

// Signals for taking the highest game score 
logic [5:0] lives_0_character_address, lives_1_character_address;
logic [5:0] score_0_character_address, score_1_character_address;
logic [5:0] highest_score_1_character_address, highest_score_0_character_address;
logic [5:0] highest_game_0_character_address, highest_game_1_character_address;
logic [5:0] counter_0_character_address, counter_1_character_address;

logic welcome_flag;

// Score / lives / games counter in BCD format, up to 99
logic [3:0] highest_score_0;
logic [3:0] highest_score_1;
logic [3:0] counter_0;
logic [3:0] counter_1;
logic [3:0] lives_0; 
logic [3:0] lives_1;
logic [3:0] score_0;
logic [3:0] score_1;
logic [3:0] highest_game_0, highest_game_1;
logic [3:0] game_counter_0, game_counter_1;

logic game_id;
logic time_left;

// For the Pong game
parameter OBJECT_SIZE = 10,
		  BAR_X_SIZE = 60,
		  BAR_Y_SIZE = 5,
		  BAR_SPEED = 5,
		  SCREEN_BOTTOM = 50;

typedef struct {
	logic [9:0] X_pos;
	logic [9:0] Y_pos;	
} coordinate_struct;

coordinate_struct object_coordinate, bar_coordinate;

logic object_X_direction, object_Y_direction;

logic object_on, bar_on, screen_bottom_on;

logic game_over;

logic [4:0]counter;

logic [24:0] clock_div_count;
logic count_enable;
logic one_sec_clock, one_sec_clock_buf;


enum logic {
	S_FLASH_INIT,
	S_FLASH_DELAY
} FLASH_state;

logic [9:0] object_speed;

// For 7 segment displays
logic [6:0] value_7_segment [6:0];

assign system_resetn = ~(SWITCH_I[17] || ~Clock_25_locked);

// PLL for clock generation
CLOCK_25_PLL CLOCK_25_PLL_inst (
	.areset(SWITCH_I[17]),
	.inclk0(CLOCK_50_I),
	.c0(Clock_50),
	.c1(Clock_25),
	.locked(Clock_25_locked)
);

// Push Button unit
// A PB_pushed detect signal output is used for starting the game
PB_Controller PB_unit (
	.Clock_25(Clock_25),
	.Resetn(system_resetn),
	.PB_signal(PUSH_BUTTON_I),	
	.PB_pushed(PB_pushed)
);

// VGA unit
logic [9:0] VGA_RED_O_long, VGA_GREEN_O_long, VGA_BLUE_O_long;

// welcome_flag is used to identify when to switch from vertical color bar to horizontal color bar
VGA_Controller VGA_unit(
	.Clock(Clock_25),
	.Resetn(system_resetn),

	.iRed(VGA_red),
	.iGreen(VGA_green),
	.iBlue(VGA_blue),
	.oCoord_X(pixel_X_pos),
	.oCoord_Y(pixel_Y_pos),
	
	//	VGA Side
	.oVGA_R(VGA_RED_O_long),
	.oVGA_G(VGA_GREEN_O_long),
	.oVGA_B(VGA_BLUE_O_long),
	.oVGA_H_SYNC(VGA_HSYNC_O),
	.oVGA_V_SYNC(VGA_VSYNC_O),
	.oVGA_SYNC(VGA_SYNC_O),
	.oVGA_BLANK(VGA_BLANK_O),
	.oVGA_CLOCK(VGA_CLOCK_O),
	.welcome_flag(welcome_flag)
);

assign VGA_RED_O = VGA_RED_O_long[9:2];
assign VGA_GREEN_O = VGA_GREEN_O_long[9:2];
assign VGA_BLUE_O = VGA_BLUE_O_long[9:2];

// Character ROM
char_rom char_rom_unit (
	.Clock(VGA_CLOCK_O),
	.Character_address(character_address),
	.Font_row(pixel_Y_pos[2:0]),
	.Font_col(pixel_X_pos[2:0]),	
	.Rom_mux_output(rom_mux_output)
);

// Convert hex to character address
convert_hex_to_char_rom_address convert_lives_to_char_rom_address0 (
	.hex_value(lives_0),
	.char_rom_address(lives_0_character_address)
);
convert_hex_to_char_rom_address convert_lives_to_char_rom_address1 (
	.hex_value(lives_1),
	.char_rom_address(lives_1_character_address)
);

convert_hex_to_char_rom_address convert_score_to_char_rom_address0 (
	.hex_value(score_0),
	.char_rom_address(score_0_character_address)
);
convert_hex_to_char_rom_address convert_score_to_char_rom_address1 (
	.hex_value(score_1),
	.char_rom_address(score_1_character_address)
);

convert_hex_to_char_rom_address convert_highest_score_to_char_rom_address0 (
	.hex_value(highest_score_0),
	.char_rom_address(highest_score_0_character_address)
);
convert_hex_to_char_rom_address convert_highest_score_to_char_rom_address1 (
	.hex_value(highest_score_1),
	.char_rom_address(highest_score_1_character_address)
);

convert_hex_to_char_rom_address convert_highest_game_to_char_rom_address0 (
	.hex_value(highest_game_0),
	.char_rom_address(highest_game_0_character_address)
);
convert_hex_to_char_rom_address convert_highest_game_to_char_rom_address1 (
	.hex_value(highest_game_1),
	.char_rom_address(highest_game_1_character_address)
);

convert_hex_to_char_rom_address convert_counter_game_to_char_rom_address0 (
	.hex_value(counter_0),
	.char_rom_address(counter_0_character_address)
);
convert_hex_to_char_rom_address convert_counter_game_to_char_rom_address1 (
	.hex_value(counter_1),
	.char_rom_address(counter_1_character_address)
);

assign object_speed = {7'd0, SWITCH_I[2:0]};

// A counter for clock division
always_ff @ (posedge CLOCK_50_I or negedge system_resetn) begin
	if (system_resetn == 1'b0) begin
		clock_div_count <= 25'h0000000;
	end else begin
		if (clock_div_count < 'd24999999) begin
			clock_div_count <= clock_div_count + 25'd1;
		end else 
			clock_div_count <= 25'h0000000;		
	end
end

// The value of one_sec_clock flip-flop is inverted every time the counter is reset to zero
always_ff @ (posedge CLOCK_50_I or negedge system_resetn) begin
	if (system_resetn == 1'b0) begin
		one_sec_clock <= 1'b1;
	end else begin
		if (clock_div_count == 'd0) one_sec_clock <= ~one_sec_clock;
	end
end

// A buffer on one_sec_clock for edge detection
always_ff @ (posedge CLOCK_50_I or negedge system_resetn) begin
	if (system_resetn == 1'b0) begin
		one_sec_clock_buf <= 1'b1;	
	end else begin
		one_sec_clock_buf <= one_sec_clock;
	end
end

// Pulse generation, that generates one pulse every time a posedge is detected on one_sec_clock
assign count_enable = (one_sec_clock_buf == 1'b0 && one_sec_clock == 1'b1);

// A FSM is used to generate 15 seconds of delay 
always_ff @ (posedge CLOCK_50_I or negedge system_resetn) begin
	if (system_resetn == 1'b0) begin
		FLASH_state <= S_FLASH_INIT;
		counter <= 5'd0;
		counter_0 <= 4'd5;
		counter_1 <= 4'd1;
	end else begin
		case (FLASH_state)
		S_FLASH_INIT : begin
			counter <= 5'd0;
			counter_0 <= 4'd5;
		    counter_1<=4'd1;
			if (lives_0 == 4'd0 && lives_1 == 4'd0) begin
				FLASH_state <= S_FLASH_DELAY;
			end 
		end
		S_FLASH_DELAY : begin
			if(count_enable == 1'b1) begin
				if(counter < 5'd16) begin
					counter <= counter + 5'd1;
				end
				else begin
					FLASH_state <= S_FLASH_INIT;
				end
				// counter_0 and counter_1 will be used "time left YY" message
				counter_0 <= counter_0 - 4'd1;
				if(counter_0 == 4'd0) begin
					counter_1 <= counter_1 - 4'd1;
					counter_0 <= 4'd9;
				end 
			end
		end
		default: FLASH_state <= S_FLASH_INIT;
		endcase
	end
end

// RGB signals
always_comb begin
	VGA_red = 10'd0;
	VGA_green = 10'd0;
	VGA_blue = 10'd0;
	// Use (lives_0 || live_1) to detect the condition which no lives are left, game over
	if (object_on && (game_start == 2'd1) && (lives_0 || lives_1))begin
		// Yellow object
		VGA_red = 10'h3FF;
		VGA_green = 10'h3FF;
	end
	
	if (bar_on && (game_start == 2'd1) && (lives_0 || lives_1))begin
		// Blue bar
		VGA_blue = 10'h3FF;
	end
	
	if (screen_bottom_on && (game_start == 2'd1) && (lives_0 || lives_1)) begin
		// Red border
		VGA_red = 10'h3FF;
	end
	
	if (rom_mux_output && (game_start == 2'd1)) begin
		// Display text
		VGA_blue = 10'h3FF;
		VGA_green = 10'h3FF;
	end
	
	// Implement video color bar 
	if (game_start == 2'd0) begin
		if (welcome_flag == 1'b0) begin
			VGA_red = {10{~pixel_Y_pos[8]}};
			VGA_green = {10{~pixel_Y_pos[7]}};
			VGA_blue = {10{~pixel_Y_pos[6]}}; 
		end
		if (welcome_flag == 1'b1) begin////NEED TO BE EDITED!!!!!!////
			if (pixel_X_pos[9:3] >= 7'd0 && pixel_X_pos[9:3] <= 7'd9) begin
				VGA_red = 10'h3FF; VGA_green = 10'h3FF; VGA_blue = 10'h3FF; end ///111
			else if (pixel_X_pos[9:3] >= 7'd10 && pixel_X_pos[9:3] <= 7'd19) begin
				VGA_red = 10'h3FF; VGA_green = 10'h3FF;VGA_blue = 10'd0; end    ///110
			else if (pixel_X_pos[9:3] >= 7'd20 && pixel_X_pos[9:3] <= 7'd29) begin
				VGA_red = 10'h3FF; VGA_green = 10'd0; VGA_blue = 10'h3FF; end   ///101
			else if (pixel_X_pos[9:3] >= 7'd30 && pixel_X_pos[9:3] <= 7'd39) begin
				VGA_red = 10'h3FF; VGA_green = 10'd0; VGA_blue = 10'hd0; end    ///100
			else if (pixel_X_pos[9:3] >= 7'd40 && pixel_X_pos[9:3] <= 7'd49) begin
				VGA_red = 10'd0; VGA_green = 10'h3FF; VGA_blue = 10'h3FF; end   ///011
			else if (pixel_X_pos[9:3] >= 7'd50 && pixel_X_pos[9:3] <= 7'd59) begin
				VGA_red = 10'd0; VGA_green = 10'h3FF; VGA_blue = 10'd0; end     ///010
			else if (pixel_X_pos[9:3] >= 7'd60 && pixel_X_pos[9:3] <= 7'd69) begin
				VGA_red = 10'd0; VGA_green = 10'd0; VGA_blue = 10'h3FF; end     ///001
			else if (pixel_X_pos[9:3] >= 7'd70 && pixel_X_pos[9:3] <= 7'd79) begin
				VGA_red = 10'd0; VGA_green = 10'd0; VGA_blue = 10'd0;           ///000
			end
		end
	end
end

always_ff @ (posedge Clock_25 or negedge system_resetn) begin
	if (system_resetn == 1'b0) begin
		VGA_vsync_buf <= 1'b0;
	end else begin
		VGA_vsync_buf <= VGA_VSYNC_O;
	end
end

// A seperate always_ff logic to determine the highest score for message "Game YY score ZZ"
always_ff @ (posedge Clock_25 or negedge system_resetn) begin
	if (system_resetn == 1'b0) begin
		highest_score_0 <= 4'd0;
		highest_score_1 <= 4'd0;
		highest_game_0 <= 4'd0;
		highest_game_1 <= 4'd0;
	
	end else begin
		// Condition 1: when decimal BCD is greater than previous game
		if (score_1 > highest_score_1) begin
			 highest_score_1 <= score_1;
			 highest_score_0 <= score_0;
			 highest_game_0  <= game_counter_0;
			 highest_game_1  <= game_counter_1;
		// Condition 2: when decimal BCD is equal to previous game
		end else if (score_1 == highest_score_1) begin
			if (score_0 > highest_score_0) begin
				highest_score_0 <= score_0;
				highest_game_0  <= game_counter_0;
			    highest_game_1  <= game_counter_1;
			end
		end
		// Condition 3: when decimal BCD is less than previous game, highest score/game takes its own value
	end
end


// Updating location of the object (Ball)
always_ff @ (posedge Clock_25 or negedge system_resetn) begin
	if (system_resetn == 1'b0) begin
		object_coordinate.X_pos <= 10'd200;
		object_coordinate.Y_pos <= 10'd50;
		object_X_direction <= 1'b1;	
		object_Y_direction <= 1'b1;	
		score_0 <= 4'd0;		
		score_1 <= 4'd0;		
		lives_0 <= 4'd6;
		lives_1 <= 4'd0;
		game_over <= 1'b0;
		game_counter_0 <= 4'd1;
		game_counter_1<= 4'd0;
	end 
	else if (counter == 5'd16) begin
		object_coordinate.X_pos <= 10'd200;
		object_coordinate.Y_pos <= 10'd50;
		object_X_direction <= 1'b1;	
		object_Y_direction <= 1'b1;	
		score_1 <= 4'd0;
		score_0 <= 4'd0;		
		lives_0 <= 4'd6;
		lives_1 <= 4'd0;
		game_over <= 1'b0;
	end else begin
		// Update movement during vertical blanking
		
		if (VGA_vsync_buf && ~VGA_VSYNC_O && game_over == 1'b0) begin
			if (object_X_direction == 1'b1) begin
				// Moving right
				if (object_coordinate.X_pos < H_SYNC_ACT - OBJECT_SIZE - object_speed) 
					object_coordinate.X_pos <= object_coordinate.X_pos + object_speed;
				else
					object_X_direction <= 1'b0;
			end else begin
				// Moving left
				if (object_coordinate.X_pos >= object_speed) 		
					object_coordinate.X_pos <= object_coordinate.X_pos - object_speed;		
				else
					object_X_direction <= 1'b1;
			end
			
			if (object_Y_direction == 1'b1) begin
				// Moving down
				if (object_coordinate.Y_pos <= bar_coordinate.Y_pos - OBJECT_SIZE - object_speed)
					object_coordinate.Y_pos <= object_coordinate.Y_pos + object_speed;
				else begin
					if (object_coordinate.X_pos >= bar_coordinate.X_pos 							          // Left edge of object is within bar
					 && object_coordinate.X_pos + OBJECT_SIZE <= bar_coordinate.X_pos + BAR_X_SIZE 	// Right edge of object is within bar
					) begin
						// Hit the bar
						object_Y_direction <= 1'b0;
						score_0 <= score_0 + 4'd1;				
						if(score_0 == 4'd9) begin
							score_1 <= score_1 + 4'd1;
							score_0 <= 4'd0;
							if(score_1 == 4'd9) begin
								score_1 <= 4'd0;
							end
						end		
					end else begin
						// Hit the bottom of screen
						lives_0 <= lives_0 - 4'd1;
						if(lives_0 == 4'd0) begin
							lives_1 <= lives_1 - 4'd1;
							lives_0 <= 4'd9;
							if(lives_1 == 4'd0) begin
								lives_1 <= 4'd9;
							end
						end
						if(FLASH_state == 1'b1) begin
							lives_0 <= 4'd0;
							lives_1 <= 4'd0;
						end
					
						if (lives_0 || lives_1) begin
							// Restart the object
							object_X_direction <= SWITCH_I[16];	
							object_Y_direction <= SWITCH_I[15];
							
							object_coordinate.X_pos <= 10'd200;
							object_coordinate.Y_pos <= 10'd50;
						end else begin
							// Game over
							game_over <= 1'b1;
							
							// A game counter counting how many games has been played
							game_counter_0 <= game_counter_0 + 4'd1;				
							if (game_counter_0 == 4'd9) begin
								game_counter_1 <= game_counter_1 + 4'd1;
								game_counter_0 <= 4'd0;
								
								if (game_counter_1 == 4'd9) begin
									game_counter_1 <= 4'd0;
								end
							end								
						end				
					end
				end
			end else begin
				// Moving up
				if (object_coordinate.Y_pos >= object_speed) 				
					object_coordinate.Y_pos <= object_coordinate.Y_pos - object_speed;		
				else
					object_Y_direction <= 1'b1;
			end		
		end
	end
end

// Update the location of bar
always_ff @ (posedge Clock_25 or negedge system_resetn) begin
	if (system_resetn == 1'b0) begin
		bar_coordinate.X_pos <= 10'd200;
		bar_coordinate.Y_pos <= 10'd0;
	end else begin
		bar_coordinate.Y_pos <= V_SYNC_ACT-BAR_Y_SIZE-SCREEN_BOTTOM;
		
		// Update the movement during vertical blanking using PS2 keyboard input A and S
		if (VGA_vsync_buf && ~VGA_VSYNC_O) begin
			if ((S_key && PS2_make_code) == 1'b1) begin
				// Move bar right
				if (bar_coordinate.X_pos < H_SYNC_ACT - BAR_X_SIZE - BAR_SPEED) 		
					bar_coordinate.X_pos <= bar_coordinate.X_pos + BAR_SPEED;
			end else begin
				if ((A_key && PS2_make_code) == 1'b1) begin
					// Move bar left
					if (bar_coordinate.X_pos > BAR_SPEED) 		
						bar_coordinate.X_pos <= bar_coordinate.X_pos - BAR_SPEED;
				end 	
			end
		end
	end
end

// Check if the ball should be displayed or not
always_comb begin	
	if (pixel_X_pos >= object_coordinate.X_pos && pixel_X_pos < object_coordinate.X_pos + OBJECT_SIZE
	 && pixel_Y_pos >= object_coordinate.Y_pos && pixel_Y_pos < object_coordinate.Y_pos + OBJECT_SIZE
	 && game_over == 1'b0) 
		object_on = 1'b1;
	else 
		object_on = 1'b0;
end

// Check if the bar should be displayed or not
always_comb begin
	if (pixel_X_pos >= bar_coordinate.X_pos && pixel_X_pos < bar_coordinate.X_pos + BAR_X_SIZE
	 && pixel_Y_pos >= bar_coordinate.Y_pos && pixel_Y_pos < bar_coordinate.Y_pos + BAR_Y_SIZE 
	 && game_over == 1'b0) 
		bar_on = 1'b1;
	else 
		bar_on = 1'b0;
end

// Check if the line on the bottom of the screen should be displayed or not
always_comb begin
	if ((pixel_Y_pos == V_SYNC_ACT - SCREEN_BOTTOM + 1) && game_over == 1'b0)
		screen_bottom_on = 1'b1;
	else 
		screen_bottom_on = 1'b0;
end


// Display text
always_comb begin
	character_address = 6'o40; // Show space by default
	
	// 8 x 8, display lives ## and score ##
	if (pixel_Y_pos[9:3] == ((V_SYNC_ACT - SCREEN_BOTTOM + 20) >> 3) && (lives_0 || lives_1)) begin
		// Reach the section where the text is displayed
		case (pixel_X_pos[9:3])
			7'd1: character_address = 6'o14; // L
			7'd2: character_address = 6'o11; // I
			7'd3: character_address = 6'o26; // V
			7'd4: character_address = 6'o05; // E
			7'd5: character_address = 6'o23; // S
			7'd6: character_address = 6'o40; // space
			7'd7: character_address = lives_1_character_address;
			7'd8: character_address = lives_0_character_address;
			
			7'd72: character_address = 6'o23; // S
			7'd73: character_address = 6'o03; // C
			7'd74: character_address = 6'o17; // O
			7'd75: character_address = 6'o22; // R
			7'd76: character_address = 6'o05; // E
			7'd77: character_address = 6'o40; // space
			7'd78: character_address = score_1_character_address;
			7'd79: character_address = score_0_character_address;	
		endcase
	end
		////////////// LAST GAME SCORE WAS XX ////////////////
		if (pixel_Y_pos[9:3] == ((V_SYNC_ACT -300) >> 3) && (lives_0 == 4'd0 && lives_1 == 4'd0)) begin
		// Reach the section where the text is displayed
		case (pixel_X_pos[9:3])
			7'd30: character_address = 6'o14; // L
			7'd31: character_address = 6'o01; // A
			7'd32: character_address = 6'o23; // S
			7'd33: character_address = 6'o24; // T
			7'd34: character_address = 6'o40; // space
			7'd35: character_address = 6'o07; // G
			7'd36: character_address = 6'o01; // A
			7'd37: character_address = 6'o15; // M
			7'd38: character_address = 6'o05; // E
			7'd39: character_address = 6'o40; // SPACE
			7'd40: character_address = 6'o23; // S
			7'd41: character_address = 6'o03; // C
			7'd42: character_address = 6'o17; // O
			7'd43: character_address = 6'o22; // R 
			7'd44: character_address = 6'o05; // E
			7'd45: character_address = 6'o40; // SPACE
			7'd46: character_address = 6'o27; // W
			7'd47: character_address = 6'o01; // A
			7'd48: character_address = 6'o23; // S
			7'd49: character_address = 6'o40; // SPACE
			7'd50: character_address = score_1_character_address; // Z
			7'd51: character_address = score_0_character_address; // Z
		endcase
		end
		
		////////////// GAME YY SCORE ZZ ////////////////		
		if (pixel_Y_pos[9:3] == ((V_SYNC_ACT -285) >> 3) && (lives_0 == 4'd0&&lives_1 == 4'd0)) begin
		// Reach the section where the text is displayed
		case (pixel_X_pos[9:3])
			7'd30: character_address = 6'o07; // G
			7'd31: character_address = 6'o01; // A
			7'd32: character_address = 6'o15; // M
			7'd33: character_address = 6'o05; // E
			7'd34: character_address = 6'o40; // space
			7'd35: character_address = highest_game_1_character_address; // Y
			7'd36: character_address = highest_game_0_character_address; // Y
			7'd37: character_address = 6'o40; // SPACE
			7'd38: character_address = 6'o23; // S
			7'd39: character_address = 6'o03; // C
			7'd40: character_address = 6'o17; // O
			7'd41: character_address = 6'o22; // R 
			7'd42: character_address = 6'o05; // E
			7'd43: character_address = 6'o40; // SPACE
			7'd44: character_address = highest_score_1_character_address; // Z
			7'd45: character_address = highest_score_0_character_address; // Z				
		endcase
	end
	
	////////////// TIME LEFT WW ///////////////
	if (pixel_Y_pos[9:3] == ((V_SYNC_ACT -270) >> 3) && (lives_0 == 4'd0&&lives_1 == 4'd0)) begin
		// Reach the section where the text is displayed
		case (pixel_X_pos[9:3])
			7'd30: character_address = 6'o24; // T
			7'd31: character_address = 6'o11; // I
			7'd32: character_address = 6'o15; // M
			7'd33: character_address = 6'o05; // E
			7'd34: character_address = 6'o40; // space
			7'd35: character_address = 6'o14; // L
			7'd36: character_address = 6'o05; // E
			7'd37: character_address = 6'o06; // F
			7'd38: character_address = 6'o24; // T
			7'd39: character_address = 6'o40; // SPACE 
			7'd40: character_address = counter_1_character_address; // W
			7'd41: character_address = counter_0_character_address; // W 
				
		endcase
	end
	
end

convert_hex_to_seven_segment unit1 (
	.hex_value( lives_0), 
	.converted_value(value_7_segment[1])
);

convert_hex_to_seven_segment unit0 (
	.hex_value(score_0), 
	.converted_value(value_7_segment[0])
);

assign	SEVEN_SEGMENT_N_O[0] = value_7_segment[0],
		SEVEN_SEGMENT_N_O[1] = 7'h7f,
		SEVEN_SEGMENT_N_O[2] = value_7_segment[1],
		SEVEN_SEGMENT_N_O[3] = 7'h7f,
		SEVEN_SEGMENT_N_O[4] = 7'h7f,
		SEVEN_SEGMENT_N_O[5] = 7'h7f,
		SEVEN_SEGMENT_N_O[6] = value_7_segment[3],
		SEVEN_SEGMENT_N_O[7] = value_7_segment[2];

assign LED_RED_O = {system_resetn, 15'd0, object_X_direction, object_Y_direction};
assign LED_GREEN_O = {game_over, 4'd0, PB_pushed};

///////////////PS2 setting///////////////
logic [7:0] PS2_code;
logic PS2_code_ready;
logic PS2_code_ready_buf;
logic PS2_make_code;
logic A_key,S_key;
logic game_start;
logic [23:0] seven_segment_shift_reg;

PS2_controller ps2_unit (
	.Clock_50(Clock_50),
	.Resetn(system_resetn),
	.PS2_clock(PS2_CLOCK_I),
	.PS2_data(PS2_DATA_I),
	.PS2_code(PS2_code),
	.PS2_code_ready(PS2_code_ready),
	.PS2_make_code(PS2_make_code),
	.A_key(A_key),
	.S_key(S_key)
);

always_ff @ (posedge Clock_50 or negedge system_resetn) begin
	if (system_resetn == 1'b0) begin
		PS2_code_ready_buf <= 1'b0;
		game_start <= 2'b00;
		seven_segment_shift_reg <= 24'h000000;
	end else begin
		PS2_code_ready_buf <= PS2_code_ready;
	if (PS2_code_ready && ~PS2_code_ready_buf && PS2_make_code) begin
		game_start <= 2'd1;	
		seven_segment_shift_reg <= {seven_segment_shift_reg[15:0], PS2_code};
		end
	end
end

convert_hex_to_seven_segment unit2 (
	.hex_value(counter),
	.converted_value(value_7_segment[2])
);
convert_hex_to_seven_segment unit3 (
	.hex_value(S_key && PS2_make_code),
	.converted_value(value_7_segment[3])
);
endmodule
