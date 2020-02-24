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

module SRAM_BIST (
	input logic Clock,
	input logic Resetn,
	input logic BIST_start,
	
	output logic [17:0] BIST_address,
	output logic [15:0] BIST_write_data,
	output logic BIST_we_n,
	input logic [15:0] BIST_read_data,
	
	output logic BIST_finish,
	output logic BIST_mismatch
);

enum logic [2:0] {
	S_IDLE,        //0
	S_DELAY_1,     //1
	S_DELAY_2,     //2
	S_WRITE_CYCLE, //3
	S_READ_CYCLE,  //4
	S_DELAY_3,     //5
	S_DELAY_4      //6
} BIST_state;

logic BIST_start_buf;
logic [15:0] BIST_expected_data, BIST_const;
logic BIST_flag;
logic [18:0] BIST_endaddr;
logic [17:0] BIST_addr_init;

// write the 16 least significant bits of the address bus in each memory location
// 
// NOTE: this particular BACKGROUND pattern is specific to this BIST implementation

// Putting all these constant selection outside to make system go faster
assign BIST_write_data[15:0] = BIST_address[15:0];
assign BIST_endaddr = (BIST_flag == 1'b0) ? 18'h3FFFE : 18'h3FFFF;

// Descending order when read
assign BIST_const = (BIST_flag == 1'b0) ? 16'hFFFE : 16'hFFFF;
assign BIST_addr_init = (BIST_flag == 1'b0) ? 18'h3FFFE : 18'h3FFFF; 

// based on the way how this particular BIST engine is implemented,
// the BIST expected data can be computed on-the-fly by
// decrementing the 16 least significant bits of the address 

// this specific BIST engine for this reference implementation works as follows
// write location 0 -> read location 0 -> 
// write location 1 -> read location 1 + compare location 0 ->
// write location 2 -> read location 2 + compare location 1 ->
// ... go through the entire address range

always_ff @ (posedge Clock or negedge Resetn) begin
	if (Resetn == 1'b0) begin
		BIST_state <= S_IDLE;
		BIST_mismatch <= 1'b0;
		BIST_finish <= 1'b0;
		BIST_address <= 18'd0;
		BIST_we_n <= 1'b1;		
		BIST_start_buf <= 1'b0;
		BIST_expected_data <= 16'd0;
		BIST_flag <= 1'b0;
	end else begin
		BIST_start_buf <= BIST_start;
		
		case (BIST_state)
		S_IDLE: begin
			// Even operation starts first
			if (BIST_flag == 1'b0) begin
				if (BIST_start & ~BIST_start_buf) begin
					// start the BIST engine
					BIST_address <= 18'd0;
					BIST_we_n <= 1'b0; 
					BIST_mismatch <= 1'b0;
					BIST_finish <= 1'b0;
					BIST_expected_data <= 16'd0;
					BIST_state <= S_WRITE_CYCLE;
				end else begin
					BIST_address <= 18'd0;
					BIST_we_n <= 1'b1;
					BIST_finish <= 1'b1;
					BIST_expected_data <= 16'd0;
				end
			// Odd operation starts right away after even operation is finished
			end else begin
				BIST_address <= 18'd1;
				BIST_we_n <= 1'b0; 
				BIST_mismatch <= 1'b0;
				BIST_finish <= 1'b0;
				BIST_expected_data <= 16'd1;
				BIST_state <= S_WRITE_CYCLE;
			end
		end
		S_WRITE_CYCLE: begin
			if (BIST_address < BIST_endaddr) begin
				BIST_we_n <= 1'b0;
				BIST_expected_data <= BIST_expected_data + 16'd2;
				BIST_address <= BIST_address + 18'd2;
			end else begin
				BIST_we_n    <= 1'b1;
				BIST_state   <= S_DELAY_1;
				BIST_expected_data <= BIST_const;  // Reinitialize expected data to be either FFFE or FFFF (descending order)
				BIST_address <= BIST_addr_init;    // Reinitialize SRAM memory address back to either 3FFFE or 3FFFF (descending order)
			end
		end
		// a couple of delay states to initiate the first WRITE and first READ
		S_DELAY_1: begin
			BIST_we_n <= 1'b1;            // initiate first READ (NOTE: registers updated NEXT clock cycle)
			BIST_address <= BIST_address - 18'd2;
			BIST_state <= S_DELAY_2;
		end
		S_DELAY_2: begin
			BIST_we_n <= 1'b1;
			BIST_address <= BIST_address - 18'd2;
			BIST_state <= S_READ_CYCLE;
		end

		S_READ_CYCLE: begin
			// complete the READ initiated two clock cycles earlier and perform comparison
			if (BIST_read_data != BIST_expected_data) begin
				BIST_mismatch <= 1'b1;
			end
			if (BIST_address < BIST_endaddr) begin
				// increment address and continue by initiating a new WRITE 
				BIST_expected_data <= BIST_expected_data - 16'd2;
				BIST_address <= BIST_address - 18'd2;
				BIST_we_n <= 1'b1;
			end else begin
				// delay for checking the last address
				BIST_state <= S_DELAY_3;
				BIST_expected_data <= BIST_expected_data - 16'd2;
			end
		end
		S_DELAY_3: begin
			BIST_state <= S_DELAY_4;
			BIST_expected_data <= BIST_expected_data - 16'd2;
			if (BIST_read_data != BIST_expected_data) begin
				BIST_mismatch <= 1'b1;
			end
			BIST_state <= S_IDLE;
			BIST_finish <= (BIST_flag == 1'b0) ? 1'b0 : 1'b1;	
			BIST_flag <= ~BIST_flag;
		end
		// Deleting 1 delay state since now two sessions are used instead of 1
		//S_DELAY_4: begin
		//	// check for data mismatch
		//	if (BIST_read_data != BIST_expected_data) begin
		//		BIST_mismatch <= 1'b1;
		//	end
		//	// finish the whole SRAM
		//	BIST_state <= S_IDLE;
		//	BIST_finish <= (BIST_flag == 1'b0) ? 1'b0 : 1'b1;	
		//	BIST_flag <= ~BIST_flag;
		//end
		default: BIST_state <= S_IDLE;
		endcase
	end
end

endmodule
