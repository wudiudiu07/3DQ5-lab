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
// It takes a valid LCD instruction when a start signal is detected
// Then it will issue the instruction to the LCD according to the LCD protocol
// When it's done, the done flag will be raised
module LCD_controller (
	input logic Clock_50,
	input logic Resetn,
	input logic LCD_start,
	input logic [8:0] LCD_instruction,

	output logic LCD_done,
	
	// LCD side
	output logic LCD_power,
	output logic LCD_back_light,
	output logic LCD_read_write,
	output logic LCD_enable,
	output logic LCD_command_data_select,
	output [7:0] LCD_data_io
);

parameter	CLK_DIVIDE	=	16;

enum logic [2:0] {
	S_LCD_IDLE,
	S_LCD_START_DELAY,
	S_LCD_ENABLE,
	S_LCD_DELAY_ENABLE,
	S_LCD_NOT_ENABLE,
	S_LCD_DELAY,
	S_LCD_DONE
} LCD_state;

logic Start_buf;
logic [4:0] LCD_enable_delay;
logic [17:0] LCD_delay;

// Turn on LCD
assign LCD_power               = 1'b1;
assign LCD_back_light          = 1'b1;

//	Only write to LCD, bypass iRS to LCD_RS
assign LCD_data_io             = LCD_instruction[7:0]; 
assign LCD_read_write          = 1'b0;
assign LCD_command_data_select = LCD_instruction[8];

always@(posedge Clock_50 or negedge Resetn)
begin
	if(!Resetn)	begin
		LCD_done <= 1'b0;
		LCD_enable <= 1'b0;
		Start_buf <= 1'b0;
		LCD_state <= S_LCD_IDLE;
		LCD_enable_delay <= 5'd0;
		LCD_delay <= 18'd0;
	end	else begin
		Start_buf <= LCD_start;
		
		case (LCD_state)
		S_LCD_IDLE: begin
			// Detect positive edge of start signal
			if(LCD_start && ~Start_buf) begin
				LCD_state <= S_LCD_START_DELAY;
				LCD_done <= 1'b0;
				LCD_enable_delay <= 5'd0;
			end
		end
		S_LCD_START_DELAY: begin
			// Delay one clock cycle before asserting enable signal
			LCD_state <= S_LCD_ENABLE;
		end
		S_LCD_ENABLE: begin
			// Assert enable signal
			LCD_enable <= 1'b1;
			LCD_state <= S_LCD_DELAY_ENABLE;
		end
		S_LCD_DELAY_ENABLE: begin
			// Hold enable signal for 16 clock cycles
			if (LCD_enable_delay < CLK_DIVIDE) begin
				LCD_enable_delay <= LCD_enable_delay + 5'd1;
			end else begin
				LCD_state <= S_LCD_NOT_ENABLE;
			end
		end
		S_LCD_NOT_ENABLE: begin
			// Deactivate enable for LCD
			LCD_enable <= 1'b0;
			LCD_state <= S_LCD_DELAY;
		end
		S_LCD_DELAY: begin
			// Delay for about 5 ms
			if (LCD_delay < 18'h3FFFE) begin
				LCD_delay <= LCD_delay + 18'd1;
			end else begin
				LCD_delay <= 18'd0;
				LCD_state <= S_LCD_DONE;
			end
		end
		S_LCD_DONE: begin
			// Finish issuing one LCD instruction
			LCD_done <= 1'b1;
			LCD_state <= S_LCD_IDLE;
		end
		default: LCD_state <= S_LCD_IDLE;
		endcase
	end
end

endmodule
