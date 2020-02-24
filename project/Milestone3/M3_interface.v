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
module M3_interface (
		input logic Clock,
		input logic resetn,
		input logic M3_start,
		input logic [15:0] SRAM_read_data,
		output logic [15:0] SRAM_write_data,
		output logic SRAM_we_n,
		output logic M3_done,
		output logic [17:0] SRAM_address			
);

M3_state_type M3_state;

logic [6:0] base_address;
logic [15:0] q;
logic [31:0] shift_reg; //32 bits register 
logic [4:0] shift_counter,header_counter; // number of bits that has already shifted
logic [4:0] bit_shift_unit,bits_left, remain_bits;
logic [7:0] we_counter,zero_counter,flag; //we_counter: number of data that has written in the DPRAM
									 //zero_counter: zeros need to write

logic [7:0] max_number_per_row,base_we_counter,matrix_row;
logic [5:0] block_col_index,block_row_index,max_col_index;
logic signed [7:0] row_index, col_index,col_index_extended,row_index_extended;
logic [17:0] row_address,col_address,read_address,memory_offset,read_block_offset;
logic [8:0] write_offset;
logic [1:0] memory_sel;
logic [15:0] MULTI_IDCT0, MULTI_IDCT1, MULTI_IDCT2;
logic [15:0] memory_data;
logic [31:0] SHIFT;
integer i;


parameter Y_OFFSET = 18'd76800,
		  U_OFFSET = 18'd38400,
		  V_OFFSET = 18'd57600,
		  uv_block_col = 6'd19,  //UV block is 20 * 30
		  y_block_col = 6'd39,   //Y block is 40 * 30
		  y_read_offset = 9'd320,
		  uv_read_offset = 9'd160,
		  y_read_block_offset = 12'd2560,
		  uv_read_block_offset= 12'd1280,
		  v_seg_offset = 18'd57600;

assign row_address = (block_row_index * read_block_offset) + row_index * write_offset;
assign col_address = (block_col_index << 3) + col_index;
assign row_index = row_index_extended >> 3;
assign col_index = {1'b0, col_index_extended[2:0]};
assign col_index_extended = (matrix_row[0] == 1'b0)?base_address-((we_counter - base_we_counter) * 3'd7): base_address + ((we_counter - base_we_counter) * 3'd7);
assign row_index_extended =(matrix_row[0] == 1'b0)? base_address-((we_counter - base_we_counter) * 3'd7): base_address + ((we_counter - base_we_counter) * 3'd7);

assign write_offset = (memory_sel == 2'd0) ? y_read_offset : uv_read_offset;
assign memory_offset = (memory_sel == 2'd0) ? Y_OFFSET : (memory_sel == 2'd1) ? (Y_OFFSET + (U_OFFSET << 1)) : (Y_OFFSET + (V_OFFSET<<1));
assign max_col_index = (memory_sel == 2'd0) ? y_block_col : uv_block_col;
assign read_block_offset = (memory_sel == 2'd0)? y_read_block_offset : uv_read_block_offset;
 
always_ff @ (posedge Clock or negedge resetn) begin
	if (resetn == 1'b0) begin
		shift_reg <= 32'd0;
		shift_counter <= 5'd0;
		header_counter <= 5'd0;
		read_address <= 18'd0;
		block_row_index <= 6'd0;
		block_col_index <= 6'd0;
		memory_sel <= 2'd0;
		remain_bits <= 5'd0;
		SRAM_we_n <= 1'd1;
		bit_shift_unit <= 5'd0;
		we_counter  <= 8'd0;
		zero_counter<= 8'd0;
		M3_state <= M3_IDLE;
		M3_done <= 1'b0;
		flag <= 8'd0;
		memory_data <= 16'd0;
		bits_left <= 5'd0;
		
	end else begin
		case (M3_state)
		M3_IDLE: begin
			header_counter <= 5'd0;
			shift_reg <= 32'd0;
			shift_counter <= 5'd0;
			header_counter <= 5'd0;
			read_address <= 18'd0;
			block_row_index <= 6'd0;
			block_col_index <= 6'd0;
			memory_sel <= 2'd0;
			remain_bits <= 5'd0;
			bit_shift_unit <= 5'd0;
			we_counter  <= 8'd0;
			zero_counter<= 8'd0;
			M3_done <= 1'b0;
			flag <= 8'd0;
			memory_data <= 16'd0;
			bits_left <= 5'd0;
			M3_state <= M3_IDLE_1;
		end
		M3_IDLE_1: begin
			if(M3_start) begin
				//Read DE AND AD
				if(header_counter == 5'd0) begin
					SRAM_address <= read_address;
					read_address <= read_address + 18'd1;
					header_counter <= header_counter + 5'd1;
				end
				if(header_counter < 5'd2) begin
					header_counter <= header_counter + 5'd1;
				end else begin
					M3_state <= S_HEADER_1;
					SRAM_address <= read_address;
					read_address <= read_address + 18'd1;
					header_counter <= 5'd0;
				end
			end
		end
		S_HEADER_1: begin
			if (SRAM_read_data[15:8] == 16'hDE && header_counter == 5'd0) begin
				header_counter <= header_counter + 5'd1;
			end
			else if (SRAM_read_data[7:0] == 16'hAD && header_counter == 5'd1)begin
				header_counter <= header_counter + 5'd1;
				//Read 0140
				read_address <= read_address + 18'd1;
				SRAM_address <= read_address;
			end
			else if (SRAM_read_data[15:8] == 16'hBE && header_counter == 5'd2) begin
				header_counter <= header_counter + 5'd1;
			end
			else if (SRAM_read_data[7:0] == 16'hEF && header_counter == 5'd3) begin
				//Read 00F0
				header_counter <= 5'd0;
				M3_state <= S_HEADER_2;
				SRAM_address <= read_address;
				read_address <= read_address + 18'd1;
			end			
		end
		S_HEADER_2:begin
			if (SRAM_read_data[15:8] == 16'h01 && header_counter == 5'd0) begin
				header_counter <= header_counter + 5'd1;
			end
			else if (SRAM_read_data[7:0] == 16'h40 && header_counter == 5'd1)begin
				header_counter <= header_counter + 5'd1;
				//Read the first value
				SRAM_address <= read_address;
				read_address <= read_address + 18'd1;
			end
			else if (SRAM_read_data[15:8] == 16'h00 && header_counter == 5'd2)begin
				header_counter <= header_counter + 5'd1;
				SRAM_address <= read_address;
				read_address <= read_address + 18'd1;
			end
			else if (SRAM_read_data[7:0] == 16'hF0 && header_counter == 5'd3) begin
				M3_state <= S_READ_INITIAL_0;
				SRAM_address <= read_address;
				read_address <= read_address + 18'd1;
				header_counter <= 5'd0;
			end			
		end
		S_READ_INITIAL_0: begin
			//Read the second value
			shift_reg <= {SRAM_read_data, 16'd0};
			M3_state <= S_READ_INITIAL_1;
		end
		
		S_READ_INITIAL_1: begin
			if(zero_counter < 8'd1) begin
				shift_reg <= {shift_reg[31:16],SRAM_read_data};
				zero_counter <= zero_counter + 8'd1;
			end else begin
				zero_counter <= 8'd0;
				memory_data <= SRAM_read_data;
				M3_state <= S_READ_2BIT;
			end
		end
		S_READ_2BIT: begin
			//check 2 bits value
			if(shift_reg [31:30] == 2'b00)
				M3_state <= S_00;
			if(shift_reg [31:30] == 2'b01)
				M3_state <= S_01;
			if(shift_reg [31:30] == 2'b10)
				M3_state <= S_10;
			if(shift_reg [31:30] == 2'b11)
				M3_state <= S_11;
		end
		S_00: begin
			if(shift_reg[29:28] == 2'b00) begin // 4 zeros
				if (zero_counter < 8'd4) begin
				    SRAM_address <= memory_offset + row_address + col_address;
					SRAM_write_data <= 16'd0;
					SRAM_we_n <= 1'b0;
					zero_counter <= zero_counter + 8'd1;
					we_counter <= we_counter + 8'd1; //# of value written into the DPRAM
				end else begin
					M3_state <= S_shift_DETECT;
					zero_counter <= 8'd0;
					shift_counter <= shift_counter + 5'd4;
					bit_shift_unit <= 5'd4;
					//shift_reg <= SHIFT;
					//memory_data <= memory_data << bit_shift_unit;
					SRAM_we_n <= 1'b1; 	
				end
			end else begin //write shift_reg[29:28] n zeros
				if (zero_counter < shift_reg[29:28]) begin
				    SRAM_address <= memory_offset + row_address + col_address;					
					SRAM_we_n <= 1'b0;
					SRAM_write_data <= 16'd0;
					zero_counter <= zero_counter + 8'd1;
					we_counter <= we_counter + 8'd1;
				end else begin
					zero_counter <= 8'd0;
					shift_counter <= shift_counter + 5'd4;
					bit_shift_unit <= 5'd4;
					//shift_reg <= SHIFT;
					//memory_data <= memory_data << bit_shift_unit;
					SRAM_we_n <= 1'b1; 	
					M3_state <= S_shift_DETECT;
				end
			end
		end
		S_01: begin
			if(shift_reg[29] == 1'b0) begin //read 4 bits
				M3_state <= S_01_1;
			end else begin 					
				if(zero_counter == 8'd0) begin
					//since we_counter now is 64
					flag <= we_counter;
				end
				//LOOP TO THE END OF THE BLOCK
				if (zero_counter < 8'd64 - flag) begin
					SRAM_address <= memory_offset + row_address + col_address;
					SRAM_write_data <= 16'd0;
					SRAM_we_n <= 1'b0;
					zero_counter <= zero_counter + 8'd1;
					we_counter <= we_counter + 8'd1;
				end else begin
					zero_counter <= 8'd0;
					shift_counter <= shift_counter + 5'd3;
					bit_shift_unit <= 5'd3;
					SRAM_we_n <= 1'b1; 
					flag <= 8'd0;
					M3_state <= S_shift_DETECT;
				end
			end
		end
		//010
		S_01_1: begin
			//shift counter <=shift counter += 7
			//Read 4 bits
			if (shift_reg [28:25] == 4'd0) begin //16 zeros
				if (zero_counter < 8'd16) begin
					SRAM_address <= memory_offset + row_address + col_address;				
					SRAM_write_data <= 16'd0;
					SRAM_we_n <= 1'b0;
					zero_counter <= zero_counter + 8'd1;
					we_counter <= we_counter + 8'd1;
				end	else begin
					zero_counter <= 8'd0;
					shift_counter <= shift_counter + 5'd7;
					bit_shift_unit <= 5'd7;
					SRAM_we_n <= 1'b1; 
					M3_state <= S_shift_DETECT;
				end
			end else begin
				//we_counter <= we_counter += 1; read 4 bits
				if (zero_counter < shift_reg[28:25]) begin
				    SRAM_address <= memory_offset + row_address + col_address;		
					SRAM_write_data <= 16'd0;
					SRAM_we_n <= 1'b0;
					zero_counter <= zero_counter + 8'd1;
					we_counter <= we_counter + 8'd1;
				end else begin
					M3_state <= S_shift_DETECT;
					zero_counter <= 8'd0;
					shift_counter <= shift_counter + 5'd7;
					bit_shift_unit <= 5'd7;
					//shift_reg <= SHIFT;
					//memory_data <= memory_data << bit_shift_unit;
					SRAM_we_n <= 1'b1; 
				end
			end
		end
		S_10: begin
			if(shift_reg[29] == 1'b0) begin 
				M3_state <= S_10_0;
			end else begin
				M3_state <= S_10_1;
			end
		end
		S_10_0: begin
			//write the read signed 9 bits value in 2's complement
			if(zero_counter < 8'd1) begin
				SRAM_address <= memory_offset + row_address + col_address;
				SRAM_write_data <= MULTI_IDCT0;
				SRAM_we_n <= 1'b0;
				zero_counter <= zero_counter + 8'd1;
			end else begin
				zero_counter <= 8'd0;
				SRAM_we_n <= 1'b1;
				shift_counter <= shift_counter + 5'd12; //2+1+9
				bit_shift_unit <= 5'd12;
				//shift_reg <= SHIFT;
				//memory_data <= memory_data << bit_shift_unit;
				we_counter <= we_counter + 8'd1;
				M3_state <= S_shift_DETECT;
			end
		end
		S_10_1: begin
			//Update shift counter by 5 bits
			//write the read signed 5 bits value in 2's complement
			if(zero_counter < 8'd1) begin
				SRAM_address <= memory_offset + row_address + col_address;
				SRAM_write_data <= MULTI_IDCT1;
				SRAM_we_n <= 1'b0;
				zero_counter <= zero_counter + 8'd1;
			end else begin
				zero_counter <= 8'd0;
				shift_counter <= shift_counter + 5'd8; //2+1+5
				bit_shift_unit <= 5'd8;
				//shift_reg <= SHIFT;
				//memory_data <= memory_data << bit_shift_unit;
				we_counter <= we_counter + 8'd1;
				SRAM_we_n <= 1'b1;
				M3_state <= S_shift_DETECT;
			end
		end
		S_11: begin
			if(zero_counter < 8'b1) begin
				SRAM_write_data <= MULTI_IDCT2;
				SRAM_address <= memory_offset + row_address + col_address;
				SRAM_we_n <= 1'b0;
				zero_counter <= zero_counter + 8'd1;
			end else begin
				shift_counter <= shift_counter + 5'd5;
				bit_shift_unit <= 5'd5;	
				//shift_reg <= SHIFT;
				//memory_data <= memory_data << bit_shift_unit;
				zero_counter <= 8'd0;
				SRAM_we_n <= 1'b1;
				we_counter <= we_counter + 8'd1;
				M3_state <= S_shift_DETECT;	
			end
		end
		S_shift_DETECT: begin
			//shift register here
			shift_reg <= SHIFT;
			memory_data <= memory_data << bit_shift_unit;
			if (shift_counter > 5'd16) begin 
				//shift the register and write sram-read data
				SRAM_address <= read_address;
				read_address <= read_address + 18'd1;
				bits_left <= shift_counter - 5'd16;
			end
			M3_state <= S_64_DETECT;
		end	
		S_64_DETECT: begin
			//detect the end of the block
			SRAM_we_n <= 1'b1;
			if (we_counter == 8'd64) begin
				/////////////////update block index//////////////////			
				if(block_col_index == max_col_index) begin
					if (block_row_index == 6'd29) begin
						memory_sel <= memory_sel + 2'd1;
						block_row_index <= 6'd0;
						block_col_index <= 6'd0;
						if (memory_sel == 2'd2)begin
							M3_state <= S_FINISH;
							M3_done <= 1'b1;
						end							
					end else begin
						block_row_index <= block_row_index + 6'd1;
						block_col_index <= 6'd0;	
						if (shift_counter > 5'd16) begin
							M3_state <= S_WAIT; //to read SRAM_READ_data
						end else begin
							M3_state <= S_READ_2BIT;
						end
					end
				end else begin
					block_col_index <= block_col_index + 6'd1;
					if (shift_counter > 5'd16) begin
						M3_state <= S_WAIT; //to read SRAM_READ_data
					end else begin
						M3_state <= S_READ_2BIT;
					end
				end
				we_counter <= 8'd0;
			end else begin
				if (shift_counter > 5'd16) begin
					M3_state <= S_WAIT; //to read SRAM_READ_data
				end else begin
					M3_state <= S_READ_2BIT;
				end
			end
		end
		S_WAIT: begin
			if(zero_counter < 8'd2) begin
				zero_counter <= zero_counter + 8'd1;
				if(zero_counter == 8'd1) begin
					shift_counter <= 5'd0;
					memory_data <= SRAM_read_data;
				end
			end else begin
				if(remain_bits == bits_left) begin
					zero_counter <= 8'd0;
					remain_bits <= 5'd0;
					M3_state <= S_READ_2BIT;
				end else begin
					remain_bits <= remain_bits + 5'd1;
					if(bits_left == 5'd1) begin
						shift_reg[0] <= memory_data[15];
						memory_data <= memory_data << 1;
						shift_counter <= shift_counter + 5'd1;
					end else begin
						for(i=1; i<bits_left; i=i+1) begin
							shift_reg[i] <= shift_reg[i-1];
							shift_reg[0] <= memory_data[15];
							memory_data <= memory_data << 1;
							shift_counter <= shift_counter + 5'd1;
						end
					end
				end
			end
		end
		S_FINISH: begin
			M3_state <= M3_IDLE;
		end
		default: M3_state <= M3_IDLE;
		endcase
	end
end
always_comb begin
	SHIFT = shift_reg;
	if (bit_shift_unit == 5'd3) begin
		SHIFT = {shift_reg[28:0],memory_data[15:13]};
	end else if (bit_shift_unit == 5'd4) begin
		SHIFT = {shift_reg[27:0],memory_data[15:12]};
	end else if (bit_shift_unit == 5'd5) begin
		SHIFT = {shift_reg[26:0],memory_data[15:11]};
	end else if (bit_shift_unit == 5'd7) begin
		SHIFT = {shift_reg[24:0],memory_data[15:9]};
	end else if (bit_shift_unit == 5'd8) begin
		SHIFT = {shift_reg[23:0],memory_data[15:8]};
	end else if (bit_shift_unit == 5'd12) begin
		SHIFT = {shift_reg[19:0],memory_data[15:4]};
	end
end

assign MULTI_IDCT0 =  {{7{shift_reg[28]}},shift_reg[28:20]} * q;
assign MULTI_IDCT1 = {{11{shift_reg[28]}},shift_reg[28:24]} * q;
assign MULTI_IDCT2 = {{13{shift_reg[29]}},shift_reg[29:27]} * q;

always_comb begin
if (we_counter >= 8'd63) begin      //row 14
	base_we_counter = 8'd63;
	max_number_per_row = 4'd1;
	q = 7'd64;
	base_address = 7'd63;
	matrix_row = 4'd14;
end else if (we_counter >= 8'd61) begin//row 13
	base_we_counter = 8'd61;
	max_number_per_row = 4'd2;
	q = 7'd64;
	base_address = 7'd55;
	matrix_row = 4'd13;
end
else if (we_counter >= 8'd58)begin ////row 12
	base_we_counter = 8'd58;
	max_number_per_row = 4'd3;
	q = 7'd64;
	base_address = 7'd61;
	matrix_row = 4'd12;
end
else if (we_counter >= 8'd54)begin /////row 11
	base_we_counter = 8'd54;
	max_number_per_row = 4'd4;
	q = 7'd64;
	base_address = 7'd39;
	matrix_row = 4'd11;
end
else if (we_counter >= 8'd49)begin//row 10
	base_we_counter = 8'd49;
	max_number_per_row = 4'd5;
	q = 7'd64;
	base_address = 7'd59;
	matrix_row = 4'd10;
end
else if (we_counter >= 8'd43)begin//row 9
	base_we_counter = 8'd43;
	max_number_per_row = 4'd6;
	q = 7'd64;
	base_address = 7'd23;
	matrix_row = 4'd9;
end
else if (we_counter >= 8'd36)begin//row 8
	base_we_counter = 8'd36;
	max_number_per_row = 4'd7;
	q = 7'd64;
	base_address = 7'd57;
	matrix_row = 4'd8;
end
else if (we_counter >= 8'd28)begin//row 7
	base_we_counter = 8'd28;
	max_number_per_row = 4'd8;
	q = 7'd32;
	base_address = 7'd7;
	matrix_row = 4'd7;
end
else if (we_counter > 8'd21 || we_counter == 8'd21)begin//row 6
	base_we_counter = 8'd21;
	max_number_per_row = 4'd7;
	q = 7'd32;
	base_address = 7'd48;
	matrix_row = 4'd6;
end
else if (we_counter >= 8'd15)begin//row 5
	base_we_counter = 8'd15;
	max_number_per_row = 4'd6;
	q = 7'd16;
	base_address = 7'd5;
	matrix_row = 4'd5;
end
else if (we_counter >= 8'd10)begin//row 4
	base_we_counter = 8'd10;
	max_number_per_row = 4'd5;
	q = 7'd16;
	base_address = 7'd32;
	matrix_row = 4'd4;
end
else if (we_counter >= 8'd6) begin//row 3
	base_we_counter = 8'd6;
	max_number_per_row = 4'd4;
	q = 7'd8;
	base_address = 7'd3;
	matrix_row = 4'd3;
end
else if (we_counter >= 8'd3)begin//row 2
	base_we_counter = 8'd3;
	max_number_per_row = 4'd3;
	q = 7'd8;
	base_address = 7'd16;
	matrix_row = 4'd2;
end
else if (we_counter >= 8'd1)begin//row 1
	base_we_counter = 8'd1;
	max_number_per_row = 4'd2;
	q = 7'd4;
	base_address = 7'd1;
	matrix_row = 4'd1;
end
else begin
	base_we_counter = 8'd0;//row 0
	max_number_per_row = 4'd1;
	q = 7'd8;
	base_address = 7'd0;
	matrix_row = 4'd0;
end
end

endmodule
