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
module M2_interface (
		input logic Clock,
		input logic resetn,
		input logic start,
		input logic [15:0]SRAM_read_data,
		output logic  [15:0] SRAM_write_data,
		output logic SRAM_we_n,
		output logic M2_done,
		output logic [17:0] SRAM_address			
);

M2_state_type M2_state;

logic [6:0] address_0, address_1, address_2, address_3;
logic [31:0] write_data_b [1:0];
logic write_enable_b [1:0];
logic [31:0] read_data_a [1:0];
logic [31:0] read_data_b [1:0];

// Instantiate RAM1
//0:63: T = S' * C
//64:127: S = T*C(TRANSPOSE)
dual_port_RAM1 dual_port_RAM_inst1 (
	.address_a ( address_2 ),
	.address_b ( address_3 ),//write_data!!!
	.clock ( Clock ),
	.data_a ( 32'h00 ),
	.data_b ( write_data_b[1] ),
	.wren_a ( 1'b0 ),
	.wren_b ( write_enable_b[1] ),
	.q_a ( read_data_a[1] ),
	.q_b ( read_data_b[1] )
	);

// Instantiate RAM0
//0~63: S'

dual_port_RAM0 dual_port_RAM_inst0 (
	.address_a ( address_0 ),
	.address_b ( address_1 ),//write_data!!!
	.clock ( Clock ),
	.data_a ( 32'h00 ),
	.data_b ( write_data_b[0] ),
	.wren_a ( 1'b0 ),
	.wren_b ( write_enable_b[0] ),
	.q_a ( read_data_a[0] ),
	.q_b ( read_data_b[0] )
	);

parameter Y_OFFSET = 18'd76800,
		  U_OFFSET = 18'd38400,
		  V_OFFSET = 18'd57600,
		  uv_block_col = 6'd19,  //UV block is 20 * 30
		  uv_block_row = 6'd29,
		  y_block_col = 6'd39,   //Y block is 40 * 30
		  y_block_row = 6'd29,
		  uv_write_offset = 9'd80, //post_IDCT, UV row = half of Y row
		  y_write_offset = 9'd160,
		  y_read_offset = 9'd320,
		  uv_read_offset = 9'd160,
		  u_seg_offset = 18'd38400,
		  y_read_block_offset = 12'd2560,
		  uv_read_block_offset= 12'd1280,
		  v_seg_offset = 18'd57600;

logic [5:0] block_col_index,block_row_index;
logic [17:0] row_address,col_address;
logic [3:0] row_index, col_index;
logic [5:0] max_col_index;
logic signed[31:0]T,Y_0,Y_1;
logic [7:0] Y_out_0,Y_out_1;
logic [1:0] flag_ct,flag_cs;
logic flag_fs,flag_ws;
logic [15:0] Y_prime_reg;
logic signed [31:0] op1;
logic signed [31:0] op0;  
logic signed [31:0] C0,C1;
logic signed [31:0] MULTI0,MULTI1;
logic [8:0] read_offset,write_offset;
logic [17:0] memory_offset,seg_offset,block_row_offset,read_block_offset;
logic [1:0] memory_sel;
logic [5:0] c_index_0, c_index_1;
logic [6:0] address_counter;
logic [9:0] w_offset;

assign row_address = (block_row_index * read_block_offset) + row_index * read_offset;
assign col_address = (block_col_index << 3) + col_index;

assign Y_out_0 = (Y_0[31]) ? 8'd0 : (|Y_0[30:24]) ? 8'd255 : Y_0[23:16];
assign Y_out_1 = (Y_1[31]) ? 8'd0 : (|Y_1[30:24]) ? 8'd255 : Y_1[23:16];

assign read_block_offset = (memory_sel == 2'd0)? y_read_block_offset : uv_read_block_offset;
assign max_col_index = (memory_sel == 2'd0) ? y_block_col : uv_block_col;
assign memory_offset = (memory_sel == 2'd0) ? Y_OFFSET : (memory_sel == 2'd1) ? (Y_OFFSET + (U_OFFSET << 1)) : (Y_OFFSET + (V_OFFSET<<1));
assign seg_offset = (memory_sel == 2'd0) ? 18'd0 : (memory_sel == 2'd1) ?u_seg_offset : v_seg_offset;
assign write_offset = (memory_sel == 2'd0) ? y_write_offset : uv_write_offset;
assign read_offset = (memory_sel == 2'd0) ? y_read_offset : uv_read_offset;
assign block_row_offset = (memory_sel == 2'd0) ? 18'd1280 : 18'd640;

always_ff @ (posedge Clock or negedge resetn) begin
	if (resetn == 1'b0) begin		
		write_enable_b[0] <= 1'b0;
		write_enable_b[1] <= 1'b0;
		write_data_b[0] <= 32'd0;
		write_data_b[1] <= 32'd0;
		M2_state <= M2_IDLE;
		SRAM_address <= Y_OFFSET;
		block_col_index <= 6'd0;
		block_row_index <= 6'd0;
		row_index <= 4'd0;
		col_index <= 4'd0;
		address_0 <= 7'd0;
		address_1 <= 7'd0;
		address_2 <= 7'd0;
		address_3 <= 7'd0;
		address_counter <= 7'd0;
		flag_ct <= 2'b0;
		SRAM_we_n <= 1'b1;
		M2_done <= 1'b0;
		flag_fs <= 1'b0;
		memory_sel <= 2'd0;
		c_index_0 <= 6'd0;
		c_index_1 <= 6'd0;
		flag_ws <= 1'b0;
		Y_0 <= 32'd0;
		Y_1 <= 32'd0;
		T <= 32'd0;
		Y_prime_reg <= 16'd0;
	end else begin
		case (M2_state)
		M2_IDLE: begin
		//M2_done <= 1'b0;
			if (start) begin
				SRAM_address <= memory_offset + row_address + col_address;
				col_index <= col_index + 4'd1; //0 + 1
				M2_state <= M2_IDLE_0;
			end
		end
		M2_IDLE_0: begin
			//76800 out
			SRAM_address <= memory_offset + row_address + col_address;
			col_index <= col_index + 4'd1; //1+1
			M2_state <= M2_IDLE_1;
		end
		
		M2_IDLE_1:begin
			//76801 out
			SRAM_address <= memory_offset + row_address + col_address;
			col_index <= col_index + 4'd1;
			
			address_1 <= 7'd0;	
			M2_state <= LI_Fs_0;	
		end
		LI_Fs_0:begin
			if (col_index == 4'd7) begin 
			    if (row_index == 4'd7) begin //to LeadOut
			    	M2_state <= LI_Fs_1; 
					row_index <= 4'd0; //initial row_index to 0
					col_index <= 4'd0; //initial col_index to 0
					SRAM_address <= memory_offset + row_address + col_address;
					if (flag_fs)begin
						write_data_b[0] <= {Y_prime_reg,SRAM_read_data};
						write_enable_b[0] <= 1'b1;
						flag_fs <= ~flag_fs;
					end else begin
						Y_prime_reg <= SRAM_read_data;
						address_1 <= address_1 + 7'd1;
						write_enable_b[0] <= 1'b0;
						flag_fs <= ~flag_fs;
					end
				 //to another row
			    end else begin 
					SRAM_address <= memory_offset + row_address + col_address;
					if (flag_fs)begin
						write_data_b[0] <= {Y_prime_reg,SRAM_read_data};
						write_enable_b[0] <= 1'b1;
						flag_fs <= ~flag_fs;
					end else begin
						Y_prime_reg <= SRAM_read_data;
						write_enable_b[0] <= 1'b0;
						//write Y into DPRAM0
						address_1 <= address_1 + 7'd1;
						flag_fs <= ~flag_fs;
					end
					//update --> a new row
					row_index <= row_index + 4'd1;
					col_index <= 4'd0;
				end
			end else begin 
				//process the same line
				SRAM_address <= memory_offset + row_address + col_address;
				if (flag_fs)begin
					write_data_b[0] <= {Y_prime_reg,SRAM_read_data};
					write_enable_b[0] <= 1'b1;
					flag_fs <= ~flag_fs;
					
				end else begin
					Y_prime_reg <= SRAM_read_data;
					write_enable_b[0] <= 1'b0;
					flag_fs <= ~flag_fs;
					if (SRAM_address != 18'd76802)begin
						//write Y into DPRAM0 
						//increment address except the first write
						address_1 <= address_1 + 7'd1;
						
					end
				end
				col_index <= col_index + 4'd1;
			end
		end
		/////////LEAD_OUT OF F's///////////////
		LI_Fs_1: begin
			write_data_b[0] <= {Y_prime_reg,SRAM_read_data};
			write_enable_b[0] <= 1'b1;
			M2_state <= LI_Fs_2; 
		end
		LI_Fs_2: begin
			//write Y into DPRAM0
			Y_prime_reg <= SRAM_read_data;
			address_1 <= address_1 + 7'd1;
			write_enable_b[0] <= 1'b0;
			M2_state <= LI_Fs_3; 
		end
		LI_Fs_3: begin
			//write Y2247 into DPRAM0
			write_data_b[0] <= {Y_prime_reg,SRAM_read_data};
			write_enable_b[0] <= 1'b1;
			M2_state <= LI_Ct_0; 
		end
        LI_Ct_0: begin
			//initial address_1,address_0 
			address_1 <= 7'd0;
			address_0 <= address_0 + 7'd1; //to 1

			//stop writing for next state
			write_enable_b[0] <= 1'b0;			

			M2_state <= LI_Ct_1; 
		end
		LI_Ct_1: begin
			address_0 <= address_0 + 7'd1; //to 2
			
			//First operation
			op0 <= $signed(read_data_a[0][31:16]); //Y0 Y1
			op1 <= $signed(read_data_a[0][15:0]);
			c_index_0 <= 6'd0;
			c_index_1 <= 6'd8;
			
			M2_state <= LI_Ct_CC_0; 
		end
		///////////////////COMMON CASE//////////////////////
		LI_Ct_CC_0: begin
			//Fourth operation
			address_0 <= address_0 + 7'd1; //to 3
			
			//First operation
			T <= MULTI0 + MULTI1;
			
			//Second operation
			op0 <= $signed(read_data_a[0][31:16]);//Y2,Y3
			op1 <= $signed(read_data_a[0][15:0]);
			c_index_0 <= c_index_0 + 6'd16;
			c_index_1 <= c_index_1 + 6'd16;
			
			////write result to DPRAM after 1 CC
			if (flag_ct == 2'b1) begin
				write_data_b[1] <= T;
				write_enable_b[1] <= 1'b1;
			end
			M2_state <= LI_Ct_CC_1;
		end
		LI_Ct_CC_1: begin
			if(flag_ct == 2'b0) begin
				flag_ct <= flag_ct + 2'b1;
			end else begin
				address_3 <= address_3 + 7'd1;
			end
			write_enable_b[1] <= 1'b0;
			
			//Second oepration
			T <= T + MULTI0 + MULTI1;

			if (col_index == 4'd7)begin
								   //new Y
				address_0 <= address_0 + 7'd1;
			end else begin 
				address_0 <= address_0 - 7'd3;
			end
			
			//Third operation
			op0 <= $signed(read_data_a[0][31:16]);//Y4 Y5
			op1 <= $signed(read_data_a[0][15:0]);
			c_index_0 <= c_index_0 + 6'd16;
            c_index_1 <= c_index_1 + 6'd16;
			
			M2_state <= LI_Ct_CC_2;
		end	
		LI_Ct_CC_2: begin
			address_0 <= address_0 + 7'd1;
			
			//Third operation
			T <= T + MULTI0 + MULTI1;
			
			//Fourth operation
			op0 <= $signed(read_data_a[0][31:16]);//Y6 Y7
			op1 <= $signed(read_data_a[0][15:0]);
			c_index_0 <= c_index_0 + 6'd16;
			c_index_1 <= c_index_1 + 6'd16;
			
			M2_state <= LI_Ct_CC_3;
		end	
		LI_Ct_CC_3: begin
			address_0 <= address_0 + 7'd1;
			
			//Fourth operation
			T <= (T + MULTI0 + MULTI1) >>> 8;
			
			//First Operation
			op0 <= $signed(read_data_a[0][31:16]);//Y0 Y1
			op1 <= $signed(read_data_a[0][15:0]);
			if (col_index == 4'd7) begin
				c_index_0 <= 6'd0;
				c_index_1 <= 6'd8;
			end else begin
				c_index_0 <= c_index_0 - 6'd47;
				c_index_1 <= c_index_1 - 6'd47;
			end
			
			if(col_index == 4'd7) begin
				row_index <= row_index + 4'd1;
				col_index <= 4'd0;
			end else begin
				col_index <= col_index + 4'd1;
			end
			
			if (address_0 == 7'd29 && row_index == 4'd7) begin
				M2_state <= LI_Ct_LO_0;
			end else begin
				M2_state <= LI_Ct_CC_0;
			end
		end	
		///////////////////LEAD OUT of Ct/////////////////
		LI_Ct_LO_0:begin
			address_0 <= address_0 + 7'd1;
			
			//First operation
			T <= MULTI0 + MULTI1;
			
			//Second operation
			op0 <= $signed(read_data_a[0][31:16]);
			op1 <= $signed(read_data_a[0][15:0]);
			c_index_0 <= c_index_0 + 6'd16;
			c_index_1 <= c_index_1 + 6'd16;
			
			//T(7,6)
			write_data_b[1] <= T;
			write_enable_b[1] <= 1'b1;
			
			M2_state <= LI_Ct_LO_1;
		end
		LI_Ct_LO_1: begin
			//Second operation
			T <= T + MULTI0 + MULTI1;
			write_enable_b[1] <= 1'b0;
			address_3 <= address_3 + 7'd1;
			
			//Third operation
			op0 <= $signed(read_data_a[0][31:16]);
			op1 <= $signed(read_data_a[0][15:0]);
			c_index_0 <= c_index_0 + 6'd16;
			c_index_1 <= c_index_1 + 6'd16;
			
			M2_state <= LI_Ct_LO_2;
		end
		LI_Ct_LO_2: begin
			//Third operation
			T <= T + MULTI0 + MULTI1;
			
			//Fourth operation
			op0 <= $signed(read_data_a[0][31:16]);
			op1 <= $signed(read_data_a[0][15:0]);
			c_index_0 <= c_index_0 + 6'd16;
			c_index_1 <= c_index_1 + 6'd16;
			
			// Enable DPRAM write
			M2_state <= LI_Ct_LO_3;
		end	
		LI_Ct_LO_3:begin
			//Fourth Operation
			T <= (T + MULTI0 + MULTI1) >>> 8;
			M2_state <= LI_Ct_LO_4;
		end
		LI_Ct_LO_4:begin
			write_data_b[1] <= T; //T(7,7)
			write_enable_b[1] <= 1'b1;
			
			M2_state <= LI_Ct_LO_5;
		end
		LI_Ct_LO_5: begin
			write_enable_b[1] <= 1'b0;

			row_index <= 4'd0;
			col_index <= 4'd0;
			flag_ct <= 2'b0;
			
			address_0 <= 7'd0; //write S'
			address_2 <= 7'd0; //T(0,0)
			address_3 <= 7'd8; //T(1,0)
			
			block_col_index <= block_col_index + 6'd1;
			
			M2_state <= LI_Ct_LO_6;
		end
		LI_Ct_LO_6: begin
			address_2 <= address_2 + 7'd16; //T(2,0)
			address_3 <= address_3 + 7'd16; //T(3,0)
			SRAM_we_n <= 1'b1;
			M2_state <= LI_Ct_LO_7;
		end
		LI_Ct_LO_7: begin
			address_2 <= address_2 + 7'd16; //T(4,0)
			address_3 <= address_3 + 7'd16; //T(5,0)
		
			//First operation
			op0 <= read_data_a[1]; //T(0,0)
			op1 <= read_data_b[1]; //T(1,0)
			c_index_0 <= 6'd0;
			c_index_1 <= 6'd8;
			
			address_counter <= 7'd0;
			M2_state <= CC0_Cs_Fs_0;
		end
		//////////////ENTERING COMMON CS & FS CASE ///////////////
		CC0_Cs_Fs_0: begin		
			//Fourth operation
			address_2 <= address_2 + 7'd16; //T(6,0)/T(6,1)...
			address_3 <= address_3 + 7'd16; //T(7,0)/T(7,1)...
			
			//Second Operation
			op0 <= read_data_a[1]; //T(2,0)
			op1 <= read_data_b[1]; //T(3,0)
			c_index_0 <= c_index_0 + 6'd16;
			c_index_1 <= c_index_1 + 6'd16;
			
			//First operation
			if (col_index[0] == 1'b0) begin
				Y_0 <= MULTI0 + MULTI1;
			end else begin
				Y_1 <= MULTI0 + MULTI1;
			end

			if (col_index == 4'd7 && row_index == 4'd7) begin
				SRAM_address <= memory_offset + row_address + col_address;
			end
			//Update Y0Y1 to S portion of DPRAM
			if((row_index != 4'd0 || col_index != 4'd0) && col_index[0] == 1'b0) begin
				//write to address 3 Y0Y1
				write_data_b[0] <= {16'd0,Y_out_0,Y_out_1};
				write_enable_b[0] <= 1'b1;
				address_1 <= 7'd64 + address_counter;
			end
			M2_state <= CC0_Cs_Fs_1;	
		end
		CC0_Cs_Fs_1: begin
			//lead out or update address_2
			if (col_index == 4'd7) begin
				if (row_index == 4'd7) begin 
					col_index <= 4'd0;
					row_index <= 4'd0;
					M2_state <= CC0_Cs_Fs_4;
				end else begin
					address_2 <= 7'd0; //T(0,0)
					address_3 <= 7'd8; //T(1,0)
					M2_state <= CC0_Cs_Fs_2;
				end
			end else begin
				address_2 <= address_2 - 7'd47; //T(0,1)
				address_3 <= address_3 - 7'd47; //T(1,1)
				M2_state <= CC0_Cs_Fs_2;
			end
			
			if((row_index != 4'd0 || col_index != 4'd0) && col_index[0] == 1'b0) begin
				address_counter <= address_counter + 7'd1;
			end
		  
		    //Third operation
			op0 <= read_data_a[1]; //T(4,0)
			op1 <= read_data_b[1]; //T(5,0)
			c_index_0 <= c_index_0 + 6'd16;
			c_index_1 <= c_index_1 + 6'd16;
			
			//Second operation
			if (col_index[0] == 1'b0) begin
				Y_0 <= Y_0 + MULTI0 + MULTI1;
			end else begin
				Y_1 <= Y_1 + MULTI0 + MULTI1;
			end
			
			write_enable_b[0] <= 1'b0; //stop write
		end		
		CC0_Cs_Fs_2: begin
			address_2 <= address_2 + 7'd16; //T(2,1)
			address_3 <= address_3 + 7'd16; //T(3,1)
			
			//Third
			if (col_index[0] == 1'b0) begin
				Y_0 <= Y_0 + MULTI0 + MULTI1;
			end else begin
				Y_1 <= Y_1 + MULTI0 + MULTI1;
			end
			
			//Fourth operation
			op0 <= read_data_a[1]; //T(6,0)
			op1 <= read_data_b[1]; //T(7,0)	
			c_index_0 <= c_index_0 + 6'd16;
			c_index_1 <= c_index_1 + 6'd16;
			
			if(col_index[0] == 1'b1) begin
				//Register Y' at 76808/76810...
				Y_prime_reg <= SRAM_read_data;
			end else begin
				if((row_index != 4'd0)||(col_index != 1'b0)) begin
					write_data_b[0] <= {Y_prime_reg, SRAM_read_data};
					write_enable_b[0] <= 1'b1;
					if (address_counter != 7'd1)begin
						address_1 <= address_counter-6'd1;
					end else address_1 <= 6'd0;
				end
			end
		M2_state <= CC0_Cs_Fs_3;
		end
		CC0_Cs_Fs_3: begin
			address_2 <= address_2 + 7'd16; //T(4,1)
			address_3 <= address_3 + 7'd16; //T(5,1)
			write_enable_b[0] <= 1'b0;
			
			//First operation
			op0 <= read_data_a[1]; //T(0,0)
			op1 <= read_data_b[1]; //T(0,1)
			if (col_index == 4'd7) begin
				c_index_0 <= c_index_0 - 6'd47;
				c_index_1 <= c_index_1 - 6'd47;
			end else begin
				c_index_0 <= c_index_0 - 6'd48;
				c_index_1 <= c_index_1 - 6'd48;
			end
			
			//Fourth operation
			if (col_index[0] == 1'b0) begin
				Y_0 <= Y_0 + MULTI0 + MULTI1;
			end else begin
				Y_1 <= Y_1 + MULTI0 + MULTI1;
			end
				
			if (col_index == 4'd7) begin
				col_index <= 4'd0;
				row_index <= row_index + 4'd1;
			end else begin
				col_index <= col_index + 4'd1;
			end
			
			//76809/76810...
			SRAM_address <= memory_offset + row_address + col_address;			
			M2_state <= CC0_Cs_Fs_0;
		end
        ////////////////////////LeadOut////////////////////////////
		CC0_Cs_Fs_4: begin
			//Fourth operation
			op0 <= read_data_a[1]; //T(7,6)
			op1 <= read_data_b[1]; //T(7,7)	
			c_index_0 <= c_index_0 + 6'd16;
			c_index_1 <= c_index_1 + 6'd16;
			
			//Third Operation
			Y_1 <= Y_1 + MULTI0 + MULTI1;
			
			//With row and column both 7
			Y_prime_reg <= SRAM_read_data; //79054
			M2_state <= CC0_Cs_Fs_5;
		end
		CC0_Cs_Fs_5: begin
			//Fourth Operation
			Y_1 <= Y_1 + MULTI0 + MULTI1;
			
			//Ws write operation
			write_data_b[0] <= {Y_prime_reg,SRAM_read_data};
			write_enable_b[0] <= 1'b1;
			address_1 <= address_counter;
			
			address_0 <= 7'd0;
			address_2 <= 7'd0;
			address_3 <= 7'd0;
			
			row_index <= 4'd0;
			col_index <= 4'd0;
			
			M2_state <= CC1_Ct_Ws_0;
		end

		//////////////////LEAD IN FOR CT & WS CASE////////////////////
        CC1_Ct_Ws_0: begin
			//Ct write operation
			write_data_b[0] <= {16'd0,Y_out_0,Y_out_1};
			address_1 <= address_counter + 7'd64;
			//Read S'
			address_0 <= address_0 + 7'd1; //to 1

			M2_state <= CC1_Ct_Ws_1; 
		end
		CC1_Ct_Ws_1: begin
			write_enable_b[0] <= 1'b0;
			
			address_1 <= 7'd64;
			address_0 <= address_0 + 7'd1;//to 2
			
			//First operation
			op0 <= $signed(read_data_a[0][31:16]); //Y0 Y1
			op1 <= $signed(read_data_a[0][15:0]);
			c_index_0 <= 6'd0;
			c_index_1 <= 6'd8;
					
			M2_state <= CC1_Ct_Ws_2; 
		end
		///////////////////COMMON CASE//////////////////////
		CC1_Ct_Ws_2: begin
			address_0 <= address_0 + 7'd1;//3
			
			//First operation
			T <= MULTI0 + MULTI1;
			
			//Second operation
			op0 <= $signed(read_data_a[0][31:16]); //Y2 Y3
			op1 <= $signed(read_data_a[0][15:0]);
			c_index_0 <= c_index_0 + 6'd16;
			c_index_1 <= c_index_1 + 6'd16;
			
			//write result to DPRAM after two cycle
			if (flag_ct == 2'b1) begin
				write_data_b[1] <= T;
				write_enable_b[1] <= 1'b1;
			end
			M2_state <= CC1_Ct_Ws_3;
		end
		CC1_Ct_Ws_3: begin
			if(flag_ct == 2'b0) begin
				flag_ct <= flag_ct + 2'b1;
			end else begin
				address_3 <= address_3 + 7'd1;
			end
			//Second operation
			T <= T + MULTI0 + MULTI1;
			write_enable_b[1] <= 1'b0;

			if (col_index == 4'd7)begin
				col_index <= 4'd0;
				row_index <= row_index + 4'd1;
				address_0 <= address_0 + 7'd1;
			end else begin 
				col_index <= col_index + 4'd1;
				address_0 <= address_0 - 7'd3;
			end

			//Third operation
			op0 <= $signed(read_data_a[0][31:16]); //Y0 Y1
			op1 <= $signed(read_data_a[0][15:0]);
			c_index_0 <= c_index_0 + 6'd16;
			c_index_1 <= c_index_1 + 6'd16;
			
			if (!flag_ws)begin
				//read Y0Y1 and write it to SRAM
				if(memory_sel == 2'd0) begin
					if (block_col_index == 6'd0)begin //block_col_index = 7, row_index - 1
						SRAM_address <= (block_row_index- 6'd1) * block_row_offset + (max_col_index << 2) + (col_index >> 1) + write_offset * row_index + seg_offset;
					end else begin //block_col_index - 1
						SRAM_address <= block_row_index * block_row_offset + ((block_col_index- 6'd1) << 2) + (col_index >> 1) + write_offset * row_index + seg_offset;
					end
				end else begin
					if(block_row_index == 4'd0 && block_col_index == 4'd0) begin
						if (memory_sel == 2'd1)
						//Handling the last Y block
						SRAM_address <= 18'd37276 + (col_index >> 1) + (write_offset << 1) * row_index;
						else 
						//Handling the last U block
						SRAM_address <= 18'd57036 + (col_index >> 1) + write_offset * row_index;
					end else begin	
						if (block_col_index == 6'd0) begin //block_col_index = 7, row_index - 1
							SRAM_address <= (block_row_index - 6'd1)*block_row_offset+(max_col_index << 2) + (col_index >> 1) + write_offset * row_index + seg_offset;
						end else begin //block_col_index - 1
							SRAM_address <= block_row_index * block_row_offset + ((block_col_index- 6'd1) << 2) + (col_index >> 1) + write_offset * row_index + seg_offset;
						end
					end
				end
				SRAM_we_n <= 1'b0;
				SRAM_write_data <= read_data_b[0][15:0];//address_3 output
				flag_ws <= ~flag_ws;
			end else begin 
				flag_ws <= ~flag_ws;
				address_1 <= address_1 + 7'd1;
			end
			
			if (address_0 == 7'd31 && row_index == 4'd7 && col_index == 4'd7) begin
				M2_state <= CC1_Ct_Ws_6;
			end else begin
				M2_state <= CC1_Ct_Ws_4;
			end
		end
		
		CC1_Ct_Ws_4: begin
			address_0 <= address_0 + 7'd1;
			SRAM_we_n <= 1'b1;
			
			//Third operation
			T <= T + MULTI0 + MULTI1;
			
			//Fourth operation
			op0 <= $signed(read_data_a[0][31:16]);
			op1 <= $signed(read_data_a[0][15:0]);
			c_index_0 <= c_index_0 + 6'd16;
			c_index_1 <= c_index_1 + 6'd16;
			
			M2_state <= CC1_Ct_Ws_5;
		end	
		CC1_Ct_Ws_5: begin
			address_0 <= address_0 + 7'd1;
			
			//Fourth operation
			T <= (T + MULTI0 + MULTI1) >>> 8;
			
			//First operation
			op0 <= $signed(read_data_a[0][31:16]);
			op1 <= $signed(read_data_a[0][15:0]);
			if ((col_index == 4'd0) && (c_index_1 == 6'd63))begin
				c_index_0 <= 6'd0;
				c_index_1 <= 6'd8;
			end else begin
				c_index_0 <= c_index_0 - 6'd47;
				c_index_1 <= c_index_1 - 6'd47;
			end
			M2_state <= CC1_Ct_Ws_2;
		end	
		//////////////////LEAD OUT of Ct & Ws/////////////////
		CC1_Ct_Ws_6: begin
			//Third operation
			T <= T + MULTI0 + MULTI1;
			
			//Fourth operation
			op0 <= $signed(read_data_a[0][31:16]); //Y0 Y1
			op1 <= $signed(read_data_a[0][15:0]);
			c_index_0 <= c_index_0 + 6'd16;
			c_index_1 <= c_index_1 + 6'd16;

			M2_state <= CC1_Ct_Ws_7;
		end
		CC1_Ct_Ws_7: begin
			//Fourth operation
			T <= (T + MULTI0 + MULTI1) >>> 8;
			M2_state <= CC1_Ct_Ws_8;
		end
		CC1_Ct_Ws_8: begin 
			write_data_b[1] <= T; //T(7,7)
			write_enable_b[1] <= 1'b1;
			M2_state <= CC1_Ct_Ws_9;
		end	
		CC1_Ct_Ws_9:begin
			write_enable_b[1] <= 1'b0;
			
			SRAM_we_n <= 1'b1;
			
			//Initialize for Cs
			address_2 <= 7'd0; //read T(0,0)
			address_3 <= 7'd8; //read T(1,0)
			row_index <= 4'd0;
			col_index <= 4'd0;
			flag_ct <= 2'b0;
			M2_state <= CC1_Ct_Ws_10;
		end
		
		CC1_Ct_Ws_10: begin
			address_2 <= address_2 + 7'd16; //read T(2,0)
			address_3 <= address_3 + 7'd16; //read T(3,0)
			M2_state <= CC1_Ct_Ws_11;
		end
		
		CC1_Ct_Ws_11:begin
			address_2 <= address_2 + 7'd16; //read T(4,0)
			address_3 <= address_3 + 7'd16; //read T(5,0)
			col_index <= col_index + 4'd1;		
			
			//First operation
			op0 <= read_data_a[1]; //T(0,0)
			op1 <= read_data_b[1]; //T(0,1)
			c_index_0 <= 6'd0;
			c_index_1 <= 6'd8;
			
			//Initialize the DPRAM address for Common Case Cs and Fs 
			if((block_col_index == max_col_index) && (block_row_index == 6'd29) && (memory_sel == 2'd2)) begin
				address_0 <= 7'd64;
				address_1 <= 7'd64;
				row_index <= 4'd0;
				col_index <= 4'd0;
				M2_state <= LO_Cs_0;
			end else begin
				//Return to common case 	
				write_enable_b[1] <= 1'b0;
				row_index <= 4'd0;
				col_index <= 4'd0;
				flag_ct <= 2'b0;
				address_0 <= 7'd0;//write S'
				address_1 <= 7'd0; 
				address_counter <= 7'd0;
				
				if(block_col_index == max_col_index) begin
					if (block_row_index == 6'd29)begin
						memory_sel <= memory_sel + 2'd1;
						block_row_index <= 6'd0;
						block_col_index <= 6'd0;
					end else begin
						block_row_index <= block_row_index + 6'd1;
						block_col_index <= 6'd0;
					end
				end else begin
					block_col_index <= block_col_index + 6'd1;
				end
				M2_state <= CC0_Cs_Fs_0; //Line 431
			end
		end
		
		LO_Cs_0: begin
			address_2 <= address_2 + 7'd16; //T(0,6)
			address_3 <= address_3 + 7'd16; //T(0,7)
			
			//Second
			op0 <= read_data_a[1]; //T(0,2)
			op1 <= read_data_b[1]; //T(0,3)
			c_index_0 <= c_index_0 + 6'd16;
			c_index_1 <= c_index_1 + 6'd16;
			
			//First operation
			if(col_index[0] == 1'b0) begin
				Y_0 <= MULTI0 + MULTI1;
			end else begin
				Y_1 <= MULTI0 + MULTI1;
			end
			
			if((row_index != 4'd0 || col_index != 4'd0) && col_index[0] == 1'b0) begin
				write_data_b[0] <= {16'd0,Y_out_0,Y_out_1};
				write_enable_b[0] <= 1'b1;
			end
			M2_state <= LO_Cs_1;
		end
		LO_Cs_1: begin
			if (col_index == 4'd7) begin
				if(row_index == 4'd7) begin
					M2_state <= LO_Ws_0;
					col_index <= 4'd0;
					row_index <= 4'd0;
					w_offset <= 9'd0;
					address_0 <= 7'd64;  //Used to read in Ws
				end else begin 
					address_2 <= 7'd0; //T(0,0)
					address_3 <= 7'd8; //T(1,0)
					M2_state <= LO_Cs_2;
				end
			end else begin
				if(col_index == 4'd7) begin
					address_2 <= 7'd0; //T(8,0)
					address_3 <= 7'd8; //T(9,0)
				end else begin
					address_2 <= address_2 - 7'd47; //T(0,0)
					address_3 <= address_3 - 7'd47; //T(1,0)
				end
				M2_state <= LO_Cs_2;
			end
			
			if((row_index != 4'd0 || col_index != 4'd0) && col_index[0] == 1'b0) begin
				address_1 <= address_1 + 7'd1;
			end
			write_enable_b[0] <= 1'b0;
			
			//Third
			op0 <= read_data_a[1]; //T(4,0)
			op1 <= read_data_b[1]; //T(5,0)
			c_index_0 <= c_index_0 + 6'd16;
			c_index_1 <= c_index_1 + 6'd16;
			
			//Second Operation 
			if(col_index[0] == 1'b0) begin
				Y_0 <= Y_0 + MULTI0 + MULTI1;
			end else begin
				Y_1 <= Y_1 + MULTI0 + MULTI1;
			end
		end
		LO_Cs_2: begin
			address_2 <= address_2 + 7'd16; //T(2,0)
			address_3 <= address_3 + 7'd16; //T(3,0)
			
			//Fourth
			op0 <= read_data_a[1]; //T(6,0)
			op1 <= read_data_b[1]; //T(7,0)
			if (col_index == 4'd7) begin
				c_index_0 <= c_index_0 - 6'd47;
				c_index_1 <= c_index_1 - 6'd47;
			end else begin
				c_index_0 <= c_index_0 - 6'd48;
				c_index_1 <= c_index_1 - 6'd48;
			end
			
			//Third operation
			if(col_index[0] == 1'b0) begin
				Y_0 <= Y_0 + MULTI0 + MULTI1;
			end else begin
				Y_1 <= Y_1 + MULTI0 + MULTI1;
			end
			
			M2_state <= LO_Cs_3;
		end
		LO_Cs_3: begin
			address_2 <= address_2 + 7'd16; //T(0,4)
			address_3 <= address_3 + 7'd16; //T(0,5)
			
			//First
			op0 <= read_data_a[1]; //T(0,0)
			op1 <= read_data_b[1]; //T(0,1)
			c_index_0 <= c_index_0 + 6'd16;
			c_index_1 <= c_index_1 + 6'd16;
				
			//Fourth operation	
			if(col_index[0] == 1'b0) begin
				Y_0 <= Y_0 + MULTI0 + MULTI1;
			end else begin
				Y_1 <= Y_1 + MULTI0 + MULTI1;
			end
			
			if(col_index == 4'd7) begin
				row_index <= row_index + 4'd1;
				col_index <= 4'd0;
			end else begin
				col_index <= col_index + 4'd1;
			end
			M2_state <= LO_Cs_0;
		end
		LO_Ws_0: begin
			//Fourth
			op0 <= read_data_a[1]; //T(0,6)
			op1 <= read_data_b[1]; //T(0,7)
			c_index_0 <= c_index_0 + 6'd16;
			c_index_1 <= c_index_1 + 6'd16;
			
			//Third operation for the last Y
			Y_1 <= Y_1 + MULTI0 + MULTI1;
			
			address_0 <= address_0 + 7'd1;
			
			M2_state <= LO_Ws_1;
		end
		LO_Ws_1: begin
			SRAM_address <= 18'd76236 + col_index;
			SRAM_write_data <= read_data_a[0][15:0];
			col_index <= col_index + 4'd1;
			SRAM_we_n <= 1'b0;
			
			//Update read S address to 66
			address_0 <= address_0 + 7'd1;
			
			//Fourth operation for the last Y
			Y_1 <= Y_1 + MULTI0 + MULTI1;
		
			M2_state <= LO_Ws_2;
		end
		LO_Ws_2: begin
			//Update read S address to 65
			address_0 <= address_0 + 7'd1;
			
			SRAM_address <= 18'd76236 + col_index;
			SRAM_write_data <= read_data_a[0][15:0];
			col_index <= col_index + 4'd1; //3
			
			// Write Y62, Y63
			write_data_b[0] <= {16'd0,Y_out_0,Y_out_1};
			write_enable_b[0] <= 1'b1;
			
			M2_state <= LO_Ws_3;
		end
		LO_Ws_3: begin
			//read Y6Y7/Y8Y9... and write it to SRAM
			if(row_index == 4'd7 && col_index == 4'd3) begin
				M2_state <= LO_Ws_4;
				row_index <= 4'd0;
				col_index <= 4'd0;
				SRAM_address <= 18'd76236 + col_index + w_offset;
				SRAM_write_data <= read_data_a[0][15:0];
			end else begin
				SRAM_address <= 18'd76236 + col_index + w_offset;
				SRAM_write_data <= read_data_a[0][15:0];
				
				//Update address_2 to read next address
				if (col_index != 4'd2 || row_index != 4'd7) 
				address_0 <= address_0 + 4'd1;
			end
			
			if(col_index == 4'd3) begin
				col_index <= 4'd0;
				w_offset <= w_offset + write_offset;
				row_index <= row_index + 4'd1;
			end else begin
				col_index <= col_index + 4'd1;
			end
			write_enable_b[1] <= 1'b0;
		end
		LO_Ws_4: begin
			SRAM_address <= 18'd76236 + col_index + w_offset;
			SRAM_write_data <= read_data_a[0][15:0];
			SRAM_we_n <= 1'b1;
			M2_state <= LO_Ws_finish;
			M2_done <= 1'b1;
		end
		LO_Ws_finish: begin
			SRAM_we_n <= 1'b1;
			M2_state <= M2_IDLE;
			M2_done <= 1'b0;
		end
		default: M2_state <= M2_IDLE;
	endcase
	end
end

assign MULTI0 = C0 * op0;
assign MULTI1 = C1 * op1;

always_comb begin
	case(c_index_0)
	0:   C0 = 32'sd1448;   //C00
	1:   C0 = 32'sd1448;   //C01
	2:   C0 = 32'sd1448;   //C02
	3:   C0 = 32'sd1448;   //C03
	4:   C0 = 32'sd1448;   //C04
	5:   C0 = 32'sd1448;   //C05
	6:   C0 = 32'sd1448;   //C06
	7:   C0 = 32'sd1448;   //C07
	8:   C0 = 32'sd2008;   //C10
	9:   C0 = 32'sd1702;   //C11
	10:  C0 = 32'sd1137;   //C12
	11:  C0 = 32'sd399;    //C13
	12:  C0 = -32'sd399;   //C14
	13:  C0 = -32'sd1137;  //C15
	14:  C0 = -32'sd1702;  //C16
	15:  C0 = -32'sd2008;  //C17
	16:  C0 = 32'sd1892;   //C20
	17:  C0 = 32'sd783;    //C21
	18:  C0 = -32'sd783;   //C22
	19:  C0 = -32'sd1892;  //C23
	20:  C0 = -32'sd1892;  //C24
	21:  C0 = -32'sd783;   //C25
	22:  C0 = 32'sd783;    //C26
	23:  C0 = 32'sd1892;   //C27
	24:  C0 = 32'sd1702;   //C30
	25:  C0 = -32'sd399;   //C31
	26:  C0 = -32'sd2008;  //C32
	27:  C0 = -32'sd1137;  //C33
	28:  C0 = 32'sd1137;   //C34
	29:  C0 = 32'sd2008;   //C35
	30:  C0 = 32'sd399;    //C36
	31:  C0 = -32'sd1702;  //C37
	32:  C0 = 32'sd1448;   //C40
	33:  C0 = -32'sd1448;  //C41
	34:  C0 = -32'sd1448;  //C42
	35:  C0 = 32'sd1448;   //C43
	36:  C0 = 32'sd1448;   //C44
	37:  C0 = -32'sd1448;  //C45
	38:  C0 = -32'sd1448;  //C46
	39:  C0 = 32'sd1448;   //C47
	40:  C0 = 32'sd1137;   //C50
	41:  C0 = -32'sd2008;  //C51
	42:  C0 = 32'sd399;    //C52
	43:  C0 = 32'sd1702;   //C53
	44:  C0 = -32'sd1702;  //C54
	45:  C0 = -32'sd399;   //C55
	46:  C0 = 32'sd2008;   //C56
	47:  C0 = -32'sd1137;  //C57
	48:  C0 = 32'sd783;    //C60
	49:  C0 = -32'sd1892;  //C61
	50:  C0 = 32'sd1892;   //C62
	51:  C0 = -32'sd783;   //C63
	52:  C0 = -32'sd783;   //C64
	53:  C0 = 32'sd1892;   //C65
	54:  C0 = -32'sd1892;  //C66
	55:  C0 = 32'sd783;    //C67
	56:  C0 = 32'sd399;    //C70
    57:  C0 = -32'sd1137;  //C71
    58:  C0 = 32'sd1702;   //C72
    59:  C0 = -32'sd2008;  //C73
    60:  C0 = 32'sd2008;   //C74
    61:  C0 = -32'sd1702;  //C75
    62:  C0 = 32'sd1137;   //C76
    63:  C0 = -32'sd399;   //C77
	endcase
end

always_comb begin
	case(c_index_1)
	0:   C1 = 32'sd1448;
	1:   C1 = 32'sd1448;
	2:   C1 = 32'sd1448;
	3:   C1 = 32'sd1448;
	4:   C1 = 32'sd1448;
	5:   C1 = 32'sd1448;
	6:   C1 = 32'sd1448;
	7:   C1 = 32'sd1448;
	8:   C1 = 32'sd2008;
	9:   C1 = 32'sd1702;
	10:  C1 = 32'sd1137;
	11:  C1 = 32'sd399;
	12:  C1 = -32'sd399;
	13:  C1 = -32'sd1137;
	14:  C1 = -32'sd1702;
	15:  C1 = -32'sd2008;
	16:  C1 = 32'sd1892;
	17:  C1 = 32'sd783;
	18:  C1 = -32'sd783;
	19:  C1 = -32'sd1892;
	20:  C1 = -32'sd1892;
	21:  C1 = -32'sd783;
	22:  C1 = 32'sd783;
	23:  C1 = 32'sd1892;
	24:  C1 = 32'sd1702;
	25:  C1 = -32'sd399;
	26:  C1 = -32'sd2008;
	27:  C1 = -32'sd1137;
	28:  C1 = 32'sd1137;
	29:  C1 = 32'sd2008;
	30:  C1 = 32'sd399;
	31:  C1 = -32'sd1702;
	32:  C1 = 32'sd1448;
	33:  C1 = -32'sd1448;
	34:  C1 = -32'sd1448;
	35:  C1 = 32'sd1448;
	36:  C1 = 32'sd1448;
	37:  C1 = -32'sd1448;
	38:  C1 = -32'sd1448;
	39:  C1 = 32'sd1448;
	40:  C1 = 32'sd1137;
	41:  C1 = -32'sd2008;
	42:  C1 = 32'sd399;
	43:  C1 = 32'sd1702;
	44:  C1 = -32'sd1702;
	45:  C1 = -32'sd399;
	46:  C1 = 32'sd2008;
	47:  C1 = -32'sd1137;
	48:  C1 = 32'sd783;
	49:  C1 = -32'sd1892;
	50:  C1 = 32'sd1892;
	51:  C1 = -32'sd783;
	52:  C1 = -32'sd783;
	53:  C1 = 32'sd1892;
	54:  C1 = -32'sd1892;
	55:  C1 = 32'sd783;
	56:  C1 = 32'sd399;
    57:  C1 = -32'sd1137;
    58:  C1 = 32'sd1702;
    59:  C1 = -32'sd2008;
    60:  C1 = 32'sd2008;
    61:  C1 = -32'sd1702;
    62:  C1 = 32'sd1137;
    63:  C1 = -32'sd399;
	endcase	
end

endmodule
