//MILESTONE1 UNIT

`timescale 1ns/100ps

`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

`include "define_state.h"
module M1_interface(
	 input logic Clock,
	 input logic resetn,
	 input logic start,
	 input logic  [15:0] SRAM_read_data,
	 output logic [15:0] SRAM_write_data,
	 output logic done,
	 output logic SRAM_we_n,
	 output logic [17:0] SRAM_address 
);

M1_state_type M1_state;


logic [17:0] data_counter, y_counter, y_counter_loop;
logic [15:0] u_register[2:0];//UV register
logic [15:0] v_register[2:0];
logic [15:0] y_register[1:0];

logic [15:0] u_register_com;
logic [15:0] v_register_com;
logic [15:0] y_register_com[1:0];

logic [7:0] u_5[1:0] ; //U[(J-5)/2]+U[(J+5)/2]
logic [7:0] u_3[1:0] ; //U[(J-3)/2]+U[(J+3)/2]
logic [7:0] u_1[1:0] ;
logic [7:0] v_5[1:0] ;
logic [7:0] v_3[1:0] ;
logic [7:0] v_1[1:0] ;
parameter U_OFFSET   = 18'd38400,
          V_OFFSET   = 18'd57600,
			 RGB_OFFSET = 18'd146944;
		  
logic [31:0] u_odd[2:0];//U'1,U'3,U'5
logic [31:0] v_odd[2:0];
logic [31:0] u_odd_com[1:0]; //common case u odd U'7, U'9
logic [31:0] v_odd_com[1:0]; //common case v odd V'5, V'7
logic [31:0] u_even_com[1:0]; 
logic [31:0] v_even_com[1:0]; 
logic [31:0] u_prime_even_buf;
logic [31:0] v_prime_even_buf;
logic [15:0] u_even[1:0]; //U'0,U'2,U'4,U'6
logic [15:0] v_even[1:0]; //V'0,V'2,V'4,V'6
logic [17:0] RGB_address;

logic signed[31:0] coeff; //76284,104595,-25624,-53281,132251: sign-extension needed
logic [31:0] OP3;  		//Even RGB output, 32 bits
logic [31:0] OP4; 	 	//Odd RGB output, 32 signed already
logic [8:0]  OP1;  		//SRAM read memory, zero-extension needed
logic signed[8:0] OP2;  //21, -52, 159: sign-extension needed
logic [31:0] op3_math, op4_math;  

logic [31:0] MULTI, MULTI_RGB1, MULTI_RGB0;// uv MULTIPLICATION
logic [31:0] RED[1:0];
logic [31:0] GREEN[1:0];
logic [31:0] BLUE[1:0];

logic [7:0] R_OUT[1:0];
logic [7:0] G_OUT[1:0];
logic [7:0] B_OUT[1:0];

logic [7:0] R_register[1:0]; //Store RGB0 ~ RGB4
logic [7:0] G_register[1:0];
logic [7:0] B_register[1:0];

logic [15:0] R_register_com[1:0]; //Store common case
logic [15:0] G_register_com[1:0];
logic [15:0] B_register_com[1:0];

logic [31:0] op1_extended, op2_extended;


always @(posedge Clock or negedge resetn) begin
    if (~resetn)begin
		OP1 <= 8'd0;
		OP2 <= 8'd0;
		OP3 <= 32'd0;
		OP4 <= 32'd0;
		coeff <= 32'sd0;
		SRAM_we_n <= 1'b1;	
		done <= 1'b0;		
		RED[1]   <= 32'd0;
		RED[0]   <= 32'd0;
		BLUE[1]  <= 32'd0;
		BLUE[0]  <= 32'd0;
		GREEN[1] <= 32'd0;
		GREEN[0] <= 32'd0;
		R_register_com[1] <= 16'd0;
		R_register_com[0] <= 16'd0;
		G_register_com[1] <= 16'd0;
		G_register_com[0] <= 16'd0;
		B_register_com[1] <= 16'd0;
		B_register_com[0] <= 16'd0;
		R_register[1] <= 8'd0;
		R_register[0] <= 8'd0;
		G_register[1] <= 8'd0;
		G_register[0] <= 8'd0;
		B_register[1] <= 8'd0;
		B_register[0] <= 8'd0;
		u_5[1] <= 8'd0;
		u_5[0] <= 8'd0;
		u_3[1] <= 8'd0;
		u_3[0] <= 8'd0;
		u_1[1] <= 8'd0;
		u_1[0] <= 8'd0;
		v_5[1] <= 8'd0;
		v_5[0] <= 8'd0;
		v_3[1] <= 8'd0;
		v_3[0] <= 8'd0;
		v_1[1] <= 8'd0;
		v_1[0] <= 8'd0;
		u_register[2] <= 16'd0;
		u_register[1] <= 16'd0;
		u_register[0] <= 16'd0;
		v_register[2] <= 16'd0;
		v_register[1] <= 16'd0;
		v_register[0] <= 16'd0;
		y_register[1] <= 16'd0;
		y_register[0] <= 16'd0;
		y_register_com[1] <= 16'd0;
		y_register_com[0] <= 16'd0;
		u_register_com <= 16'd0;
		v_register_com <= 16'd0;
		u_odd_com[1] <= 32'd0;
		u_odd_com[0] <= 32'd0;
		v_odd_com[1] <= 32'd0;
		v_odd_com[0] <= 32'd0;
		u_even_com[1] <= 32'd0;
		u_even_com[0] <= 32'd0;
		v_even_com[1] <= 32'd0;
		v_even_com[0] <= 32'd0;
		u_even[1] <= 16'd0;
		u_even[0] <= 16'd0;
		v_even[1] <= 16'd0;
		v_even[0] <= 16'd0;
		data_counter <= 18'd0;
		y_counter <= 18'd0;
		y_counter_loop <= 18'd0;
		u_prime_even_buf <= 32'd0;
		v_prime_even_buf <= 32'd0;
		u_odd[2] <= 32'd0;
		u_odd[1] <= 32'd0;
		u_odd[0] <= 32'd0;
		v_odd[2] <= 32'd0;
		v_odd[1] <= 32'd0;
		v_odd[0] <= 32'd0;
		RGB_address <= RGB_OFFSET;
		M1_state <= M1_IDLE;		
	end else begin
		case (M1_state)
		M1_IDLE: begin
			if (start) begin
				//start or finish one frame
				M1_state <= LI_0;
				SRAM_we_n <= 1'b1; //read
				SRAM_address <= data_counter + U_OFFSET;
				u_odd[2] <= 32'd0;
				u_odd[1] <= 32'd0;
				u_odd[0] <= 32'd0;
				v_odd[2] <= 32'd0;
				v_odd[1] <= 32'd0;
				v_odd[0] <= 32'd0;
				u_even[1] <= 16'd0;
				u_even[0] <= 16'd0;
				v_even[1] <= 16'd0;
				v_even[0] <= 16'd0;
				u_prime_even_buf <= 32'd0;
				v_prime_even_buf <= 32'd0;
				u_odd_com[1] <= 32'd0;
				u_odd_com[0] <= 32'd0;
				v_odd_com[1] <= 32'd0;
				v_odd_com[0] <= 32'd0;
				u_even_com[1] <= 32'd0;
				u_even_com[0] <= 32'd0;
				v_even_com[1] <= 32'd0;
				v_even_com[0] <= 32'd0;
				u_register[2] <= 16'd0;
				u_register[1] <= 16'd0;
				u_register[0] <= 16'd0;
				v_register[2] <= 16'd0;
				v_register[1] <= 16'd0;
				v_register[0] <= 16'd0;
				y_register[1] <= 16'd0;
				y_register[0] <= 16'd0;
				y_register_com[1] <= 16'd0;
				y_register_com[0] <= 16'd0;
				u_register_com <= 16'd0;
				v_register_com <= 16'd0;
				RED[1]   <= 32'd0;
				RED[0]   <= 32'd0;
				BLUE[1]  <= 32'd0;
				BLUE[0]  <= 32'd0;
				GREEN[1] <= 32'd0;
				GREEN[0] <= 32'd0;
				R_register_com[1] <= 16'd0;
				R_register_com[0] <= 16'd0;
				G_register_com[1] <= 16'd0;
				G_register_com[0] <= 16'd0;
				B_register_com[1] <= 16'd0;
				B_register_com[0] <= 16'd0;
				R_register[1] <= 8'd0;
				R_register[0] <= 8'd0;
				G_register[1] <= 8'd0;
				G_register[0] <= 8'd0;
				B_register[1] <= 8'd0;
				B_register[0] <= 8'd0;
				OP1 <= 9'sd0;
				OP2 <= 9'sd0;
				OP3 <= 32'd0;
				OP4 <= 32'd0;
				coeff <= 32'sd0;
				u_5[1] <= 8'd0;
				u_5[0] <= 8'd0;
				u_3[1] <= 8'd0;
				u_3[0] <= 8'd0;
				u_1[1] <= 8'd0;
				u_1[0] <= 8'd0;
				v_5[1] <= 8'd0;
				v_5[0] <= 8'd0;
				v_3[1] <= 8'd0;
				v_3[0] <= 8'd0;
				v_1[1] <= 8'd0;
				v_1[0] <= 8'd0;
			end
		end 
		
		LI_0: begin
			SRAM_address <= data_counter + U_OFFSET + 18'd1;
            M1_state <= LI_1;			
		end
		LI_1 : begin
			SRAM_address <= data_counter + V_OFFSET;
			M1_state <= LI_2;
		end
		LI_2 : begin
			SRAM_address <= data_counter + V_OFFSET + 18'd1;
			data_counter <= data_counter + 18'd2;
			
			//read U0U1
			u_register[1] <= SRAM_read_data;
			u_5[1] <= SRAM_read_data[15:8];
			u_3[1] <= SRAM_read_data[15:8];
			u_1[1] <= SRAM_read_data[15:8];
			u_1[0] <= SRAM_read_data[7:0];
			M1_state <= LI_3;
		end		
		LI_3 : begin
		    SRAM_address <= y_counter;
			y_counter <= y_counter + 18'd1;
			
			//read U2U3
			u_register[0] <= SRAM_read_data;
			u_5[0] <= SRAM_read_data[7:0];
			u_3[0] <= SRAM_read_data[15:8];
			M1_state <= LI_4;
		end		
		LI_4 : begin
			//read V0V1
			v_register[1] <= SRAM_read_data;
			v_5[1] <= SRAM_read_data[15:8];
			v_3[1] <= SRAM_read_data[15:8];
			v_1[1] <= SRAM_read_data[15:8];
			v_1[0] <= SRAM_read_data[7:0];
			
			//calculate 21*(u0+u3)
			OP1 <= u_5[1] + u_5[0];
			OP2 <= 9'sd21;
			
			//calculate RGB0 ---> green
			coeff <= -32'sd25624;
			
			//op3: U'0, even number
			OP3 <= u_register[1][15:8];
			M1_state <= LI_5;	
		end	
		
		LI_5 : begin
		    //read V2V3
			v_register[0] <= SRAM_read_data;
			
			v_5[0] <= SRAM_read_data[7:0];
			v_3[0] <= SRAM_read_data[15:8];
			u_odd[2] <= MULTI;
			
			//CALCULATE -52(U0+U2)
		    OP1 <= u_3[1] + u_3[0];
			OP2 <= -9'sd52;
			
			//ACCUMULATE RGB0
			GREEN[1] <= MULTI_RGB1;
			
			//calculate RGB0 --> red
			coeff <= 32'sd104595;
			OP3 <= v_register[1][15:8];
			M1_state <= LI_6;
		end	
		
		LI_6 : begin
		    SRAM_address <= data_counter + U_OFFSET;
			y_register[1] <= SRAM_read_data;
			
			//calculate 59*(U0+U1)
			OP1 <= u_1[1] + u_1[0];;
			OP2 <= 9'sd159;
			
			//calculate RGB0
			coeff <= 32'sd76284;
			OP3 <= SRAM_read_data[15:8];
			
			u_odd[2] <= u_odd[2] + MULTI;
			
			//ACCUMULATE RGB0
			RED[1] <= MULTI_RGB1;
			M1_state <= LI_7;
		end
		LI_7 : begin
		     SRAM_address <= data_counter + V_OFFSET;
			 data_counter <= data_counter + 18'd1;
			 u_odd[2] <= (u_odd[2] + MULTI + 32'd128) >>> 8;
			
			//calculate 21*(V0+V3)
			 OP1 <= v_5[1] + v_5[0];
			 OP2 <= 9'sd21;
			 
			 //calculate RGB0
			 coeff <= -32'sd53281;
			 OP3 <= v_register[1][15:8];
			 
			 //ACCUMULATE RGB Y --> RED GREEN BLUE
			 RED[1]   <= RED[1] + MULTI_RGB1;
			 GREEN[1] <= GREEN[1] + MULTI_RGB1;
			 BLUE[1]  <= MULTI_RGB1;
			 //shift u register
			 //u_5[1] = U[j-5] = U0
			 //u_5[0] = U[j+5] = U3
			 //u_3[1] = U[j-3] = U0
			 //u_3[0] = U[j+3] = U2
			 //u_1[1] = U[j-1] = U0
			 //u_1[0] = U[j+1] = U1
			 u_5[1] <= u_3[1];
			 u_3[1] <= u_1[1];
			 u_1[1] <= u_1[0];
			 u_1[0] <= u_3[0];
			 u_3[0] <= u_5[0];
			 
			 M1_state <= LI_8;
		end
		LI_8 : begin
			 SRAM_address <= y_counter;
			 y_counter <= y_counter + 18'd1;
			 
			 v_odd[2] <= MULTI;
		     
			 //calculate -52*(V0+V2)
			 OP1 <= v_3[1] + v_3[0];
			 OP2 <= -9'sd52;
			 
			 //RGB
			 coeff <= 32'sd132251;
			 OP3 <= u_register[1][15:8];
			 //ACCUMULATE RGB0
			 GREEN[1] <= GREEN[1] + MULTI_RGB1;
			 //EVEN UV
			 u_even[1] <= {u_register[1][7:0],u_register[0][15:8]}; //U'2,U'4
			 u_even[0] <= {8'd0,u_register[0][7:0]}; 				//U'6
			 v_even[1] <= {v_register[1][7:0],v_register[0][15:8]}; //v'2,v'4
			 v_even[0] <= {8'd0,v_register[0][7:0]}; 				//V'6
			 
			 M1_state <= LI_9;
		end
		LI_9 : begin
			 u_register[2] <= SRAM_read_data; //U4,U5
		     
			 u_prime_even_buf <= {16'd0,u_even[0]};
			
			//calculate -52*(V0+V3)
			 OP1 <= v_1[1] + v_1[0];
			 OP2 <= 9'sd159;
			 
			 v_odd[2] <= v_odd[2] + MULTI;
			 
			 //ACCUMULATE RGB
			 BLUE[1] <= BLUE[1] + MULTI_RGB1;
			 M1_state <= LI_10;
		end
		LI_10 : begin
		     v_register[2] <= SRAM_read_data; //V4V5
			 v_odd[2] <= (v_odd[2] + MULTI + 32'd128) >>> 8;//V'1 sum
			 
			 u_5[0] <= u_register[2][15:8]; //U4
			 
			 // Write RGB0
			 R_register[0] <= R_OUT[1];  //What should this be: MSB or LSB?????
			 G_register[0] <= G_OUT[1];
			 B_register[0] <= B_OUT[1];
			 			 
			 v_5[1] <= v_3[1];
			 v_3[1] <= v_1[1];
			 v_1[1] <= v_1[0];
			 v_1[0] <= v_3[0];
			 v_3[0] <= v_5[0];
			 
			 
			 //calculate 21*(U0+U4)
			 OP1 <= u_5[1] + u_register[2][15:8];
			 OP2 <= 9'sd21;
			 
			 // RGB2 first operation
			 coeff <= -32'sd25624;
			 OP3 <= {24'd0,u_even[1][15:8]};
			 
			 // RGB1 first operation
			 OP4 <= u_odd[2]; //U'1
			 
			 M1_state <= LI_11;
			 
		end
		LI_11:begin
		    y_register[0] <= SRAM_read_data; //'Y2 Y3
			
			//calculate -52*(U0+U3)
			OP1 <= u_3[1] + u_3[0];
			OP2 <= -9'sd52;
			
			u_odd[1] <= MULTI;
			
			v_5[0] <= v_register[2][15:8]; //V4
			
			// RGB2 second operation
			coeff <= 32'sd104595;
			OP3 <= {24'd0,v_even[1][15:8]}; //V'2
			//ACCUMULATE RGB2
			GREEN[1] <= MULTI_RGB1;
			
			// RGB1 second operation
			OP4 <= v_odd[2]; //V'1
			//ACCUMULATE RGB1
			GREEN[0] <= MULTI_RGB0;
			
			M1_state <= LI_12;
		end
		LI_12:begin
			//calculate 159*(U1+U2)
			OP1 <= u_1[1] + u_1[0];
			OP2 <= 9'sd159;
			
			// RGB2 third operation
			coeff <= 32'sd76284;
			OP3 <= {24'd0,y_register[0][15:8]}; //V'2
			//ACCUMULATE RGB2
			RED[1] <= MULTI_RGB1;
			
			u_odd[1] <= u_odd[1] + MULTI;
			
			// RGB1 third operation
			OP4 <= {24'd0,y_register[1][7:0]}; //V'1
			//ACCUMULATE RGB1
			RED[0] <= MULTI_RGB0;
			M1_state <= LI_13;
		end
		LI_13:begin
			SRAM_address <= y_counter;
			y_counter <= y_counter + 18'd1;
			
			//calculate 21*(V0+V4)
			OP1 <= v_5[1] + v_5[0];
			OP2 <= 9'sd21;
			
			// RGB2 fourth operation
			coeff <= -32'sd53281;
			OP3 <= {24'd0,v_even[1][15:8]}; //V'2
			//ACCUMULATE RGB2
			GREEN[1] <= GREEN[1] + MULTI_RGB1;
			RED[1]   <= RED[1] + MULTI_RGB1;
			BLUE[1]  <= MULTI_RGB1;
			
			// RGB1 fourth operation
			OP4 <= v_odd[2]; //V'1
			//ACCUMULATE RGB1
			GREEN[0]<= GREEN[0] + MULTI_RGB0;
			RED[0]  <= RED[0] + MULTI_RGB0;
			BLUE[0] <= MULTI_RGB0;
			
			// Assign U'3 SUM
			u_odd[1] <= (u_odd[1] + MULTI + 32'd128) >>> 8;
			
			//shift u'3 register
			u_5[1] <= u_3[1];
			u_3[1] <= u_1[1];
			u_1[1] <= u_1[0];
			u_1[0] <= u_3[0];
			u_3[0] <= u_5[0];
			u_5[0] <= u_register[2][7:0]; //U5
			
			M1_state <= LI_14;
		end
		LI_14:begin
			v_odd[1] <= MULTI;
			
			//calculate -52*(V0+V3)
			OP1 <= v_3[1] + v_3[0];
			OP2 <= -9'sd52;
			
			// RGB2 fifth operation
			coeff <= 32'sd132251;
			OP3 <= {24'd0,u_even[1][15:8]}; //U'2
			
			//ACCUMULATE RGB2
			GREEN[1] <= GREEN[1] + MULTI_RGB1;
		    GREEN[0] <= GREEN[0] + MULTI_RGB0;
			
			// RGB1 fifth operation
			OP4 <= u_odd[2]; //U'1
			
			M1_state <= LI_15;
		end
		LI_15:begin
			//Calculate 159*(V1+V2)
			OP1 <= v_1[1] + v_1[0];
			OP2 <= 9'sd159;
			
			//ACCUMULATE BLUE
			BLUE[1] <= BLUE[1] + MULTI_RGB1;
		    BLUE[0] <= BLUE[0] + MULTI_RGB0;
			
			v_odd[1] <= v_odd[1] + MULTI;
			
			//Update RGB2 to registers [2]
			R_register_com[1] <= {R_OUT[1],8'd0};  //What should this be: MSB or LSB?????
			G_register_com[1] <= {G_OUT[1],8'd0};
			
			//Update RGB1 to registers [1]
			R_register[1] <= R_OUT[0];  //What should this be: MSB or LSB?????
			G_register[1] <= G_OUT[0];
			
			M1_state <= LI_16;
		end
		LI_16:begin
			SRAM_address <= RGB_address;
			RGB_address <= RGB_address + 18'd1;
			//Write R0G0 to SRAM
			SRAM_write_data <= {R_register[0],G_register[0]};
			
			// Assign V'3 SUM
			v_odd[1] <= (v_odd[1] + MULTI + 32'd128) >>> 8;
			// Assign y register for Y4Y5
			y_register[1] <= SRAM_read_data; 
			//shift v'3 register
			v_5[1] <= v_3[1];
			v_3[1] <= v_1[1];
			v_1[1] <= v_1[0];
			v_1[0] <= v_3[0];
			v_3[0] <= v_5[0];
			v_5[0] <= v_register[2][7:0]; //V5
			
			//UPDATE b1 b2 
			B_register_com[1] <= {B_OUT[1],8'd0};
			B_register[1] <= B_OUT[0];
			
			// RGB4 first operation
			coeff <= -32'sd25624;
			OP3 <= {24'd0,u_even[1][7:0]}; //U'4
			 
			// RGB3 first operation
			OP4 <= u_odd[1]; //U'3
			
			//Calculate 21*(U0+U5)
			OP1 <= u_5[1] + u_5[0];
			OP2 <= 9'sd21;
			
			M1_state <= LI_17;
			SRAM_we_n <= 1'b0;//write in next cycle
		end
		LI_17:begin
			SRAM_address <= RGB_address;
			RGB_address <= RGB_address + 18'd1;
			//Write B0R1 to SRAM
			SRAM_write_data <= {B_register[0],R_register[1]};
			
			//rgb4 green accumulate
			GREEN[1] <= MULTI_RGB1;
			//RGB3
			GREEN[0] <= MULTI_RGB0;
			
			// RGB4 second operation
			coeff <= 32'sd104595;
			OP3 <= {24'd0,v_even[1][7:0]}; //U'4
			 
			// RGB3 second operation
			OP4 <= v_odd[1]; //U'3
			
			u_odd_com[0] <= MULTI;
			
			//Calculate -52*(U1+U4)
			OP1 <= u_3[1] + u_3[0];
			OP2 <= -9'sd52;
			
			M1_state <= LI_18;
		end
		LI_18:begin
			SRAM_address <= data_counter + U_OFFSET;
		
			// RGB4 third operation
			coeff <= 32'sd76284;
			OP3 <= {24'd0,y_register[1][15:8]}; //Y4
			
			u_odd_com[0] <= u_odd_com[0] + MULTI;
			 
			// RGB3 third operation
			OP4 <= {24'd0,y_register[0][7:0]}; //Y3
			
			//Calculate 159*(U2+U3)
			OP1 <= u_1[1] + u_1[0];
			OP2 <= 9'sd159;
			
			RED[1] <= MULTI_RGB1;
			RED[0] <= MULTI_RGB0;
			
			M1_state <= LI_19;
			SRAM_we_n <= 1'b1;//read in next cycle
		end
		LI_19:begin
			SRAM_address <= data_counter + V_OFFSET;
			data_counter <= data_counter + 18'd1;
			
			// Assign U'5
			u_odd_com[0] <= (u_odd_com[0] + MULTI + 32'd128) >>> 8;
			
			// RGB4 fourth operation
			coeff <= -32'sd53281;
			OP3 <= {24'd0,v_even[1][7:0]}; //V'4
			GREEN[1] <= GREEN[1] + MULTI_RGB1;
            RED[1]   <= RED[1] + MULTI_RGB1;
            BLUE[1]  <= MULTI_RGB1;			
			
			// RGB3 fourth operation
			OP4 <= v_odd[1]; //V'3
			
			GREEN[0] <= GREEN[0] + MULTI_RGB0;
            RED[0]   <= RED[0] + MULTI_RGB0;
            BLUE[0]  <= MULTI_RGB0;
			
			//Calculate 21*(V0+V5)
			OP1 <= v_5[1] + v_5[0];
			OP2 <= 9'sd21;
			
			M1_state <= LI_20;
		end
		LI_20:begin
			SRAM_address <= y_counter;
			y_counter <= y_counter + 18'd1;
			
			// RGB4 fifth operation
			coeff <= 32'sd132251;
			OP3 <= {24'd0,u_even[1][7:0]}; //U'4
			GREEN[1] <= GREEN[1] + MULTI_RGB1;
			
			// RGB3 fifth operation
			OP4 <= u_odd[1]; //U'3
			GREEN[0] <= GREEN[0] + MULTI_RGB0;
			
			v_odd_com[0] <= MULTI;
			
			//Calculate -52*(V1+V4)
			OP1 <= v_3[1] + v_3[0];
			OP2 <= -9'sd52;
			
			//shift u'3 register
			u_5[1] <= u_3[1];
			u_3[1] <= u_1[1];
			u_1[1] <= u_1[0];
			u_1[0] <= u_3[0];
			u_3[0] <= u_5[0];
			
			v_prime_even_buf <= {24'd0,v_even[0][7:0]};
			
			//EVEN U and V using common register now
			u_even_com[1] <={24'd0,u_register[2][15:8]}; //U4
			u_even_com[0] <={24'd0,u_register[2][7:0]};  //U5
			v_even_com[1] <={24'd0,v_register[2][15:8]}; //V4
			v_even_com[0] <={24'd0,v_register[2][7:0]};  //V5
			
			M1_state <= LI_21;
		end
		LI_21:begin
			SRAM_address <= RGB_address;
			RGB_address <= RGB_address + 18'd1;
			//Write G1,B1 to SRAM
			SRAM_write_data <= {G_register[1],B_register[1]};
			
			// Update U6U7
			u_register_com <= SRAM_read_data;
			
			//Calculate 159*(V2+V3)
			OP1 <= v_1[1] + v_1[0];
			OP2 <= 9'sd159;
			
			// Assign V'5 sum
			v_odd_com[0] <= v_odd_com[0] + MULTI;
			
			BLUE[1] <= BLUE[1] + MULTI_RGB1;
			BLUE[0] <= BLUE[0] + MULTI_RGB0;
			
			//Update RGB4, RGB3 to registers [0]
			R_register_com[0] <= {R_OUT[1],R_OUT[0]};  //What should this be: MSB or LSB?????
			G_register_com[0] <= {G_OUT[1],G_OUT[0]};
			
			M1_state <= LI_22;
			SRAM_we_n <= 1'b0;//write
		end
		LI_22:begin
			SRAM_address <= RGB_address;
			RGB_address <= RGB_address + 18'd1;
			//Write R2G2 to SRAM
			SRAM_write_data <= {R_register_com[1][15:8],G_register_com[1][15:8]};
			
			//Update RGB4, RGB3
			B_register_com[0] <= {B_OUT[1],B_OUT[0]};
				
			// Giving the roller coaster new value
			u_5[0] <= u_register_com[15:8]; //U6
			
			//Calculate U'7: 21*(U1+U6)
			OP1 <= u_5[1] + u_register_com[15:8];
			OP2 <= 9'sd21;
			
			// Assign V'5 sum
			v_odd_com[0] <= (v_odd_com[0] + MULTI + 32'd128) >>> 8;
			
			// RGB6 first operation
			coeff <= -32'sd25624;
			OP3 <= {24'd0,u_even[0][7:0]}; //U'6
			 
			// RGB5 first operation
			OP4 <= u_odd_com[0]; //U'5 buffer
			
			// Update V6V7
			v_register_com <= SRAM_read_data;
			
			//shift v'5 register
			v_5[1] <= v_3[1];
			v_3[1] <= v_1[1];
			v_1[1] <= v_1[0];
			v_1[0] <= v_3[0];
			v_3[0] <= v_5[0];
			v_5[0] <= SRAM_read_data[15:8]; //U6/U8...
			
			y_register_com[0] <= {8'd0,y_register[1][7:0]};
			
			M1_state <= CC_0;
		end
		CC_0: begin
			SRAM_address <= RGB_address;
			RGB_address <= RGB_address + 18'd1;
			//Write B2R3 to SRAM
			SRAM_write_data <= {B_register_com[1][15:8],R_register_com[0][7:0]};
			
			// Update Y6Y7
			y_register_com[1] <= SRAM_read_data;

			u_odd_com[1] <= MULTI;
			
			//Calculate -52*(U2+U5)
			OP1 <= u_3[1] + u_3[0];
			OP2 <= -9'sd52;
			
			// RGB6/RGB10... second operation
			coeff <= 32'sd104595;
			OP3   <= v_prime_even_buf; //V'6
			GREEN[1] <= MULTI_RGB1; 
				
				
			// RGB5/RGB10... second operation
			OP4 <= v_odd_com[0]; //V'5
			GREEN[0] <= MULTI_RGB0;
			
			M1_state <= CC_1;
		end
		CC_1: begin
			SRAM_address <= RGB_address;
			RGB_address <= RGB_address + 18'd1;
			//Write G3B3 to SRAM
			SRAM_write_data <= {G_register_com[0][7:0],B_register_com[0][7:0]};	
			
			//Calculate 159*(U3+U4)
			OP1 <= u_1[1] + u_1[0];
			OP2 <= 9'sd159;
			
			u_odd_com[1] <= u_odd_com[1] + MULTI;
			
			// RGB6 third operation
			coeff <= 32'sd76284;
			OP3   <= {24'd0,y_register_com[1][15:8]}; //Y6
			RED[1] <= MULTI_RGB1;
			
			// RGB5 third operation
			OP4 <= {24'd0,y_register_com[0][7:0]}; //Y5
			RED[0] <= MULTI_RGB0;
			
			M1_state <= CC_2;
		end
		CC_2: begin
			SRAM_address <= y_counter;
			y_counter <= y_counter + 18'd1;
			
			//Assign U'7 to register
			u_odd_com[1] <= (u_odd_com[1] + MULTI + 32'd128) >>> 8;	
				
			//Calculate 159*(U3+U4)
			OP1 <= v_5[1] + v_5[0];
			OP2 <= 9'sd21;
			
			// RGB6 fourth operation
			coeff <= -32'sd53281;
			OP3 <= v_prime_even_buf; //V'6,V'10
			GREEN[1] <= GREEN[1] + MULTI_RGB1; 
			RED[1]   <= RED[1] + MULTI_RGB1;
			BLUE[1]  <= MULTI_RGB1;
			
			// RGB5 fourth operation
			OP4 <= v_odd_com[0]; //V'5, V'9
			GREEN[0] <= GREEN[0] + MULTI_RGB0; 
			RED[0]   <= RED[0] + MULTI_RGB0;
			BLUE[0]  <= MULTI_RGB0;
			
			//Roller Coaster of u'odd register
			u_5[1] <= u_3[1];
			u_3[1] <= u_1[1];
			u_1[1] <= u_1[0];
			u_1[0] <= u_3[0];
			u_3[0] <= u_5[0];
			u_5[0] <= u_register_com[7:0]; //U7
			
			M1_state <= CC_3;
			SRAM_we_n <= 1'b1;			
		end
		CC_3: begin	
			v_odd_com[1] <= MULTI;
			
			//Calculate -52(V2+U5)
			OP1 <= v_3[1] + v_3[0];
			OP2 <= -9'sd52;
			
			// RGB6 fifth operation
			coeff <= 32'sd132251;
			OP3 <= u_prime_even_buf; //U'6
			GREEN[1] <= GREEN[1] + MULTI_RGB1; 
			
			// RGB5 fifth operation
			OP4 <= u_odd_com[0]; //U'5
			GREEN[0] <= GREEN[0] + MULTI_RGB0;
			
			M1_state <= CC_4;
		end
		CC_4: begin
			//Calculate 159(V3+U4)
			OP1 <= v_1[1] + v_1[0];
			OP2 <= 9'sd159;	
			
			BLUE[1] <= BLUE[1] + MULTI_RGB1;
			BLUE[0] <= BLUE[0] + MULTI_RGB0;
			
			v_odd_com[1] <= v_odd_com[1] + MULTI;
			
			//Update RGB6 to [1][15:8] and RGB5 to registers [1][7:0]
			R_register_com[1] <= {R_OUT[1],R_OUT[0]};
			G_register_com[1] <= {G_OUT[1],G_OUT[0]};
			
			M1_state <= CC_5;
		end
		CC_5: begin
		    SRAM_address <= RGB_address;
			RGB_address <= RGB_address + 18'd1;
			//Assign R4G4 to SRAM
			SRAM_write_data <= {R_register_com[0][15:8],G_register_com[0][15:8]};
			
			B_register_com[1] <= {B_OUT[1],B_OUT[0]};
			//Assign Y8Y9
			y_register_com[0] <= SRAM_read_data;
			
			//Assign V'7 sum
			v_odd_com[1] <= (v_odd_com[1] + MULTI + 32'd128) >>> 8;
			
			//Calculate U'9: 21(U2+U7)
			OP1 <= u_5[1] + u_5[0];
			OP2 <= 9'sd21;
			
			//RGB8 first operation
			coeff <= -32'sd25624;
			OP3 <= u_even_com[1]; //U'8
			 
			//RGB7 first operation
			OP4 <= u_odd_com[1]; ; //U'7
			
			//Roller Coaster of v'odd register
			v_5[1] <= v_3[1];
			v_3[1] <= v_1[1];
			v_1[1] <= v_1[0];
			v_1[0] <= v_3[0];
			v_3[0] <= v_5[0];
			v_5[0] <= v_register_com[7:0]; //V7
			
			M1_state <= CC_6;
			SRAM_we_n <= 1'b0;
		end
		CC_6: begin
			SRAM_address <= RGB_address;
			RGB_address <= RGB_address + 18'd1;
			//Assign B4R5 to SRAM
			SRAM_write_data <= {B_register_com[0][15:8],R_register_com[1][7:0]};
			
			//Calculate -52(U3+U6)
			OP1 <= u_3[1] + u_3[0];
			OP2 <= -9'sd52;
			
			u_odd_com[0] <= MULTI;
			
			//RGB8 second operation
			coeff <= 32'sd104595;
			OP3 <= v_even_com[1]; //V'8
			GREEN[1] <= MULTI_RGB1; 
			//RGB7 second operation
			OP4 <= v_odd_com[1]; ; //V'7
			GREEN[0] <= MULTI_RGB0; 
			
			M1_state <= CC_7;
		end
		CC_7: begin
			if (y_counter - y_counter_loop != 18'd157) begin
				SRAM_address <= data_counter + U_OFFSET;
			end	
			
			//Calculate -159(U4+U5)
			OP1 <= u_1[1] + u_1[0];
			OP2 <= 9'sd159;
			
			u_odd_com[0] <= u_odd_com[0] + MULTI;
			
			//RGB8 third operation
			coeff <= 32'sd76284;
			OP3 <= {24'd0,y_register_com[0][15:8]}; //Y8
			RED[1] <= MULTI_RGB1;  
			//RGB7 third operation
			OP4 <= {24'd0,y_register_com[1][7:0]}; //Y7
			RED[0] <= MULTI_RGB0; 
			
			M1_state <= CC_8;
			SRAM_we_n <= 1'b1;
		end
		CC_8: begin
			if (y_counter - y_counter_loop != 18'd157) begin
				SRAM_address <= data_counter + V_OFFSET;
				data_counter <= data_counter + 18'd1;
			end
			
			//Calculate 21(V2+V7)
			OP1 <= v_5[1] + v_5[0];
			OP2 <= 9'sd21;
			
			//RGB8 fourth operation
			coeff <= -32'sd53281;
			OP3 <= v_even_com[1]; //V'8
			GREEN[1] <= GREEN[1] + MULTI_RGB1; 
			RED[1]   <= RED[1] + MULTI_RGB1; 
			BLUE[1]  <= MULTI_RGB1;
			
			//RGB7 fourth operation
			OP4 <= v_odd_com[1]; //V'7
			GREEN[0] <= GREEN[0] + MULTI_RGB0; 
			RED[0]   <= RED[0] + MULTI_RGB0; 
			BLUE[0]  <= MULTI_RGB0;
			//Assign U'9 sum
			u_odd_com[0] <= (u_odd_com[0] + MULTI + 32'd128) >>> 8;
			
			//Buffer U'10, V'10
			u_prime_even_buf <= u_even_com[0];
			v_prime_even_buf <= v_even_com[0];
			
			M1_state <= CC_9;
		end
		CC_9: begin
			SRAM_address <= y_counter;
			if (y_counter - y_counter_loop != 18'd157) begin
				y_counter <= y_counter + 18'd1;
			end
			
			//Calculate -52(V3+V6)
			OP1 <= v_3[1] + v_3[0];
			OP2 <= -9'sd52;
			
			v_odd_com[0] <= MULTI;
			
			//RGB8 fifth operation
			coeff <= 32'sd132251;
			OP3 <= u_even_com[1]; //U'8
			GREEN[1] <= GREEN[1] + MULTI_RGB1; 

			//RGB7 fifth operation
			OP4 <= u_odd_com[1]; //U'7
			GREEN[0] <= GREEN[0] + MULTI_RGB0;  
			
			//EVEN U and V using common register now
			u_even_com[1] <= {24'd0,u_register_com[15:8]}; //U'12
			u_even_com[0] <= {24'd0,u_register_com[7:0]};  //U'14
			v_even_com[1] <= {24'd0,v_register_com[15:8]}; //V'12
			v_even_com[0] <= {24'd0,v_register_com[7:0]};  //V'14
			
			//Roller Coaster of v'odd register
			u_5[1] <= u_3[1];
			u_3[1] <= u_1[1];
			u_1[1] <= u_1[0];
			u_1[0] <= u_3[0];
			u_3[0] <= u_5[0];
			
			M1_state <= CC_10;
		end
		CC_10: begin
			SRAM_address <= RGB_address;
			RGB_address <= RGB_address + 18'd1;
			//Assign G5B5 to SRAM
			SRAM_write_data <= {G_register_com[1][7:0],B_register_com[1][7:0]};
			
			//Assign U8U9
			if (y_counter - y_counter_loop != 18'd157) begin
				u_register_com <= SRAM_read_data;//read u
			end
			
			v_odd_com[0] <= v_odd_com[0] + MULTI;
			
			//Calculate -159(V4+V5)
			OP1 <= v_1[1] + v_1[0];
			OP2 <= 9'sd159;
			BLUE[1] <= BLUE[1] + MULTI_RGB1;
			BLUE[0] <= BLUE[0] + MULTI_RGB0;
			
			//Update RGB8 to [0][15:8] and RGB7 to registers [0][7:0]
			R_register_com[0] <= {R_OUT[1],R_OUT[0]};  //What should this be: MSB or LSB?????
			G_register_com[0] <= {G_OUT[1],G_OUT[0]};
			
			M1_state <= CC_11;
			SRAM_we_n <= 1'b0;
		end
		CC_11: begin
			SRAM_address <= RGB_address;//147409 R310,G310
	        RGB_address <= RGB_address + 18'd1;
			//Assign R6G6 to SRAM or Write R310 G310 to SRAM
			SRAM_write_data <= {R_register_com[1][15:8],G_register_com[1][15:8]};
			
			//Update RGB8 to [0][15:8] and RGB7 to [0][7:0]
			B_register_com[0] <= {B_OUT[1],B_OUT[0]};
			
			if (y_counter - y_counter_loop != 18'd157) begin
				//Assign V8V9
				v_register_com <= SRAM_read_data;
			end
			
			//Assign V'9 sum
			v_odd_com[0] <= (v_odd_com[0] + MULTI + 32'd128) >>> 8;
			
			//shift register --> V'11
			v_5[1] <= v_3[1];
			v_3[1] <= v_1[1];
			v_1[1] <= v_1[0];
			v_1[0] <= v_3[0];
			v_3[0] <= v_5[0];
			
			if (y_counter - y_counter_loop != 18'd157) begin
				v_5[0] <= SRAM_read_data[15:8]; //V8
				u_5[0] <= u_register_com[15:8]; //U8
			end else begin
				v_5[0] <= v_5[0]; // V159
				//U_5 IS U155+U160 ==> INPUT U155+U159 ==> U_5[0] <= U_5[0]
				u_5[0] <= u_5[0];
			end
			
			//Calculate 21(U3+U8)
			if (y_counter - y_counter_loop != 18'd157) begin
				OP1 <= u_5[1] + u_register_com[15:8];
			end else begin
				OP1 <= u_5[1] + u_5[0];
			end
			OP2 <= 9'sd21;
			
			//RGB10 first operation
			coeff <= -32'sd25624;
			OP3 <= u_prime_even_buf; //U'10
			 
			//RGB9 first operation
			OP4 <= u_odd_com[0]; //U'9
			
			if (y_counter - y_counter_loop == 8'd157) M1_state <= LO_0;
			else M1_state <= CC_0;
			SRAM_we_n <= 1'b0;
		end
		////last common case CC11, shift u_5 and v_5 register 
		////op1 = 21 //// check if y = 157 
		////if true : U_5 IS U155+U160 ==> INPUT U155+U199 ==> U_5[0] <= U_5[0]
		//////////////V_5 IS V155+V160 ==> INPUT V155+V159 ==> V_5[0] <= V_5[0]
		
		///////////////////LEAD OUT////////////////////////////
	    LO_0: begin
			//147410's address
	        SRAM_address <= RGB_address;
	        RGB_address <= RGB_address + 18'd1;
			//Write B310 R311 to SRAM
			SRAM_write_data <= {B_register_com[1][15:8],R_register_com[0][7:0]};
			
			//read Y value Y314, Y315
			y_register_com[1] <= SRAM_read_data;
			
			//U'135, U156+U159
			//calculate 21*(U156+U159)
		    OP1 <= u_3[1] + u_3[0];
	        OP2 <= -9'sd52;
			
			//u_odd_com[1]addition
			u_odd_com[1]<= MULTI;
			
			//RGB 314
		    coeff <= 32'sd104595;
			OP3 <= v_prime_even_buf;
			GREEN[1] <= MULTI_RGB1;
			
			//RGB 313
			OP4 <= v_odd_com[0];
			GREEN[0] <= MULTI_RGB0;
			
	    M1_state <= LO_1;
		end
	    
	    LO_1: begin
			//147411's address
	        SRAM_address <= RGB_address;
	        RGB_address <= RGB_address + 18'd1;
			//Write G311 B311 to SRAM
			SRAM_write_data <= {G_register_com[0][7:0],B_register_com[0][7:0]};
			
			//calculate 159*(U157+U158)
		    OP1 <= u_1[1] + u_1[0];
	        OP2 <= 9'sd159;
			
			//u_odd_com[1]addition
			u_odd_com[1] <= u_odd_com[1] + MULTI;
			
			// RGB314 third operation
			coeff <= 32'sd76284;
			OP3 <= {24'd0,y_register_com[1][15:8]}; //Y314
			RED[1] <= MULTI_RGB1;

			// RGB313 third operation
			OP4 <= {24'd0,y_register_com[0][7:0]}; //Y313
			RED[0] <= MULTI_RGB0;
			
			//Update y_counter
			y_counter <= y_counter + 18'd1; //158
	    
		M1_state <= LO_2;
		
		end
	    
	    LO_2: begin
			SRAM_address <= y_counter;
			SRAM_we_n <= 1'b1;
			y_counter <= y_counter + 18'd1;
			
			//shift U_5,U_3 AND U_1 for -----> U'317
		    u_5[1] <= u_3[1];
	        u_3[1] <= u_1[1];
	        u_1[1] <= u_1[0];
	        u_1[0] <= u_3[0];
	        u_3[0] <= u_5[0];
	        u_5[0] <= u_3[0]; //U159
			
			//calculate 21*(V155+V159)
		    OP1 <= v_5[1] + v_5[0];
	        OP2 <= 9'sd21;
		
			//u_odd_com[1]addition
			u_odd_com[1]<= (u_odd_com[1] + MULTI + 32'd128) >>> 8;
			
			GREEN[1] <= GREEN[1] + MULTI_RGB1; 
			RED[1]   <= RED[1] + MULTI_RGB1; 
			BLUE[1]  <= MULTI_RGB1; 
 	
            GREEN[0] <= GREEN[0] + MULTI_RGB0; 
            RED[0]   <= RED[0] + MULTI_RGB0; 
            BLUE[0]  <= MULTI_RGB0;
		
			// RGB314 fourth operation
			coeff <= -32'sd53281;
			OP3 <= v_prime_even_buf; //V'314
			 
			// RGB315 fourth operation
			OP4 <= v_odd_com[0];  //V'313
			
		M1_state <= LO_3;	
		SRAM_we_n <= 1'b1;//read
		end
		
	    LO_3: begin
			//calculate -52*(V156+V159)
		    OP1 <= v_3[1] + v_3[0];
	        OP2 <= -9'sd52;
		
			//v_odd_com[1]addition
			v_odd_com[1] <= MULTI;
		
			// RGB314 fifth operation
			coeff <= 32'sd132251;
			OP3 <= u_prime_even_buf; 
			GREEN[1] <= GREEN[1] + MULTI_RGB1; 

			// RGB313 fifth operation
			OP4 <= u_odd_com[0];  
			GREEN[0] <= GREEN[0] + MULTI_RGB0;  
		
		M1_state <= LO_4;
		end
		
	    LO_4: begin
			//calculate 159*(V157+V158)
		    OP1 <= v_1[1] + v_1[0];
	        OP2 <= 9'sd159;
			
			BLUE[1] <= BLUE[1] + MULTI_RGB1;
			BLUE[0] <= BLUE[0] + MULTI_RGB0;
			
			//v_odd_com[1]addition
			v_odd_com[1] <= v_odd_com[1] + MULTI;
			//Update RGB314 to [1][15:8] and RGB313 to registers [1][7:0]
		
			R_register_com[1] <= {R_OUT[1],R_OUT[0]};  
			G_register_com[1] <= {G_OUT[1],G_OUT[0]};
			
		M1_state <= LO_5;	
	    end
	    
	    LO_5: begin
			//147406's address
			SRAM_address <= RGB_address;
	        RGB_address <= RGB_address + 18'd1;
			//Write R312 G312 to SRAM
			SRAM_write_data <= {R_register_com[0][15:8],G_register_com[0][15:8]};
			
			//read Y value Y316, Y317
			y_register_com[0] <= SRAM_read_data;
			B_register_com[1] <= {B_OUT[1],B_OUT[0]};
			
			//shift register --> V'317
			v_5[1] <= v_3[1];
			v_3[1] <= v_1[1];
			v_1[1] <= v_1[0];
			v_1[0] <= v_3[0];
			v_3[0] <= v_5[0];
			v_5[0] <= v_3[0]; 
			
			//calculate 21*(U156+V159)
		    OP1 <= u_5[1] + u_5[0];
	        OP2 <= 9'sd21;
			
			//v_odd_com[1]addition
			v_odd_com[1]<= (v_odd_com[1] + MULTI + 32'd128) >>> 8;
			
			//RGB316 first operation
			coeff <= -32'sd25624;
			OP3 <= u_even_com[1]; //U'316
			 
			//RGB315 first operation
			OP4 <= u_odd_com[1];  //U'315
	    
		M1_state <= LO_6;
		SRAM_we_n <= 1'b0;//write
		end
	    
	    LO_6: begin
			//147407's address
	        SRAM_address <= RGB_address;
	        RGB_address <= RGB_address + 18'd1;
			//Write B312 R313 to SRAM
			SRAM_write_data <= {B_register_com[0][15:8],R_register_com[1][7:0]};
			
			//calculate -52*(U157+V159)
		    OP1 <= u_3[1] + u_3[0];
	        OP2 <= -9'sd52;
			
			//u_odd_com[0]addition
			u_odd_com[0] <= MULTI;
			
			//RGB316 second operation
			coeff <= 32'sd104595;
			OP3 <= v_even_com[1]; //V'316
			GREEN[1] <= MULTI_RGB1;
			
			//RGB315 second operation
			OP4 <= v_odd_com[1];  //V'315
			GREEN[0] <= MULTI_RGB0;
			
		M1_state <= LO_7;
		end
	    
	    LO_7: begin
			//calculate 159*(U158+V159)
		    OP1 <= u_1[1] + u_1[0];
	        OP2 <= 9'sd159;
			
			//u_odd_com[0]addition
			u_odd_com[0] <= u_odd_com[0] + MULTI;
			
			//RGB316 third operation
			coeff  <= 32'sd76284;
			OP3    <= {24'd0,y_register_com[0][15:8]}; //Y316
			RED[1] <= MULTI_RGB1;
			
			//RGB315 third operation
			OP4 <= {24'd0,y_register_com[1][7:0]}; //Y315
			RED[0] <= MULTI_RGB0;
			
		M1_state <= LO_8;
		SRAM_we_n <= 1'b1;
		end
	    
	    LO_8: begin
			//shift U_5,U_3 AND U_1 for -----> U'319
		    u_5[1] <= u_3[1];
	        u_3[1] <= u_1[1];
	        u_1[1] <= u_1[0];
	        u_1[0] <= u_3[0];
	        u_3[0] <= u_5[0];
	        u_5[0] <= u_3[0]; //U159
			
			//calculate 21*(V156+V159)
		    OP1 <= v_5[1] + v_5[0];
	        OP2 <= 9'sd21;
			
			//RGB316 fourth operation
			coeff <= -32'sd53281;
			OP3 <= v_even_com[1]; //V'316
			
			GREEN[1] <= GREEN[1] + MULTI_RGB1; 
			RED[1] <= RED[1] + MULTI_RGB1; 
			BLUE[1] <= MULTI_RGB1;
			
			//RGB315 fourth operation
			OP4 <= v_odd_com[1]; //V'315	
			
			GREEN[0] <= GREEN[0] + MULTI_RGB0; 
			RED[0] <= RED[0] + MULTI_RGB0; 
			BLUE[0] <= MULTI_RGB0;
			
			//u_odd_com[0]addition
			u_odd_com[0]<= (u_odd_com[0] + MULTI + 32'd128) >>> 8;
		
		M1_state <= LO_9;
		end
	    
	    LO_9: begin
			SRAM_address <= y_counter;
			
			//calculate -52*(V157+V159)
		    OP1 <= v_3[1] + v_3[0];
	        OP2 <= -9'sd52;
			
			//v_odd_com[0]addition
			v_odd_com[0] <= MULTI;
			
			//RGB316 fifth operation
			coeff <= 32'sd132251;
			OP3 <= u_even_com[1]; //U'316
			GREEN[1] <= GREEN[1] + MULTI_RGB1; 
			
			//RGB315 fifth operation
			OP4 <= u_odd_com[1]; //U'315
			GREEN[0] <= GREEN[0] + MULTI_RGB0;  
		
		M1_state <= LO_10;	
	    end
	    LO_10: begin
	        SRAM_address <= RGB_address;
	        RGB_address <= RGB_address + 18'd1;
			//Write G313,B313 to SRAM
			SRAM_write_data <= {G_register_com[1][7:0],B_register_com[1][7:0]};
			
			//calculate 158*(V158+V159)
		    OP1 <= v_1[1] + v_1[0];
	        OP2 <= 9'sd159;
			
			//v_odd_com[0]addition
			v_odd_com[0] <= v_odd_com[0] + MULTI;
			BLUE[1] <= BLUE[1] + MULTI_RGB1;
			BLUE[0] <= BLUE[0] + MULTI_RGB0;
			
			//Update RGB316 to [0][15:8] and RGB315 to registers [0][7:0]
			R_register_com[0] <= {R_OUT[1],R_OUT[0]};  
			G_register_com[0] <= {G_OUT[1],G_OUT[0]};
	
		M1_state <= LO_11;
		SRAM_we_n <= 1'b0;
	    end
	    
	    LO_11: begin
	        SRAM_address <= RGB_address;
	        RGB_address <= RGB_address + 18'd1;
			//Write R314,G314 to SRAM
			SRAM_write_data <= {R_register_com[1][15:8],G_register_com[1][15:8]};
			
			B_register_com[0] <= {B_OUT[1],B_OUT[0]};
		
			//shift register --> V'319
			v_5[1] <= v_3[1];
			v_3[1] <= v_1[1];
			v_1[1] <= v_1[0];
			v_1[0] <= v_3[0];
			v_3[0] <= v_5[0];
			v_5[0] <= v_3[0];
			
			//calculate 21*(U+U)
		    OP1 <= u_5[1] + u_5[0];
	        OP2 <= 9'sd21;
			
			//v_odd_com[0]addition
			v_odd_com[0]<= (v_odd_com[0] + MULTI + 32'd128) >>> 8;	
			
			// RGB318 first operation
			coeff <= -32'sd25624;
			OP3 <= u_even_com[0]; //U'318
			 
			// RGB317 first operation
			OP4 <= u_odd_com[0]; //U'317
			
		M1_state <= LO_12;
		end
        
        LO_12:begin
	        SRAM_address <= RGB_address;
	        RGB_address <= RGB_address + 18'd1;
			//Write B314,R315 to SRAM
			SRAM_write_data <= {B_register_com[1][15:8],R_register_com[0][7:0]};
			
			//Y318 Y319			
		    y_register_com[1] <= SRAM_read_data;
			
			//calculate -52*(U+U)
		    OP1 <= u_3[1] + u_3[0];
	        OP2 <= -9'sd52;	
			
			//u_odd_com[1]addition
			u_odd_com[1]<= MULTI;	
			
			// RGB318 second operation
			coeff <= 32'sd104595;
			OP3 <= v_even_com[0]; //V'318
			
			GREEN[1] <= MULTI_RGB1; 
			
			// RGB317 second operation
			OP4 <= v_odd_com[0]; //V'317	
			
			GREEN[0] <= MULTI_RGB0;
			
		M1_state <= LO_13;
		end
        
        LO_13:begin
	        SRAM_address <= RGB_address;
	        RGB_address <= RGB_address + 18'd1;
			//Write G315, B315 to SRAM
			SRAM_write_data <= {G_register_com[0][7:0],B_register_com[0][7:0]};
			
			//calculate 158*(U+U)
		    OP1 <= u_1[1] + u_1[0];
	        OP2 <= 9'sd159;	
			
			//u_odd_com[1]addition
			u_odd_com[1]<= MULTI + u_odd_com[1];
			
			// RGB318 third operation
			coeff <= 32'sd76284;
			OP3 <= {24'd0,y_register_com[1][15:8]}; //Y318
			
			RED[1] <= MULTI_RGB1;
		
			// RGB317 third operation
			OP4 <= {24'd0,y_register_com[0][7:0]}; //Y317
			
			RED[0] <= MULTI_RGB0; 
	   
		M1_state <= LO_14;
		end
	    
        LO_14:begin
	        SRAM_address <= RGB_address;
	        RGB_address <= RGB_address + 18'd1;
			//Write R316,G316 to SRAM
			SRAM_write_data <= {R_register_com[0][15:8],G_register_com[0][15:8]};
			
			//calculate 21*(V157+V159)
		    OP1 <= v_5[1] + v_5[0];
	        OP2 <= 9'sd21;
	
			//u_odd_com[1]addition
			u_odd_com[1]<= (MULTI + u_odd_com[1] + 32'd128) >>> 8;
			
			// RGB318 fourth operation
			coeff <= -32'sd53281;
			OP3 <= v_even_com[0]; //V'318
			
			GREEN[1] <= GREEN[1] + MULTI_RGB1; 
			RED[1] <= RED[1] + MULTI_RGB1; 
			BLUE[1] <= MULTI_RGB1; 
		
			// RGB317 fourth operation
			OP4 <= v_odd_com[0]; //V'317
			
			GREEN[0] <= GREEN[0] + MULTI_RGB0; 
			RED[0] <= RED[0] + MULTI_RGB0; 
			BLUE[0] <= MULTI_RGB0;	
			
	    M1_state <= LO_15;
		end
	    
        LO_15 : begin
			//calculate 21*(V158+V159)
		    OP1 <= v_3[1] + v_3[0];
	        OP2 <= -9'sd52;
			
			//v_odd_com[1]addition
			v_odd_com[1] <= MULTI;
			
			// RGB318 fifth operation
			coeff <= 32'sd132251;
			OP3 <= u_even_com[0]; //U'318
			GREEN[1] <= GREEN[1] + MULTI_RGB1; 
 
			// RGB316 fifth operation
			OP4 <= u_odd_com[0];  //U'317
			GREEN[0] <= GREEN[0] + MULTI_RGB0; 
	   
   	    M1_state <= LO_16;
		SRAM_we_n <= 1'b1;
		end
	    
        LO_16:begin
			BLUE[1] <= BLUE[1] + MULTI_RGB1;
			BLUE[0] <= BLUE[0] + MULTI_RGB0;
			
			//calculate 21*(V159+V159)
		    OP1 <= v_1[1] + v_1[0];
	        OP2 <= 9'sd159;
			
			//v_odd_com[1]addition
			v_odd_com[1] <= MULTI + v_odd_com[1];
			
			//Update RGB318 to [1][15:8] and RGB317 to registers [1][7:0]
			R_register_com[1] <= {R_OUT[1],R_OUT[0]};  //What should this be: MSB or LSB?????
			G_register_com[1] <= {G_OUT[1],G_OUT[0]};
	   
   	    M1_state <= LO_17;
		SRAM_we_n <= 1'b1;
		end
	    
        LO_17 : begin
			SRAM_address <= RGB_address;
	        RGB_address <= RGB_address + 18'd1;
			//Write B316,R317 to SRAM
			SRAM_write_data <= {B_register_com[0][15:8],R_register_com[1][7:0]};
			
			B_register_com[1] <= {B_OUT[1],B_OUT[0]};
			
			//v_odd_com[1]addition
			v_odd_com[1]<= (MULTI + v_odd_com[1] + 32'd128) >>> 8;
	 
			//RGB319 first operation
			coeff <= -32'sd25624;
			OP4 <= u_odd_com[1];  //U'319
	    
		M1_state <= LO_18;
        SRAM_we_n <= 1'b0;
		end
	    
        LO_18 : begin
	        SRAM_address <= RGB_address;
	        RGB_address <= RGB_address + 18'd1;
			//Write G317,B317 to SRAM
			SRAM_write_data <= {G_register_com[1][7:0],B_register_com[1][7:0]};
			
			//RGB319 second operation
			coeff <= 32'sd104595;
			OP4 <= v_odd_com[1];  //V'319
			GREEN[0] <= MULTI_RGB0;
	    
		M1_state <= LO_19;
		end
	    
        LO_19 : begin
	        SRAM_address <= RGB_address;
	        RGB_address <= RGB_address + 18'd1;
			//Write R318,G318 to SRAM
			SRAM_write_data <= {R_register_com[1][15:8],G_register_com[1][15:8]};
			
			//RGB319 third operation
			coeff <= 32'sd76284;
			OP4 <= {24'd0,y_register_com[1][7:0]}; //Y319
			RED[0] <= MULTI_RGB0;
	   
   	    M1_state <= LO_20;
		end
	    
        LO_20 : begin 	
			//RGB319 fourth operation
			coeff <= -32'sd53281;
			OP4 <= v_odd_com[1]; //V'319
		    
			GREEN[0] <= GREEN[0] + MULTI_RGB0; 
		    RED[0] <= RED[0] + MULTI_RGB0; 
		    BLUE[0] <= MULTI_RGB0;	
	    
		M1_state <= LO_21;
		SRAM_we_n <= 1'b1;
		end
	    
        LO_21 : begin
			//RGB319 fifth operation
			coeff <= 32'sd132251;
			OP4 <= u_odd_com[1]; //U'319
			GREEN[0] <= GREEN[0] + MULTI_RGB0;
	   
	   M1_state <= LO_22;
	   end
	    
        LO_22 : begin
			BLUE[0] <= BLUE[0] + MULTI_RGB0;
		   
		    //Update RGB319 to registers [0][7:0]
			R_register_com[0] <= R_OUT[0];  //What should this be: MSB or LSB?????
			G_register_com[0] <= G_OUT[0];
	    
		M1_state <= LO_23;
		end
	    
        LO_23 : begin
			SRAM_address <= RGB_address;
	        RGB_address <= RGB_address + 18'd1;
			//Write B318,R319 to SRAM
			SRAM_write_data <= {B_register_com[1][15:8],R_register_com[0][7:0]};
			
			B_register_com[0] <= B_OUT[0];
			
		M1_state <= LO_24;
		SRAM_we_n <= 1'b0; //write;
	    end
	    
        LO_24 : begin
			SRAM_address <= RGB_address;
	        RGB_address <= RGB_address + 18'd1;
			//Write G319,B319 to SRAM
			SRAM_write_data <= {G_register_com[0][7:0],B_register_com[0][7:0]};	
		
			y_counter <= y_counter + 18'd1;  //160
			
			
		M1_state <= LO_25;
	    end
	    
        LO_25 : begin
			SRAM_we_n <= 1'b1;
			if (y_counter == 18'd38400) begin //finish rows;
				M1_state <= M1_finish;
				done <= 1'b1;
			end
			else begin
				M1_state <= M1_IDLE;
				y_counter_loop <= y_counter;     //160
				
			end
		end
		M1_finish : begin
			done <= 1'b0;
			M1_state <= M1_IDLE;
		end
		
		default : M1_state <= M1_IDLE;
		endcase
	end //END OF IF RESETN
//END OF FLIP FLOP
end
///////

assign op1_extended = {23'd0, OP1};
assign op2_extended = {{23{OP2[8]}},OP2};
assign op3_math = (coeff == 32'sd76284) ? OP3 - 32'd16 : OP3 - 32'd128;
assign op4_math = (coeff == 32'sd76284) ? OP4 - 32'd16 : OP4 - 32'd128;

assign MULTI = op1_extended * op2_extended;
assign MULTI_RGB1 = coeff * op3_math;
assign MULTI_RGB0 = coeff * op4_math;
//assign MULTI_RGB1 = (op3_math[31]) ? coeff * 32'd0 : coeff * op3_math;
//assign MULTI_RGB0 = (op4_math[31]) ? coeff * 32'd0 : coeff * op4_math;
//assign MULTI_RGB0 = (coeff == 32'sd76284) ? coeff * (OP4 - 32'sd16) : coeff * (OP4 - 32'sd128);

assign R_OUT[1] = (RED[1][31]) ? 8'd0 : (|RED[1][30:24]) ? 8'd255 : RED[1][23:16];
assign G_OUT[1] = (GREEN[1][31]) ? 8'd0 : (|GREEN[1][30:24]) ? 8'd255 : GREEN[1][23:16];
assign B_OUT[1] = (BLUE[1][31]) ? 8'd0 : (|BLUE[1][30:24]) ? 8'd255 : BLUE[1][23:16];

assign R_OUT[0] = (RED[0][31]) ? 8'd0 : (|RED[0][30:24]) ? 8'd255 : RED[0][23:16];
assign G_OUT[0] = (GREEN[0][31]) ? 8'd0 : (|GREEN[0][30:24]) ? 8'd255 : GREEN[0][23:16];
assign B_OUT[0] = (BLUE[0][31]) ? 8'd0 : (|BLUE[0][30:24]) ? 8'd255 : BLUE[0][23:16];
//assign B_OUT[0] = (BLUE[0][31]) ? 8'd0 : (|BLUE[0][30:24]) ? 8'd255 : BLUE[0][23:16];

//always_comb begin
//case(M1_state)
//	M1_IDLE: M1_state_out <= 32'd26  ;
//	LI_0:    M1_state_out <= 32'd0   ;
//	LI_1:    M1_state_out <= 32'd1   ;
//	LI_2:    M1_state_out <= 32'd2   ;
//	LI_3:    M1_state_out <= 32'd3   ;
//	LI_4:    M1_state_out <= 32'd4   ;
//	LI_5:    M1_state_out <= 32'd5   ;
//	LI_6:    M1_state_out <= 32'd6   ;
//	LI_7:    M1_state_out <= 32'd7   ;
//	LI_8:    M1_state_out <= 32'd8   ;
//	LI_9:    M1_state_out <= 32'd9   ;
//	LI_10:   M1_state_out <= 32'd10  ;
//	LI_11:   M1_state_out <= 32'd11  ;
//	LI_12:   M1_state_out <= 32'd12  ;
//	LI_13:   M1_state_out <= 32'd13  ;
//	LI_14:   M1_state_out <= 32'd14  ;
//	LI_15:   M1_state_out <= 32'd15  ;
//	LI_16:   M1_state_out <= 32'd16  ;
//	LI_17:   M1_state_out <= 32'd17  ;
//	LI_18:   M1_state_out <= 32'd18  ;
//	LI_19:   M1_state_out <= 32'd19  ;
//	LI_20:   M1_state_out <= 32'd20  ;
//	LI_21:   M1_state_out <= 32'd21  ;
//	LI_22:	 M1_state_out <= 32'd22  ;
//	CC_0:    M1_state_out <= 32'd0   ;
//	CC_1:    M1_state_out <= 32'd1   ;
//	CC_2:    M1_state_out <= 32'd2   ;
//	CC_3:    M1_state_out <= 32'd3   ;
//	CC_4:    M1_state_out <= 32'd4   ;
//	CC_5:    M1_state_out <= 32'd5   ;
//	CC_6:    M1_state_out <= 32'd6   ;
//	CC_7:    M1_state_out <= 32'd7   ;
//	CC_8:    M1_state_out <= 32'd8   ;
//	CC_9:    M1_state_out <= 32'd9   ;
//	CC_10:   M1_state_out <= 32'd10  ;
//	CC_11:   M1_state_out <= 32'd11  ;
//	LO_0:    M1_state_out <= 32'd0   ;
//	LO_1:    M1_state_out <= 32'd1   ;
//	LO_2:    M1_state_out <= 32'd2   ;
//	LO_3:    M1_state_out <= 32'd3   ;
//	LO_4:    M1_state_out <= 32'd4   ;
//	LO_5:    M1_state_out <= 32'd5   ;
//	LO_6:    M1_state_out <= 32'd6   ;
//	LO_7:    M1_state_out <= 32'd7   ;
//	LO_8:    M1_state_out <= 32'd8   ;
//	LO_9:    M1_state_out <= 32'd9   ;
//	LO_10:   M1_state_out <= 32'd10  ;
//	LO_11:   M1_state_out <= 32'd11  ;
//	LO_12:   M1_state_out <= 32'd12  ;
//	LO_13:   M1_state_out <= 32'd13  ;
//	LO_14:   M1_state_out <= 32'd14  ;
//	LO_15:   M1_state_out <= 32'd15  ;
//	LO_16:   M1_state_out <= 32'd16  ;
//	LO_17:   M1_state_out <= 32'd17  ;
//	LO_18:   M1_state_out <= 32'd18  ;
//	LO_19:   M1_state_out <= 32'd19  ;
//	LO_20:   M1_state_out <= 32'd20  ;
//	LO_21:   M1_state_out <= 32'd21  ;
//	LO_22:   M1_state_out <= 32'd22  ;
//	LO_23:   M1_state_out <= 32'd23  ;
//	LO_24:   M1_state_out <= 32'd24  ;
//	LO_25:   M1_state_out <= 32'd25  ;
//	M1_finish: M1_state_out <= 32'd26;
//	endcase
//end


//always_comb begin
//   case(coeff):
//	-25624 : begin 
//	         GREEN[0]<=coeff * (OP4-18'd128);
//	         coeff <= 18'sd1045955;
//	         end
//				
//	1045955: begin
//				RED[0] <= coeff * (OP4-18'd128);
//				coeff <= 18'sd76284;
//	         end
//				
//	76284:   begin
//				GREEN[0] <= GREEN[0] + coeff*(OP4-18'd16);
//				RED[0] <= (RED[0] + coeff*(OP4-18'd16))/65536;
//				BLUE[0] <= coeff*(OP4-18'd16);
//	         coeff <= -18'sd53281;
//	         end
//				
//	-53281:  begin
//				GREEN[0] <= (GREEN[0] + coeff*(OP4-18'd128))/65536;
//				coeff <= -18'sd132251;
//	         end
//	132251:  begin
//				BLUE[0] <= (BLUE[0] + coeff*(OP4-18'd128))/65536;
//				coeff <= 18'sd0;
//	         end
//	0: coeff <= -18'sd25624;
//   endcase
//   default: begin
//			GREEN[0]<=32'd0;
//			RED[0]<=32'd0;
//			RED[0]<=32'd0;
//   end
////END FLIP FLOP
//end


endmodule