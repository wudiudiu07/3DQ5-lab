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
// It connects the PS2 controller and the LCD controller
// It first stores the typed keys onto 4 data registers
// When the data registers are full, it will update the LCD with the 4 new characters
module experiment5 (
		/////// board clocks                      ////////////
		input logic CLOCK_50_I,                   // 50 MHz clock

		/////// switches                          ////////////
		input logic[17:0] SWITCH_I,               // toggle switches
      input logic[3:0] PUSH_BUTTON_I,           // pushbuttons
		
		
		/////// 7 segment displays/LEDs           ////////////
		output logic[6:0] SEVEN_SEGMENT_N_O[7:0], // 8 seven segment displays
		output logic[8:0] LED_GREEN_O,            // 9 green LEDs
		output logic[17:0] LED_RED_O,             // 18 red LEDs
		
		/////// PS2                               ////////////
		input logic PS2_DATA_I,                   // PS2 data
		input logic PS2_CLOCK_I,                  // PS2 clock

		/////// LCD display                       ////////////
		output logic LCD_POWER_O,                 // LCD power ON/OFF
		output logic LCD_BACK_LIGHT_O,            // LCD back light ON/OFF
		output logic LCD_READ_WRITE_O,            // LCD read/write select, 0 = Write, 1 = Read
		output logic LCD_EN_O,                    // LCD enable
		output logic LCD_COMMAND_DATA_O,          // LCD command/data select, 0 = Command, 1 = Data
		output [7:0] LCD_DATA_IO                  // LCD data bus 8 bits
);

logic resetn;

enum logic [4:0] {
	S_LCD_INIT,
	S_LCD_INIT_WAIT,
	S_IDLE_SINGLE,
	S_IDLE_SIXTEEN,
	S_LCD_WAIT_ROM_UPDATE,
	S_LCD_ISSUE_INSTRUCTION,
	S_LCD_FINISH_INSTRUCTION_SINGLE,
	S_LCD_FINISH_INSTRUCTION_SIXTEEN,
	S_LCD_ISSUE_CHANGE_LINE,
	S_LCD_FINISH_CHANGE_LINE,
	S_LCD_RESET
} state;

enum logic {
	S_LED_INIT,
	S_LED_DELAY
} LED_state;

logic [3:0] data_counter;

logic [7:0] data_reg [15:0];
logic [7:0] data_store [15:0];
logic [7:0] data_compare [15:0];

logic [7:0] PS2_code;
logic PS2_code_ready, PS2_code_ready_buf;
logic PS2_make_code;
logic PS2_upper_lower;
logic PS2_upper_lower_reg [15:0];

logic [2:0] LCD_init_index;
logic [8:0] LCD_init_sequence;
logic [8:0] LCD_instruction;
logic [8:0] LCD_seq;
logic [7:0] LCD_code;
logic [3:0] LCD_position, LCD_pos_detect;
logic LCD_line;
logic first_char;
logic last_char, erase_sel;
logic [3:0]counter_d;

logic LCD_start;
logic LCD_done;
logic flag;
logic LCD_Line_detect, LCD_erased;

logic [6:0] value_7_segment[6:0];

assign resetn = ~SWITCH_I[17];

// PS2 unit
PS2_controller PS2_unit (
	.Clock_50(CLOCK_50_I),
	.Resetn(resetn),
	
	.PS2_clock(PS2_CLOCK_I),
	.PS2_data(PS2_DATA_I),
	
	.PS2_code(PS2_code),
	.PS2_code_ready(PS2_code_ready),
	.PS2_make_code(PS2_make_code),
	.PS2_upper_lower(PS2_upper_lower)
);

// ROM for translate PS2 code to LCD code, deciding capital letter or small letter
PS2_to_LCD_ROM	PS2_to_LCD_ROM_inst (
	.address ( {(LCD_line == 1'b1) ? PS2_upper_lower : PS2_upper_lower_reg[15], (LCD_line == 1'b1)? PS2_code: data_reg[15]} ),
	.clock ( CLOCK_50_I ),
	.q ( LCD_code )
	);

// LCD unit
LCD_controller LCD_unit (
	.Clock_50(CLOCK_50_I),
	.Resetn(resetn),
	.LCD_start(LCD_start),
	.LCD_instruction(LCD_instruction),
	.LCD_done(LCD_done),
	
	// LCD side
	.LCD_power(LCD_POWER_O),
	.LCD_back_light(LCD_BACK_LIGHT_O),
	.LCD_read_write(LCD_READ_WRITE_O),
	.LCD_enable(LCD_EN_O),
	.LCD_command_data_select(LCD_COMMAND_DATA_O),
	.LCD_data_io(LCD_DATA_IO)
);

///////////////////////////////////////////////////////////////////////////
//                     Clock Division for 1Hz Clock                      //
///////////////////////////////////////////////////////////////////////////

logic [24:0] clock_div_count;
logic count_enable;
logic [3:0] counter;
logic one_sec_clock, one_sec_clock_buf;

logic [15:0] clock_div_count_1kHz;
logic clock_1kHz, clock_1kHz_buf;

// A counter for clock division
always_ff @ (posedge CLOCK_50_I or negedge resetn) begin
	if (resetn == 1'b0) begin
		clock_div_count <= 25'h0000000;
	end else begin
		if (clock_div_count < 'd24999999) begin
			clock_div_count <= clock_div_count + 25'd1;
		end else 
			clock_div_count <= 25'h0000000;		
	end
end

// The value of one_sec_clock flip-flop is inverted every time the counter is reset to zero
always_ff @ (posedge CLOCK_50_I or negedge resetn) begin
	if (resetn == 1'b0) begin
		one_sec_clock <= 1'b1;
	end else begin
		if (clock_div_count == 'd0) one_sec_clock <= ~one_sec_clock;
	end
end

// A buffer on one_sec_clock for edge detection
always_ff @ (posedge CLOCK_50_I or negedge resetn) begin
	if (resetn == 1'b0) begin
		one_sec_clock_buf <= 1'b1;	
	end else begin
		one_sec_clock_buf <= one_sec_clock;
	end
end

/////////////////////////////////////////////////////////////////////////////
//                      Clock division for 1kHz clock                      //
/////////////////////////////////////////////////////////////////////////////

always_ff @ (posedge CLOCK_50_I or negedge resetn) begin
	if (resetn == 1'b0) begin
		clock_div_count_1kHz <= 16'h0000000;
	end else begin
		if (clock_div_count_1kHz < 'd24999) begin
			clock_div_count_1kHz <= clock_div_count_1kHz + 16'd1;
		end else 
			clock_div_count_1kHz <= 16'h0000;		
	end
end

always_ff @ (posedge CLOCK_50_I or negedge resetn) begin
	if (resetn == 1'b0) begin
		clock_1kHz <= 1'b1;
	end else begin
		if (clock_div_count_1kHz == 'd0) clock_1kHz <= ~clock_1kHz;
	end
end

always_ff @ (posedge CLOCK_50_I or negedge resetn) begin
	if (resetn == 1'b0) begin
		clock_1kHz_buf <= 1'b1;	
	end else begin
		clock_1kHz_buf <= clock_1kHz;
	end
end
//////////////////////////////////////////////////////////////////////////////


// Pulse generation, that generates one pulse every time a posedge is detected on one_sec_clock
assign count_enable = (one_sec_clock_buf == 1'b0 && one_sec_clock == 1'b1);


//////////////////////////////////////////////////////////////////////////////
//                    FSM FOR HANDLING 5 SECONDS DELAY                      //
//////////////////////////////////////////////////////////////////////////////

always_ff @ (posedge CLOCK_50_I or negedge resetn) begin
	if (resetn == 1'b0) begin
		LED_state <= S_LED_INIT;
		flag <= 1'b0;
		counter <= 4'd0;
	end else begin
		case (LED_state)
		S_LED_INIT : begin
			flag <= 1'b0;
			counter <= 4'd0;
			if (LCD_line == 1'b1 && LCD_Line_detect == 1'b0 && data_counter == 4'd15 && LCD_position == 4'd0) begin
				LED_state <= S_LED_DELAY;
			end 
		end
		S_LED_DELAY : begin
			if(count_enable == 1'b1) begin
				flag <= 1'b1;
				if(counter < 4'd5) begin
					counter <= counter + 4'd1;
				end else begin
					LED_state <= S_LED_INIT;
				end
			end
		end
		default: LED_state <= S_LED_INIT;
		endcase
	end
end

//////////////////////////////////////////////////////////////////////////////
//                 FSM FOR HANDLING PS2_TO_LCD OPERATION                    //
//////////////////////////////////////////////////////////////////////////////

always_ff @ (posedge CLOCK_50_I or negedge resetn) begin
	if (resetn == 1'b0) begin
		state <= S_LCD_INIT;
		LCD_erased <= 1'b0;
		LCD_init_index <= 3'd0;
		LCD_start <= 1'b0;
		LCD_instruction <= 9'd0;
		LCD_line <= 1'b1;
		LCD_Line_detect <= 1'b1;
		PS2_code_ready_buf <= 1'b0;
		LCD_position <= 4'h0;
		data_counter <= 4'd0;
		PS2_upper_lower_reg[15] <= 1'b0;
		PS2_upper_lower_reg[14] <= 1'b0;
		PS2_upper_lower_reg[13] <= 1'b0;
		PS2_upper_lower_reg[12] <= 1'b0;
		PS2_upper_lower_reg[11] <= 1'b0;
		PS2_upper_lower_reg[10] <= 1'b0;
		PS2_upper_lower_reg[9] <= 1'b0;
		PS2_upper_lower_reg[8] <= 1'b0;
		PS2_upper_lower_reg[7] <= 1'b0;
		PS2_upper_lower_reg[6] <= 1'b0;
		PS2_upper_lower_reg[5] <= 1'b0;
		PS2_upper_lower_reg[4] <= 1'b0;
		PS2_upper_lower_reg[3] <= 1'b0;
		PS2_upper_lower_reg[2] <= 1'b0;
		PS2_upper_lower_reg[1] <= 1'b0;
		data_reg[15] <= 8'h00;
		data_reg[14] <= 8'h00;
		data_reg[13] <= 8'h00;
		data_reg[12] <= 8'h00;
		data_reg[11] <= 8'h00;
		data_reg[10] <= 8'h00;
		data_reg[9]  <= 8'h00;
		data_reg[8]  <= 8'h00;
		data_reg[7]  <= 8'h00;
		data_reg[6]  <= 8'h00;
		data_reg[5]  <= 8'h00;
		data_reg[4]  <= 8'h00;
		data_reg[3]  <= 8'h00;
		data_reg[2]  <= 8'h00;
		data_reg[1]  <= 8'h00;
		data_reg[0]  <= 8'h00;	
	//push button is pressed 4 consecutive times to erase immdietely after LCD erase has been performed 
	end else if (button_erase==1'b1 && LCD_erased == 1'b1) begin
		state <= S_LCD_INIT;
		LCD_init_index <= 3'd0;
		LCD_start <= 1'b0;
		LCD_instruction <= 9'd0;
		LCD_line <= 1'b1;
		LCD_Line_detect <= 1'b1;
		PS2_code_ready_buf <= 1'b0;
		LCD_position <= 4'h0;
		data_counter <= 4'd0;
		PS2_upper_lower_reg[15] <= 1'b0;
		PS2_upper_lower_reg[14] <= 1'b0;
		PS2_upper_lower_reg[13] <= 1'b0;
		PS2_upper_lower_reg[12] <= 1'b0;
		PS2_upper_lower_reg[11] <= 1'b0;
		PS2_upper_lower_reg[10] <= 1'b0;
		PS2_upper_lower_reg[9] <= 1'b0;
		PS2_upper_lower_reg[8] <= 1'b0;
		PS2_upper_lower_reg[7] <= 1'b0;
		PS2_upper_lower_reg[6] <= 1'b0;
		PS2_upper_lower_reg[5] <= 1'b0;
		PS2_upper_lower_reg[4] <= 1'b0;
		PS2_upper_lower_reg[3] <= 1'b0;
		PS2_upper_lower_reg[2] <= 1'b0;
		PS2_upper_lower_reg[1] <= 1'b0;
		data_reg[15] <= 8'h00;
		data_reg[14] <= 8'h00;
		data_reg[13] <= 8'h00;
		data_reg[12] <= 8'h00;
		data_reg[11] <= 8'h00;
		data_reg[10] <= 8'h00;
		data_reg[9]  <= 8'h00;
		data_reg[8]  <= 8'h00;
		data_reg[7]  <= 8'h00;
		data_reg[6]  <= 8'h00;
		data_reg[5]  <= 8'h00;
		data_reg[4]  <= 8'h00;
		data_reg[3]  <= 8'h00;
		data_reg[2]  <= 8'h00;
		data_reg[1]  <= 8'h00;
		data_reg[0]  <= 8'h00;	
	end else begin
		PS2_code_ready_buf <= PS2_code_ready;		

		case (state)
		S_LCD_INIT: begin
			// Initialize LCD
			///////////////////
			// DO NOT CHANGE //
			///////////////////
			LCD_instruction <= LCD_init_sequence;
			LCD_start <= 1'b1;
			state <= S_LCD_INIT_WAIT;
		end
		S_LCD_INIT_WAIT: begin
			///////////////////
			// DO NOT CHANGE //
			///////////////////
			if (LCD_start == 1'b1) begin
				LCD_start <= 1'b0;
			end else begin
				if (LCD_done == 1'b1) begin
					LCD_init_index <= LCD_init_index + 3'd1;
					if (LCD_init_index < 3'd4) 
						state <= S_LCD_INIT;
					else begin
						// Finish initializing LCD
						if (LCD_line == 1'b1)begin state <= S_IDLE_SINGLE;end
						else begin state <= S_IDLE_SIXTEEN; end
						LCD_position <= 4'h0;
					end
				end
			end
		end
		
		S_IDLE_SINGLE: begin
		if(LCD_start == 1'b1) begin
			LCD_start <= 1'b0;
		end
		if (PS2_code_ready && ~PS2_code_ready_buf && PS2_make_code == 1'b1)begin
				data_store[15] <= data_store[14];
				data_store[14] <= data_store[13];
				data_store[13] <= data_store[12];
				data_store[12] <= data_store[11];
				data_store[11] <= data_store[10];
				data_store[10] <= data_store[9];
				data_store[9]  <= data_store[8];
				data_store[8]  <= data_store[7];
				data_store[7]  <= data_store[6];
				data_store[6]  <= data_store[5];
				data_store[5]  <= data_store[4];
				data_store[4]  <= data_store[3];
				data_store[3]  <= data_store[2];
				data_store[2]  <= data_store[1];
				data_store[1]  <= data_store[0];
				data_store[0]  <= PS2_code;
				state <= S_LCD_ISSUE_INSTRUCTION;
			end
			
		end
		
		S_IDLE_SIXTEEN: begin
			// Scan code is detected
			if (PS2_code_ready && ~PS2_code_ready_buf && PS2_make_code == 1'b1) begin
				if (data_counter < 4'd15) begin
					data_counter <= data_counter + 4'd1;
				end else begin
					// Send the 4 data to LCD
					data_counter <= 4'd0;
					state <= S_LCD_WAIT_ROM_UPDATE;
				end
				// Load the PS2 code to shift registers
					data_reg[15] <= data_reg[14];
					data_reg[14] <= data_reg[13];
					data_reg[13] <= data_reg[12];
					data_reg[12] <= data_reg[11];
					data_reg[11] <= data_reg[10];
					data_reg[10] <= data_reg[9];
					data_reg[9]  <= data_reg[8];
					data_reg[8]  <= data_reg[7];
					data_reg[7]  <= data_reg[6];
					data_reg[6]  <= data_reg[5];
					data_reg[5]  <= data_reg[4];
					data_reg[4]  <= data_reg[3];
					data_reg[3]  <= data_reg[2];
					data_reg[2]  <= data_reg[1];
					data_reg[1]  <= data_reg[0];
					data_reg[0]  <= PS2_code;
					
					//upper/lower case handling needs to be buffered as well for second line case
					PS2_upper_lower_reg[15] <= PS2_upper_lower_reg[14];
					PS2_upper_lower_reg[14] <= PS2_upper_lower_reg[13];
					PS2_upper_lower_reg[13] <= PS2_upper_lower_reg[12];
					PS2_upper_lower_reg[12] <= PS2_upper_lower_reg[11];
					PS2_upper_lower_reg[11] <= PS2_upper_lower_reg[10];
					PS2_upper_lower_reg[10] <= PS2_upper_lower_reg[9];
					PS2_upper_lower_reg[9] <= PS2_upper_lower_reg[8];
					PS2_upper_lower_reg[8] <= PS2_upper_lower_reg[7];
					PS2_upper_lower_reg[7] <= PS2_upper_lower_reg[6];
					PS2_upper_lower_reg[6] <= PS2_upper_lower_reg[5];
					PS2_upper_lower_reg[5] <= PS2_upper_lower_reg[4];
					PS2_upper_lower_reg[4] <= PS2_upper_lower_reg[3];
					PS2_upper_lower_reg[3] <= PS2_upper_lower_reg[2];
					PS2_upper_lower_reg[2] <= PS2_upper_lower_reg[1];
					PS2_upper_lower_reg[1] <= PS2_upper_lower_reg[0];
					PS2_upper_lower_reg[0] <= PS2_upper_lower;
					
					data_compare[15] <= data_compare[14];
					data_compare[14] <= data_compare[13];
					data_compare[13] <= data_compare[12];
					data_compare[12] <= data_compare[11];
					data_compare[11] <= data_compare[10];
					data_compare[10] <= data_compare[9];
					data_compare[9]  <= data_compare[8];
					data_compare[8]  <= data_compare[7];
					data_compare[7]  <= data_compare[6];
					data_compare[6]  <= data_compare[5];
					data_compare[5]  <= data_compare[4];
					data_compare[4]  <= data_compare[3];
					data_compare[3]  <= data_compare[2];
					data_compare[2]  <= data_compare[1];
					data_compare[1]  <= data_compare[0];
					data_compare[0]  <= PS2_code;
			end
		end
		
		S_LCD_WAIT_ROM_UPDATE: begin
			// One clock cycle to wait for ROM to update its output
			state <= S_LCD_ISSUE_INSTRUCTION;
		end
		S_LCD_ISSUE_INSTRUCTION: begin
			// Load translated LCD code to LCD instruction from the ROM
			LCD_instruction <= {1'b1, LCD_code};
			LCD_start <= 1'b1;
			if (LCD_line == 1'b1) begin state <=S_LCD_FINISH_INSTRUCTION_SINGLE; end
			else begin state <=S_LCD_FINISH_INSTRUCTION_SIXTEEN;  end
		end
		S_LCD_FINISH_INSTRUCTION_SINGLE: begin
		if (LCD_start == 1'b1) begin
				LCD_start <= 1'b0;
			end else begin	
				if (LCD_done == 1'b1) begin			
					if (LCD_position < 4'd15) begin
						LCD_position <= LCD_position + 4'h1;
						state <= S_IDLE_SINGLE;
					end else begin
						// Need to change to line 2 for LCD
						LCD_position <= 4'h0;
						state <= S_LCD_ISSUE_CHANGE_LINE;
					end
				end
			end
		end
		
		S_LCD_FINISH_INSTRUCTION_SIXTEEN: begin
			if (LCD_start == 1'b1) begin
				LCD_start <= 1'b0;
			end else begin	
				if (LCD_done == 1'b1) begin			
					if (LCD_position < 4'd15) begin
						LCD_position <= LCD_position + 4'h1;
						if (data_counter < 4'd15) begin
							data_counter <= data_counter + 4'd1;

							state <= S_LCD_WAIT_ROM_UPDATE;
						end else begin
							data_counter <= 4'd0;						
							state <= S_IDLE_SIXTEEN;
						end
					end else begin
						// Need to change to line 2 for LCD
						LCD_position <= 4'h0;
						state <= S_LCD_ISSUE_CHANGE_LINE;
					end
					// Clearing buffer registers
					data_reg[15] <= data_reg[14];
					data_reg[14] <= data_reg[13];
					data_reg[13] <= data_reg[12];
					data_reg[12] <= data_reg[11];
					data_reg[11] <= data_reg[10];
					data_reg[10] <= data_reg[9];
					data_reg[9]  <= data_reg[8];
					data_reg[8]  <= data_reg[7];
					data_reg[7]  <= data_reg[6];
					data_reg[6]  <= data_reg[5];
					data_reg[5]  <= data_reg[4];
					data_reg[4]  <= data_reg[3];
					data_reg[3]  <= data_reg[2];
					data_reg[2]  <= data_reg[1];
					data_reg[1]  <= data_reg[0];
					data_reg[0]  <= 8'h00;		
		
					PS2_upper_lower_reg[15] <= PS2_upper_lower_reg[14];
					PS2_upper_lower_reg[14] <= PS2_upper_lower_reg[13];
					PS2_upper_lower_reg[13] <= PS2_upper_lower_reg[12];
					PS2_upper_lower_reg[12] <= PS2_upper_lower_reg[11];
					PS2_upper_lower_reg[11] <= PS2_upper_lower_reg[10];
					PS2_upper_lower_reg[10] <= PS2_upper_lower_reg[9];
					PS2_upper_lower_reg[9]  <= PS2_upper_lower_reg[8];
					PS2_upper_lower_reg[8]  <= PS2_upper_lower_reg[7];
					PS2_upper_lower_reg[7]  <= PS2_upper_lower_reg[6];
					PS2_upper_lower_reg[6]  <= PS2_upper_lower_reg[5];
					PS2_upper_lower_reg[5]  <= PS2_upper_lower_reg[4];
					PS2_upper_lower_reg[4]  <= PS2_upper_lower_reg[3];
					PS2_upper_lower_reg[3]  <= PS2_upper_lower_reg[2];
					PS2_upper_lower_reg[2]  <= PS2_upper_lower_reg[1];
					PS2_upper_lower_reg[1]  <= PS2_upper_lower_reg[0];
					PS2_upper_lower_reg[0]  <= 1'b0;
				end
			end
		end
		
		S_LCD_ISSUE_CHANGE_LINE: begin
			// Change line
			LCD_instruction <= {2'b01, LCD_line, 6'h00};
			LCD_line <= ~LCD_line;
			LCD_Line_detect <= LCD_line;
			LCD_start <= 1'b1;
			state <= S_LCD_FINISH_CHANGE_LINE;
		end
		
		S_LCD_FINISH_CHANGE_LINE: begin
			if (LCD_start == 1'b1) begin
				LCD_start <= 1'b0;
			end else begin	
				if (LCD_done == 1'b1) begin	
				data_counter<=0;
					if (LCD_line == 1'b1) begin
						state <= S_LCD_RESET;
					end else begin 
						state <= S_IDLE_SIXTEEN;
						
					end
				end
			end
		end
		// Adding another reset state to help reset LCD back to first line and perform erase operation
		S_LCD_RESET : begin
			LCD_erased <= 1'b1;
			LCD_line <= 1'b1;
			LCD_init_index <= 3'd0;
			LCD_Line_detect <= 1'b1;
			PS2_code_ready_buf <= 1'b0;
			LCD_position <= 4'h0;
			data_counter <= 4'd0;
			PS2_upper_lower_reg[15] <= 1'b0;
			PS2_upper_lower_reg[14] <= 1'b0;
			PS2_upper_lower_reg[13] <= 1'b0;
			PS2_upper_lower_reg[12] <= 1'b0;
			PS2_upper_lower_reg[11] <= 1'b0;
			PS2_upper_lower_reg[10] <= 1'b0;
			PS2_upper_lower_reg[9] <= 1'b0;
			PS2_upper_lower_reg[8] <= 1'b0;
			PS2_upper_lower_reg[7] <= 1'b0;
			PS2_upper_lower_reg[6] <= 1'b0;
			PS2_upper_lower_reg[5] <= 1'b0;
			PS2_upper_lower_reg[4] <= 1'b0;
			PS2_upper_lower_reg[3] <= 1'b0;
			PS2_upper_lower_reg[2] <= 1'b0;
			PS2_upper_lower_reg[1] <= 1'b0;
			data_reg[15] <= 8'h00;
			data_reg[14] <= 8'h00;
			data_reg[13] <= 8'h00;
			data_reg[12] <= 8'h00;
			data_reg[11] <= 8'h00;
			data_reg[10] <= 8'h00;
			data_reg[9]  <= 8'h00;
			data_reg[8]  <= 8'h00;
			data_reg[7]  <= 8'h00;
			data_reg[6]  <= 8'h00;
			data_reg[5]  <= 8'h00;
			data_reg[4]  <= 8'h00;
			data_reg[3]  <= 8'h00;
			data_reg[2]  <= 8'h00;
			data_reg[1]  <= 8'h00;
			data_reg[0]  <= 8'h00;
			
			// Erase operation here
			if (LED_state == 2'd0)begin
			  LCD_instruction <= 9'h001;
			  LCD_start <= 1'b1;
			  state <= S_IDLE_SINGLE;
			end
		
		end 
		default: state <= S_LCD_INIT;
		endcase
	end
end


// Handling letter detection here
integer i;

always_comb begin
	first_char=1'b0;
	last_char = 1'b0;
	for (i=0;i<16;i=i+1)begin
	 if (flag == 1'b1) begin
		if (data_compare[15] == data_store[i])begin
			first_char = 1'b1;
		end 
		if (PS2_code == data_store[i])begin
			last_char = 1'b1;
		end 
	 end else begin
	      first_char=1'b0;
			last_char = 1'b0;
	 end
	end
end

// Initialization sequence for LCD
///////////////////
// DO NOT CHANGE //
///////////////////
always_comb begin
	case(LCD_init_index)
	0:       LCD_init_sequence	=	9'h038; // Set display to be 8 bit and 2 lines
	1:       LCD_init_sequence	=	9'h00C; // Set display
	2:       LCD_init_sequence	=	9'h001; // Clear display
	3:       LCD_init_sequence	=	9'h006; // Enter entry mode
	default: LCD_init_sequence	=	9'h080; // Set starting position to 0
	endcase
end

assign LED_GREEN_O = (flag == 1'b1) ? 8'h1FF : 8'h000;
assign LED_RED_O = {resetn, 14'd0, LCD_Line_detect, LCD_line, flag};

convert_hex_to_seven_segment unit3 (
	.hex_value(4'd13), 
	.converted_value(value_7_segment[3])
);

convert_hex_to_seven_segment unit2 (
	.hex_value(4'd13), 
	.converted_value(value_7_segment[2])
);

convert_hex_to_seven_segment unit1 (
	.hex_value(push_count_0), 
	.converted_value(value_7_segment[1])
);

convert_hex_to_seven_segment unit0 (
	.hex_value(counter), 
	.converted_value(value_7_segment[0])
);

convert_hex_to_seven_segment unit4 (
	.hex_value(data_counter), 
	.converted_value(value_7_segment[4])
);

assign	SEVEN_SEGMENT_N_O[0] = value_7_segment[0],
		SEVEN_SEGMENT_N_O[1] = value_7_segment[1],
		SEVEN_SEGMENT_N_O[2] = value_7_segment[4],
		SEVEN_SEGMENT_N_O[3] = 7'h7f,
		SEVEN_SEGMENT_N_O[4] = 7'h7f,
		SEVEN_SEGMENT_N_O[5] = 7'h7f,
		SEVEN_SEGMENT_N_O[6] = (first_char) ? value_7_segment[2] : 7'hff,
		SEVEN_SEGMENT_N_O[7] = (last_char) ? value_7_segment[3] : 7'hff;


///////////////////////////////////////////////////////////////
//		            ANOTHER FSM FOR PUSH BUTTON              //
///////////////////////////////////////////////////////////////

enum logic [3:0]{
    S_IDLE,
	S_ONCE,
	S_TWO,
	S_THREE,
	S_DISPLAY
}BUTTON_state;

logic button_erase;
logic [9:0] debounce_shift_reg [3:0];
logic [3:0] push_button_status, push_button_status_buf;
logic [3:0] PB_detected;

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

// push_button_status will be all bits in debounce_shift_reg[] ORed together
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

assign PB_detected = push_button_status & ~push_button_status_buf;

logic [1:0] push_count_0,push_count_1,push_count_2,push_count_3;

always_ff @ (posedge CLOCK_50_I or negedge resetn) begin
	if (resetn == 1'b0) begin
		BUTTON_state <= S_IDLE;
		push_count_0 <= 2'd0;
		push_count_1 <= 2'd0;
		push_count_2 <= 2'd0;
		push_count_3 <= 2'd0;
		button_erase <= 1'b0;
	end else begin
		case (BUTTON_state)
		S_IDLE : begin
		push_count_0 <= 2'd0;
		push_count_1 <= 2'd0;
		push_count_2 <= 2'd0;
		push_count_3 <= 2'd0;
		button_erase<=1'b0;
			if (PB_detected[0] == 1'b1) begin
				push_count_0 <= push_count_0 + 2'd1;
				BUTTON_state <= S_ONCE;
			end
			else if (PB_detected[1] == 1'b1) begin
				push_count_1 <= push_count_1 + 2'd1;
				BUTTON_state <= S_ONCE;
			end
			else if (PB_detected[2] == 1'b1) begin
				push_count_2 <= push_count_2 + 2'd1;
				BUTTON_state <= S_ONCE;
			end
			else if (PB_detected[3] == 1'b1) begin
				push_count_3 <= push_count_3 + 2'd1;
				BUTTON_state <= S_ONCE;
			end
		end
		
		
		S_ONCE : begin
			if (PB_detected[0] == 1'b1) begin
				if (push_count_0==2'd1)begin
					push_count_0 <= push_count_0 + 2'd1;
					BUTTON_state <= S_TWO;
				end else BUTTON_state <= S_IDLE;	
			end
			
			else if (PB_detected[1] == 1'b1) begin
				if (push_count_1==2'd1)begin
					push_count_1 <= push_count_1 + 2'd1;
					BUTTON_state <= S_TWO;
				end else BUTTON_state <= S_IDLE;	
			end
			
			else if (PB_detected[2] == 1'b1) begin
				if (push_count_2==2'd1)begin
					push_count_2 <= push_count_2 + 2'd1;
					BUTTON_state <= S_TWO;
				end else BUTTON_state <= S_IDLE;	
			end
			
			else if (PB_detected[3] == 1'b1) begin
				if (push_count_3==2'd1)begin
					push_count_3 <= push_count_3 + 2'd1;
					BUTTON_state <= S_TWO;
				end else BUTTON_state <= S_IDLE;	
			end	
		end
		
		S_TWO : begin
			if (PB_detected[0] == 1'b1) begin
				if (push_count_0==2'd2)begin
					push_count_0 <= push_count_0 + 2'd1;
					BUTTON_state <= S_THREE;
				end else BUTTON_state <= S_IDLE;	
			end
			
			else if (PB_detected[1] == 1'b1) begin
				if (push_count_1==2'd2)begin
					push_count_1 <= push_count_1 + 2'd1;
					BUTTON_state <= S_THREE;
				end else BUTTON_state <= S_IDLE;	
			end
			
			else if (PB_detected[2] == 1'b1) begin
				if (push_count_2==2'd2)begin
					push_count_2 <= push_count_2 + 2'd1;
					BUTTON_state <= S_THREE;
				end else BUTTON_state <= S_IDLE;	
			end
			
			else if (PB_detected[3] == 1'b1) begin
				if (push_count_3==2'd2)begin
					push_count_3 <= push_count_3 + 2'd1;
					BUTTON_state <= S_THREE;
				end else BUTTON_state <= S_IDLE;	
			end
		end
		
		
		S_THREE : begin
			if (PB_detected[0] == 1'b1) begin
				if (push_count_0==2'd3)begin
					push_count_0 <= push_count_0 + 2'd1;
					BUTTON_state <= S_DISPLAY;
				end else BUTTON_state <= S_IDLE;	
			end
			
			else if (PB_detected[1] == 1'b1) begin
				if (push_count_1==2'd3)begin
					push_count_1 <= push_count_1 + 2'd1;
					BUTTON_state <= S_DISPLAY;
				end else BUTTON_state <= S_IDLE;	
			end
			
			else if (PB_detected[2] == 1'b1) begin
				if (push_count_2==2'd3)begin
					push_count_2 <= push_count_2 + 2'd1;
					BUTTON_state <= S_DISPLAY;
				end else BUTTON_state <= S_IDLE;	
			end
			
			else if (PB_detected[3] == 1'b1) begin
				if (push_count_3==2'd3)begin
					push_count_3 <= push_count_3 + 2'd1;
					BUTTON_state <= S_DISPLAY;
				end else BUTTON_state <= S_IDLE;	
			end
		end
		
		S_DISPLAY : begin
			button_erase <= 1'b1;
			BUTTON_state <= S_IDLE;
		end
		default: BUTTON_state <= S_IDLE;
		endcase
	end
end

		
endmodule
