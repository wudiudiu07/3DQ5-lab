

# add waves to waveform
#add wave uut/SRAM_we_n
#add wave -decimal uut/SRAM_read_data
#add wave -unsigned uut/SRAM_address


add wave Clock_50
add wave -divider {some label for my divider}
add wave -octal uut/SRAM_write_data
add wave uut/M2_unit/M2_state
add wave uut/M2_enable
add wave uut/M2_done

add wave uut/M2_unit/SRAM_we_n
add wave -unsigned uut/M2_unit/SRAM_write_data
add wave -hexadecimal uut/M2_unit/SRAM_read_data
add wave -unsigned uut/M2_unit/SRAM_address
add wave -unsigned uut/M2_unit/address_0
add wave -unsigned uut/M2_unit/address_1
add wave -unsigned uut/M2_unit/address_2
add wave -unsigned uut/M2_unit/address_3
#add wave -unsigned uut/M2_unit/flag_ws
add wave -hexadecimal uut/M2_unit/write_data_b
add wave -unsigned uut/M2_unit/write_enable_b
add wave -unsigned uut/M2_unit/memory_sel
add wave -unsigned uut/M2_unit/seg_offset
add wave -unsigned uut/M2_unit/write_offset

#add wave -unsigned uut/M2_unit/read_data_a
#add wave -unsigned uut/M2_unit/read_data_b

add wave -unsigned uut/M2_unit/row_index
add wave -unsigned uut/M2_unit/col_index
#add wave -unsigned uut/M2_unit/address_counter
#add wave -unsigned uut/M2_unit/flag_ws

add wave -hexadecimal uut/M2_unit/Y_prime_reg
#add wave -unsigned uut/M2_unit/memory_offset
#add wave -unsigned uut/M2_unit/write_offset
#add wave -unsigned uut/M2_unit/row_address
#add wave -unsigned uut/M2_unit/col_address


#add wave -unsigned uut/M2_unit/c_index_0
#add wave -unsigned uut/M2_unit/c_index_1
#add wave -decimal uut/M2_unit/op0
#add wave -decimal uut/M2_unit/op1
#add wave -decimal uut/M2_unit/C0
#add wave -decimal uut/M2_unit/C1
#add wave -unsigned uut/M2_unit/T


add wave -unsigned uut/M2_unit/block_col_index
add wave -unsigned uut/M2_unit/block_row_index
add wave -unsigned uut/M2_unit/max_col_index

add wave -decimal uut/M2_unit/Y_out_0
add wave -decimal uut/M2_unit/Y_out_1









