`ifndef DEFINE_STATE

// This defines the states
typedef enum logic [2:0] {
	S_IDLE,//000
	S_ENABLE_UART_RX,//001
	S_WAIT_UART_RX,//010
	S_M3,//011
	S_M2,//100
	S_M1//101
} top_state_type;

typedef enum logic [31:0] {
	M1_IDLE,
	LI_0,
	LI_1,
	LI_2,
	LI_3,
	LI_4,
	LI_5,
	LI_6,
	LI_7,
	LI_8,
	LI_9,
	LI_10,
	LI_11,
	LI_12,
	LI_13,
	LI_14,
	LI_15,
	LI_16,
	LI_17,
	LI_18,
	LI_19,
	LI_20,
	LI_21,
	LI_22,	
	CC_0,
	CC_1,
	CC_2,
	CC_3,
	CC_4,
	CC_5,
	CC_6,
	CC_7,
	CC_8,
	CC_9,
	CC_10,
	CC_11,
	LO_0,
	LO_1,
	LO_2,
	LO_3,
	LO_4,
	LO_5,
	LO_6,
	LO_7,
	LO_8,
	LO_9,
	LO_10,
	LO_11,
	LO_12,
	LO_13,
	LO_14,
	LO_15,
	LO_16,
	LO_17,
	LO_18,
	LO_19,
	LO_20,
	LO_21,
	LO_22,
	LO_23,
	LO_24,
	LO_25,
	M1_finish
} M1_state_type;

typedef enum logic [31:0] {
	M2_IDLE,
	M2_IDLE_0,
	M2_IDLE_1,
	LI_Fs_0,
	LI_Fs_1,
	LI_Fs_2,
	LI_Fs_3,
	LI_Ct_0,
	LI_Ct_1,
	LI_Ct_CC_0,
	LI_Ct_CC_1,
	LI_Ct_CC_2,
	LI_Ct_CC_3,
	LI_Ct_LO_0,
	LI_Ct_LO_1,
	LI_Ct_LO_2,
	LI_Ct_LO_3,
	LI_Ct_LO_4,
	LI_Ct_LO_5,
	LI_Ct_LO_6,
	LI_Ct_LO_7,
	CC0_Cs_Fs_0,
	CC0_Cs_Fs_1,
	CC0_Cs_Fs_2,
	CC0_Cs_Fs_3,
	CC0_Cs_Fs_4,
	CC0_Cs_Fs_5,
	CC1_Ct_Ws_0,
	CC1_Ct_Ws_1,
	CC1_Ct_Ws_2,
	CC1_Ct_Ws_3,
	CC1_Ct_Ws_4,
	CC1_Ct_Ws_5,
	CC1_Ct_Ws_6,
	CC1_Ct_Ws_7,
	CC1_Ct_Ws_8,
	CC1_Ct_Ws_9,
	CC1_Ct_Ws_10,
	CC1_Ct_Ws_11,
	LO_Cs_0,
	LO_Cs_1,
	LO_Cs_2,
	LO_Cs_3,
	LO_Ws_0,
	LO_Ws_1,
	LO_Ws_2,
	LO_Ws_3,
	LO_Ws_4,
	LO_Ws_finish

} M2_state_type;

typedef enum logic [10:0] {
	M3_IDLE,
	M3_IDLE_1,
	S_HEADER_1,
	S_HEADER_2,
	S_READ_INITIAL_0,
	S_READ_INITIAL_1,
	S_READ_2BIT,
	S_00,
	S_01,
	S_01_1,
	S_10,
	S_10_0,
	S_10_1,
	S_11,
	S_shift_DETECT,
	S_64_DETECT,
	S_WAIT,
	S_shift_reg,
	S_FINISH
} M3_state_type;

typedef enum logic [1:0] {
	S_RXC_IDLE,
	S_RXC_SYNC,
	S_RXC_ASSEMBLE_DATA,
	S_RXC_STOP_BIT
} RX_Controller_state_type;

typedef enum logic [2:0] {
	S_US_IDLE,
	S_US_STRIP_FILE_HEADER_1,
	S_US_STRIP_FILE_HEADER_2,
	S_US_START_FIRST_BYTE_RECEIVE,
	S_US_WRITE_FIRST_BYTE,
	S_US_START_SECOND_BYTE_RECEIVE,
	S_US_WRITE_SECOND_BYTE
} UART_SRAM_state_type;

typedef enum logic [3:0] {
	S_VS_WAIT_NEW_PIXEL_ROW,
	S_VS_NEW_PIXEL_ROW_DELAY_1,
	S_VS_NEW_PIXEL_ROW_DELAY_2,
	S_VS_NEW_PIXEL_ROW_DELAY_3,
	S_VS_NEW_PIXEL_ROW_DELAY_4,
	S_VS_NEW_PIXEL_ROW_DELAY_5,
	S_VS_FETCH_PIXEL_DATA_0,
	S_VS_FETCH_PIXEL_DATA_1,
	S_VS_FETCH_PIXEL_DATA_2,
	S_VS_FETCH_PIXEL_DATA_3
} VGA_SRAM_state_type;

`define DEFINE_STATE 1
`endif
