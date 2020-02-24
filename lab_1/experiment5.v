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
// It performs debouncing on the push buttons using a 1kHz clock, and a 10-bit shift register
// When PB0 is pressed, it will stop/start the counter
module experiment5 (
		/////// board clocks                      ////////////
		input logic CLOCK_50_I,                   // 50 MHz clock

		/////// pushbuttons/switches              ////////////
		input logic[3:0] PUSH_BUTTON_I,           // pushbuttons
		input logic[17:0] SWITCH_I,               // toggle switches

		/////// 7 segment displays/LEDs           ////////////
		output logic[6:0] SEVEN_SEGMENT_N_O[7:0], // 8 seven segment displays		
		output logic[8:0] LED_GREEN_O             // 9 green LEDs
);

logic resetn;

logic [15:0] clock_div_count;
logic clock_1kHz, clock_1kHz_buf;

logic [24:0] clock_1Hz_div_count;
logic clock_1Hz, clock_1Hz_buf;

logic [9:0] debounce_shift_reg [3:0];
logic [3:0] push_button_status, push_button_status_buf;
logic [3:0] led_green;
logic [2:0] led_green_out1, led_green_out2, led_green_out3;


logic [3:0] bcd1,bcd0;
logic [6:0] value_7_segment0, value_7_segment1, value_7_segment2,value_7_segment3;
logic stop_count, count_down,flag;

logic [3:0] button_pushed;

assign resetn = ~SWITCH_I[17];

// Clock division for 1kHz clock
always_ff @ (posedge CLOCK_50_I or negedge resetn) begin
	if (resetn == 1'b0) begin
		clock_div_count <= 16'h0000000;
	end else begin
		if (clock_div_count < 'd24999) begin
			clock_div_count <= clock_div_count + 16'd1;
		end else 
			clock_div_count <= 16'h0000;		
	end
end

always_ff @ (posedge CLOCK_50_I or negedge resetn) begin
	if (resetn == 1'b0) begin
		clock_1kHz <= 1'b1;
	end else begin
		if (clock_div_count == 'd0) clock_1kHz <= ~clock_1kHz;
	end
end

always_ff @ (posedge CLOCK_50_I or negedge resetn) begin
	if (resetn == 1'b0) begin
		clock_1kHz_buf <= 1'b1;	
	end else begin
		clock_1kHz_buf <= clock_1kHz;
	end
end

// Clock division for 1Hz clock
always_ff @ (posedge CLOCK_50_I or negedge resetn) begin
	if (resetn == 1'b0) begin
		clock_1Hz_div_count <= 25'h0000000;
	end else begin
		if (clock_1Hz_div_count < 'd24999999) begin
			clock_1Hz_div_count <= clock_1Hz_div_count + 25'd1;
		end else 
			clock_1Hz_div_count <= 25'h0000;		
	end
end

always_ff @ (posedge CLOCK_50_I or negedge resetn) begin
	if (resetn == 1'b0) begin
		clock_1Hz <= 1'b1;
	end else begin
		if (clock_1Hz_div_count == 'd0) clock_1Hz <= ~clock_1Hz;
	end
end

always_ff @ (posedge CLOCK_50_I or negedge resetn) begin
	if (resetn == 1'b0) begin
		clock_1Hz_buf <= 1'b1;	
	end else begin
		clock_1Hz_buf <= clock_1Hz;
	end
end

// Shift register for debouncing
always_ff @ (posedge CLOCK_50_I or negedge resetn) begin
	if (resetn == 1'b0) begin
		debounce_shift_reg[0] <= 10'd0;
		debounce_shift_reg[1] <= 10'd0;
		debounce_shift_reg[2] <= 10'd0;
		debounce_shift_reg[3] <= 10'd0;						
	end else begin
		if (clock_1kHz_buf == 1'b0 && clock_1kHz == 1'b1) begin
			debounce_shift_reg[0] <= {debounce_shift_reg[0][8:0], ~PUSH_BUTTON_I[0]};
			debounce_shift_reg[1] <= {debounce_shift_reg[1][8:0], ~PUSH_BUTTON_I[1]};
			debounce_shift_reg[2] <= {debounce_shift_reg[2][8:0], ~PUSH_BUTTON_I[2]};
			debounce_shift_reg[3] <= {debounce_shift_reg[3][8:0], ~PUSH_BUTTON_I[3]};									
		end
	end
end

// push_button_status will contained the debounced signal
always_ff @ (posedge CLOCK_50_I or negedge resetn) begin
	if (resetn == 1'b0) begin
		push_button_status <= 4'h0;
		push_button_status_buf <= 4'h0;
	end else begin
		push_button_status_buf <= push_button_status;
		push_button_status[0] <= |debounce_shift_reg[0];
		push_button_status[1] <= |debounce_shift_reg[1];
		push_button_status[2] <= |debounce_shift_reg[2];
		push_button_status[3] <= |debounce_shift_reg[3];						
	end
end

// Push button status is checked here for controlling the counter
always_ff @ (posedge CLOCK_50_I or negedge resetn) begin
	if (resetn == 1'b0) begin
		led_green <= 4'h0;
		stop_count <= 1'b0;
		count_down <= 1'b0;
	end else begin
		if (push_button_status_buf[0] == 1'b0 && push_button_status[0] == 1'b1 && flag == 1'b0) begin
			led_green[0] <= ~led_green[0];		
			stop_count <= ~stop_count;
		end
		if (push_button_status_buf[1] == 1'b0 && push_button_status[1] == 1'b1 && flag == 1'b0) begin
			led_green[1] <= ~led_green[1];
			count_down <= 1'b0;
		end
		if (push_button_status_buf[2] == 1'b0 && push_button_status[2] == 1'b1 && flag == 1'b0) begin 
			led_green[2] <= ~led_green[2];	
			count_down <= 1'b1;	
		end
		if (push_button_status_buf[3] == 1'b0 && push_button_status[3] == 1'b1 && flag == 1'b1) begin
			led_green[3] <= ~led_green[3];
			count_down <= ~count_down;
		end		
	end
end

///////////////////////////////////////////////////////////////
//       QUESTION 3- 7 SEGMENT DISPLAY OF PUSH BUTTON        //
///////////////////////////////////////////////////////////////

//Triggering falling edge (push button released)
always_ff @ (posedge CLOCK_50_I or negedge resetn) begin
	if (resetn == 1'b0) begin
		button_pushed <= 4'd4;
	end else begin
		if (push_button_status_buf[0] == 1'b1 && push_button_status[0] == 1'b0) begin
			button_pushed <= 4'd0;
		end
		if (push_button_status_buf[1] == 1'b1 && push_button_status[1] == 1'b0) begin
			button_pushed <= 4'd1;
		end
		if (push_button_status_buf[2] == 1'b1 && push_button_status[2] == 1'b0) begin 
			button_pushed <= 4'd2;
		end
		if (push_button_status_buf[3] == 1'b1 && push_button_status[3] == 1'b0) begin
			button_pushed <= 4'd3;
		end		
	end
end


///////////////////////////////////////////////////////
//                    QUESTION 2                     //
///////////////////////////////////////////////////////

// Counter is incremented here
always_ff @ (posedge CLOCK_50_I or negedge resetn) begin
	if (resetn == 1'b0) begin
		{bcd0,bcd1} <= 8'd0;
	end 
	else begin
		if (clock_1Hz_buf == 1'b0 && clock_1Hz == 1'b1) begin
			if (stop_count == 1'b0) begin
			   if (flag == 1'b0) begin
					if(count_down == 1'b0) begin
						bcd0 <= bcd0 + 4'd1;					
						if(bcd0 == 4'd9) begin
							bcd1 <= bcd1 + 4'd1;
							bcd0 <= 4'd0;
							if(bcd1 == 4'd9) begin
								bcd1 <= 4'd0;
							end
						end				
					end else begin
						bcd0 <= bcd0 - 4'd1;
						if(bcd0 == 4'd0) begin
							bcd1 <= bcd1 - 4'd1;
							bcd0 <= 4'd9;
							if(bcd1 == 4'd0) begin
								bcd1 <= 4'd9;
							end
						end
					end
				end
			end
		end
	end
end

always_comb
begin
	if ((bcd1 == 4'd5 && bcd0 == 4'd9 && count_down ==1'b0) || (bcd1 == 4'd0 && bcd0 == 4'd0 && count_down ==1'b1 )  )begin
		flag = 1'b1;
	end
	else begin
		flag = 1'b0;
	end
	
end


//////////////////////////////////////////////////////////////
//         QUESTION 3-7 SEGMENT DISPLAY OF SWITCHES         //
//////////////////////////////////////////////////////////////
logic [3:0] value_bit,value_range;
always_comb begin
	value_range = 1'b0;
	if (SWITCH_I[0]== 1'b1) begin
		value_bit = 4'd0;
	end else begin
		if (SWITCH_I[1] == 1'b1) begin
			value_bit = 4'd1;
		end else begin
			if (SWITCH_I[2] == 1'b1) begin
				value_bit = 4'd2;
			end else begin
				if (SWITCH_I[3] == 1'b1) begin
					value_bit = 4'd3;
				end else begin
					if (SWITCH_I[4] == 1'b1) begin
						value_bit = 4'd4;
					end else begin
						if (SWITCH_I[5] == 1'b1) begin
							value_bit = 4'd5;
						end else begin
							if (SWITCH_I[6] == 1'b1) begin
								value_bit = 4'd6;
							end else begin
								if (SWITCH_I[7] == 1'b1) begin
									value_bit = 4'd7;
								end else begin
									if (SWITCH_I[8] == 1'b1) begin
										value_bit = 4'd8;
									end else begin
										if (SWITCH_I[9] == 1'b1) begin
											value_bit = 4'd9;
										end else begin
											if (SWITCH_I[10]== 1'b1) begin
												value_bit = 4'd10;
											end else begin
												if (SWITCH_I[11]== 1'b1) begin
													value_bit = 4'd11;
												end else begin
													if (SWITCH_I[12]== 1'b1) begin
														value_bit = 4'd12;
													end else begin
														if (SWITCH_I[13]== 1'b1) begin
															value_bit = 4'd13;
														end else begin
															if (SWITCH_I[14]== 1'b1) begin
																value_bit = 4'd14;
															end else begin
																if (SWITCH_I[15] ==1'b1) begin
																	value_bit = 4'd15;
																end else begin
																	value_bit = 4'd0;
																	value_range = 1'd1;
																end
															end
														end
													end
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
end


// Instantiate modules for converting hex number to 7-bit value for the 7-segment display
convert_hex_to_seven_segment unit0 (
	.hex_value(bcd0), 
	.converted_value(value_7_segment0)
);

convert_hex_to_seven_segment unit1 (
	.hex_value(bcd1), 
	.converted_value(value_7_segment1)
);
convert_hex_to_seven_segment unit2 (
	.hex_value(value_bit), 
	.converted_value(value_7_segment2)
);

convert_hex_to_seven_segment unit3 (
	.hex_value(button_pushed),
	.converted_value(value_7_segment3)
);


assign	SEVEN_SEGMENT_N_O[0] = (resetn == 1'b0) ? 7'h7f:value_7_segment0,
		SEVEN_SEGMENT_N_O[1] = (resetn == 1'b0) ? 7'h7f:value_7_segment1,
		SEVEN_SEGMENT_N_O[2] = (resetn == 1'b0) ? 7'h7f:7'h7f,
		SEVEN_SEGMENT_N_O[3] = (resetn == 1'b0) ? 7'h7f:7'h7f,
		SEVEN_SEGMENT_N_O[4] = (resetn == 1'b0) ? 7'h7f:7'h7f,
		SEVEN_SEGMENT_N_O[5] = (resetn == 1'b0) ? 7'h7f:7'h7f,
		SEVEN_SEGMENT_N_O[6] = (resetn == 1'b0) ? 7'h7f:((button_pushed==4'd4)?7'h7f:value_7_segment3),
		SEVEN_SEGMENT_N_O[7] = (resetn == 1'b0) ? 7'h7f:((value_range==1'b0)?value_7_segment2:7'h7f);
		

/////////////////////////////////////////////////////////
//                    QUESTION 4                       //
/////////////////////////////////////////////////////////

assign LED_GREEN_O = (resetn == 1'b0) ? 9'd0 : {led_green_out1, led_green_out2, led_green_out3};

switch_to_led set0 (
	.switch_in(SWITCH_I[14:10]),
	.led_out(led_green_out1)
);
switch_to_led set1 (
	.switch_in(SWITCH_I[9:5]),
	.led_out(led_green_out2)
);
switch_to_led set2 (
	.switch_in(SWITCH_I[4:0]),
	.led_out(led_green_out3)
);


endmodule
