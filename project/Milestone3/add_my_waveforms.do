

# add waves to waveform
#add wave uut/SRAM_we_n
#add wave -decimal uut/SRAM_read_data
#add wave -unsigned uut/SRAM_address


add wave Clock_50
add wave -divider {some label for my divider}
add wave -octal uut/SRAM_write_data
add wave uut/M3_unit/M3_state
add wave uut/M3_enable

add wave uut/M3_unit/SRAM_we_n
add wave -unsigned uut/M3_unit/SRAM_write_data
add wave -binary uut/M3_unit/SRAM_read_data
add wave -unsigned uut/M3_unit/SRAM_address
add wave -unsigned uut/M3_unit/read_address
#dd wave -unsigned uut/M3_unit/SRAM_we_n
#add wave -unsigned uut/M3_unit/SRAM_write_data
add wave -unsigned uut/M3_unit/row_address
add wave -unsigned uut/M3_unit/col_address
add wave -unsigned uut/M3_unit/memory_offset
add wave -unsigned uut/M3_unit/row_index
add wave -unsigned uut/M3_unit/row_index_extended
add wave -unsigned uut/M3_unit/col_index
add wave -unsigned uut/M3_unit/we_counter
add wave -unsigned uut/M3_unit/write_offset
add wave -unsigned uut/M3_unit/read_block_offset
add wave -unsigned uut/M3_unit/q
add wave -unsigned uut/M3_unit/base_we_counter
add wave -unsigned uut/M3_unit/base_address
add wave -binary uut/M3_unit/shift_reg
add wave -unsigned uut/M3_unit/shift_counter
add wave -unsigned uut/M3_unit/header_counter
add wave -unsigned uut/M3_unit/MULTI_IDCT2
add wave -unsigned uut/M3_unit/MULTI_IDCT1
add wave -unsigned uut/M3_unit/MULTI_IDCT0
add wave -unsigned uut/M3_unit/bit_shift_unit

add wave -unsigned uut/M3_unit/zero_counter
#add wave -signed uut/M3_unit/direction
add wave -unsigned uut/M3_unit/memory_sel
add wave -unsigned uut/M3_unit/block_col_index
add wave -unsigned uut/M3_unit/block_row_index















