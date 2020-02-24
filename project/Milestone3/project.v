`timescale 1ns/100ps

`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

`include "define_state.h"

// This is the top module
// It connects the UART, SRAM and VGA together.
// It gives access to the SRAM for UART and VGA
module project (
		/////// board clocks                      ////////////
		input logic CLOCK_50_I,                   // 50 MHz clock

		/////// pushbuttons/switches              ////////////
		input logic[3:0] PUSH_BUTTON_I,           // pushbuttons
		input logic[17:0] SWITCH_I,               // toggle switches

		/////// 7 segment displays/LEDs           ////////////
		output logic[6:0] SEVEN_SEGMENT_N_O[7:0], // 8 seven segment displays
		output logic[8:0] LED_GREEN_O,            // 9 green LEDs

		/////// VGA interface                     ////////////
		output logic VGA_CLOCK_O,                 // VGA clock
		output logic VGA_HSYNC_O,                 // VGA H_SYNC
		output logic VGA_VSYNC_O,                 // VGA V_SYNC
		output logic VGA_BLANK_O,                 // VGA BLANK
		output logic VGA_SYNC_O,                  // VGA SYNC
		output logic[7:0] VGA_RED_O,              // VGA red
		output logic[7:0] VGA_GREEN_O,            // VGA green
		output logic[7:0] VGA_BLUE_O,             // VGA blue
		
		/////// SRAM Interface                    ////////////
		inout wire[15:0] SRAM_DATA_IO,            // SRAM data bus 16 bits
		output logic[19:0] SRAM_ADDRESS_O,        // SRAM address bus 18 bits
		output logic SRAM_UB_N_O,                 // SRAM high-byte data mask 
		output logic SRAM_LB_N_O,                 // SRAM low-byte data mask 
		output logic SRAM_WE_N_O,                 // SRAM write enable
		output logic SRAM_CE_N_O,                 // SRAM chip enable
		output logic SRAM_OE_N_O,                 // SRAM output logic enable
		
		/////// UART                              ////////////
		input logic UART_RX_I,                    // UART receive signal
		output logic UART_TX_O                    // UART transmit signal
		
		
);
	
logic resetn;

top_state_type top_state;

// For Push button
logic [3:0] PB_pushed;

// For VGA SRAM interface
logic VGA_enable;
logic [17:0] VGA_base_address;
logic [17:0] VGA_SRAM_address;

// For SRAM
logic [17:0] SRAM_address;
logic [15:0] SRAM_write_data;
logic SRAM_we_n;
logic [15:0] SRAM_read_data;
logic SRAM_ready;

// For UART SRAM interface
logic UART_rx_enable;
logic UART_rx_initialize;
logic [17:0] UART_SRAM_address;
logic [15:0] UART_SRAM_write_data;
logic UART_SRAM_we_n;
logic [25:0] UART_timer;

logic [6:0] value_7_segment [7:0];

// For error detection in UART
logic [3:0] Frame_error;

// For disabling UART transmit
assign UART_TX_O = 1'b1;

assign resetn = ~SWITCH_I[17] && SRAM_ready;

// Push Button unit
PB_Controller PB_unit (
	.Clock_50(CLOCK_50_I),
	.Resetn(resetn),
	.PB_signal(PUSH_BUTTON_I),	
	.PB_pushed(PB_pushed)
);

// VGA SRAM interface
logic [9:0] VGA_RED_O_long, VGA_GREEN_O_long, VGA_BLUE_O_long;

VGA_SRAM_interface VGA_unit (
	.Clock(CLOCK_50_I),
	.Resetn(resetn),
	.VGA_enable(VGA_enable),
   
	// For accessing SRAM
	.SRAM_base_address(VGA_base_address),///INPUT
	.SRAM_address(VGA_SRAM_address),////OUTPUT
	.SRAM_read_data(SRAM_read_data),///INPUT
   
	// To VGA pins
	.VGA_CLOCK_O(VGA_CLOCK_O),//ALL OUTPUT
	.VGA_HSYNC_O(VGA_HSYNC_O),
	.VGA_VSYNC_O(VGA_VSYNC_O),
	.VGA_BLANK_O(VGA_BLANK_O),
	.VGA_SYNC_O(VGA_SYNC_O),
	.VGA_RED_O(VGA_RED_O_long),
	.VGA_GREEN_O(VGA_GREEN_O_long),
	.VGA_BLUE_O(VGA_BLUE_O_long)///////
);

assign VGA_RED_O = VGA_RED_O_long[9:2];
assign VGA_GREEN_O = VGA_GREEN_O_long[9:2];
assign VGA_BLUE_O = VGA_BLUE_O_long[9:2];

// UART SRAM interface
UART_SRAM_interface UART_unit(
	.Clock(CLOCK_50_I),
	.Resetn(resetn), 
   
	.UART_RX_I(UART_RX_I),
	.Initialize(UART_rx_initialize),
	.Enable(UART_rx_enable),
   
	// For accessing SRAM
	.SRAM_address(UART_SRAM_address),
	.SRAM_write_data(UART_SRAM_write_data),
	.SRAM_we_n(UART_SRAM_we_n),
	.Frame_error(Frame_error)
);

// SRAM unit
SRAM_Controller SRAM_unit (
	.Clock_50(CLOCK_50_I),
	.Resetn(~SWITCH_I[17]),
	.SRAM_address(SRAM_address),
	.SRAM_write_data(SRAM_write_data),
	.SRAM_we_n(SRAM_we_n),
	.SRAM_read_data(SRAM_read_data),		
	.SRAM_ready(SRAM_ready),
		
	// To the SRAM pins
	.SRAM_DATA_IO(SRAM_DATA_IO),
	.SRAM_ADDRESS_O(SRAM_ADDRESS_O[17:0]),
	.SRAM_UB_N_O(SRAM_UB_N_O),
	.SRAM_LB_N_O(SRAM_LB_N_O),
	.SRAM_WE_N_O(SRAM_WE_N_O),
	.SRAM_CE_N_O(SRAM_CE_N_O),
	.SRAM_OE_N_O(SRAM_OE_N_O)
);
logic M1_enable, M1_done,M1_we_n;
logic [15:0] M1_write_data;
logic [17:0] M1_address;

M1_interface M1_unit(
	.Clock(CLOCK_50_I),
	.resetn(resetn),
	.start(M1_enable),
	.SRAM_read_data(SRAM_read_data),
	.SRAM_write_data(M1_write_data),
	.done(M1_done),
	.SRAM_we_n(M1_we_n),
	.SRAM_address(M1_address)
);

logic M2_enable, M2_done,M2_we_n;
logic [15:0] M2_write_data;
logic [17:0] M2_address;

M2_interface M2_unit(
	.Clock(CLOCK_50_I),
	.resetn(resetn),
	.start(M2_enable),
	.SRAM_read_data(SRAM_read_data),
	.SRAM_write_data(M2_write_data),
	.SRAM_we_n(M2_we_n),
	.M2_done(M2_done),
	.SRAM_address(M2_address)

);

logic M3_enable, M3_done,M3_we_n;
logic [15:0] M3_write_data;
logic [17:0] M3_address;

M3_interface M3_unit(
	.Clock(CLOCK_50_I),
	.resetn(resetn),
	.M3_start(M3_enable),
	.SRAM_read_data(SRAM_read_data),
	.SRAM_write_data(M3_write_data),
	.SRAM_we_n(M3_we_n),
	.M3_done(M3_done),
	.SRAM_address(M3_address)
);

assign SRAM_ADDRESS_O[19:18] = 2'b00;
///TOP FSM
always @(posedge CLOCK_50_I or negedge resetn) begin
	if (~resetn) begin
		top_state <= S_IDLE;
		UART_rx_initialize <= 1'b0;
		UART_rx_enable <= 1'b0;
		UART_timer <= 26'd0;
		M3_enable <= 1'b0;
		M2_enable <= 1'b0;
		M1_enable <= 1'b0;
		VGA_enable <= 1'b1;
		
	end else begin
		UART_rx_initialize <= 1'b0; 
		UART_rx_enable <= 1'b0; 
		// Timer for timeout on UART
		// This counter reset itself every time a new data is received on UART
		if (UART_rx_initialize | ~UART_SRAM_we_n) UART_timer <= 26'd0;
		else UART_timer <= UART_timer + 26'd1;
		case (top_state)
		S_IDLE: begin
			M3_enable <= 1'b0;
			M2_enable <= 1'b0;
			M1_enable <= 1'b0;
			VGA_enable <= 1'b1;
/////////////////////////////for simulation only////////////////////			
			`ifdef SIMULATION 
			if (UART_timer == 26'd49999990)begin
				M3_enable <= 1'b1;
				top_state <= S_M3;
				UART_rx_initialize <= 1'b1;
			end
			`endif	
////////////////////////////////////////////////////////////////////
			if (~UART_RX_I | PB_pushed[0]) begin
				// UART detected a signal, or PB0 is pressed
				UART_rx_initialize <= 1'b1;
				VGA_enable <= 1'b0;				
				top_state <= S_ENABLE_UART_RX;
			end
		end
		
		S_ENABLE_UART_RX: begin
			// Enable the UART receiver
			UART_rx_enable <= 1'b1;
			top_state <= S_WAIT_UART_RX;
		end
		
		S_WAIT_UART_RX: begin
			if ((UART_timer == 26'd49999999) && (UART_SRAM_address != 18'h00000)) begin
				// Timeout for 1 sec on UART for detecting if file transmission is finished
				UART_rx_initialize <= 1'b1;
				M3_enable <= 1'b1;
				top_state <= S_M3;
			end
		end
		
		S_M3: begin
			if (M3_done) begin
				top_state <= S_M2;
				M3_enable <= 1'b0;
				M2_enable <= 1'b1;
			end
		end
		
		S_M2: begin
			if (M2_done) begin
				top_state <= S_M1;
				M2_enable <= 1'b0;
				M1_enable <= 1'b1;
			end
		end
		S_M1: begin
			if (M1_done)begin
				top_state <= S_IDLE;
				M1_enable <= 1'b0;
			end
		end
		default: top_state <= S_IDLE;
		endcase
	end
end

assign VGA_base_address = 18'h23E00;

// Give access to SRAM for UART and VGA at appropriate time
always_comb begin
	SRAM_address = VGA_SRAM_address;
	SRAM_we_n = 1'b1;
	SRAM_write_data = UART_SRAM_write_data;
	if ((top_state == S_ENABLE_UART_RX) | (top_state == S_WAIT_UART_RX)) begin
		SRAM_address = UART_SRAM_address;
		SRAM_we_n = UART_SRAM_we_n;
		SRAM_write_data = UART_SRAM_write_data;
	end
	if (top_state == S_M3) begin
		SRAM_address = M3_address;
		SRAM_we_n = M3_we_n;
		SRAM_write_data = M3_write_data;
	end 
	if (top_state == S_M2) begin
		SRAM_address = M2_address;
		SRAM_we_n = M2_we_n;
		SRAM_write_data = M2_write_data;
	end 
	if (top_state == S_M1) begin
		SRAM_address = M1_address;
		SRAM_we_n = M1_we_n;
		SRAM_write_data = M1_write_data;
	end
end
		
logic [17:0] M1_write_counter;	
logic [17:0] M2_write_counter;
logic [17:0] display_write_counter;
logic [31:0] M2_state_counter;

assign display_write_counter = SWITCH_I[1] ? M2_write_counter : M1_write_counter;

always @(posedge CLOCK_50_I or negedge resetn) begin
	if (~resetn) begin
		M1_write_counter <= 18'd0;
		M2_write_counter <= 18'd0;
		M2_state_counter <= 32'd0;
	end else begin
		if (top_state == S_M3) begin
			if (M3_address != SRAM_address) begin
				M2_write_counter <= M2_write_counter + 18'd1;
			end
		end		
	end
end
		
// 7 segment displays
convert_hex_to_seven_segment unit7 (
	.hex_value(SRAM_address[15:12]), 
	.converted_value(value_7_segment[7])
);

convert_hex_to_seven_segment unit6 (
	.hex_value(SRAM_address[11:8]), 
	.converted_value(value_7_segment[6])
);

convert_hex_to_seven_segment unit5 (
	.hex_value(SRAM_address[7:4]), 
	.converted_value(value_7_segment[5])
);

convert_hex_to_seven_segment unit4 (
	.hex_value(SRAM_address[17:16]), 
	.converted_value(value_7_segment[4])
);

convert_hex_to_seven_segment unit3 (
	.hex_value({2'b00, SRAM_address[15:12]}), 
	.converted_value(value_7_segment[3])
);

convert_hex_to_seven_segment unit2 (
	.hex_value(SRAM_address[11:8]), 
	.converted_value(value_7_segment[2])
);

convert_hex_to_seven_segment unit1 (
	.hex_value(SRAM_address[7:4]), 
	.converted_value(value_7_segment[1])
);

convert_hex_to_seven_segment unit0 (
	.hex_value(SRAM_address[3:0]), 
	.converted_value(value_7_segment[0])
);

assign   
   SEVEN_SEGMENT_N_O[0] = value_7_segment[0],
   SEVEN_SEGMENT_N_O[1] = value_7_segment[1],
   SEVEN_SEGMENT_N_O[2] = value_7_segment[2],
   SEVEN_SEGMENT_N_O[3] = value_7_segment[3],
   SEVEN_SEGMENT_N_O[4] = value_7_segment[4],
   SEVEN_SEGMENT_N_O[5] = value_7_segment[5],
   SEVEN_SEGMENT_N_O[6] = value_7_segment[6],
   SEVEN_SEGMENT_N_O[7] = value_7_segment[7];

//assign LED_GREEN_O = {resetn, VGA_enable, ~SRAM_we_n, M1_enable, M2_enable};
assign LED_GREEN_O = {M3_enable,~SRAM_we_n,top_state};
endmodule
