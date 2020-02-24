onbreak {resume}

transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

# load designs
vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET SRAM_BIST.v
vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET +define+SIMULATION SRAM_Controller.v
vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET tb_SRAM_Emulator.v
vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET experiment4.v
vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET tb_experiment4.v

# specify library for simulation
vsim -t 100ps -L altera_mf_ver -lib rtl_work tb_experiment4

# Clear previous simulation
restart -f

# activate waveform simulation
view wave

# add signals to waveform
add wave Clock_50

add wave uut/BIST_unit/BIST_state
add wave -unsigned uut/BIST_unit/BIST_address
add wave -hex uut/BIST_unit/BIST_write_data
add wave -hex uut/BIST_unit/BIST_we_n
add wave -hex uut/BIST_unit/BIST_read_data
add wave -hex uut/BIST_unit/BIST_expected_data
add wave uut/BIST_unit/BIST_finish
add wave uut/BIST_unit/BIST_mismatch

# Added two additional signal for simulation
add wave uut/BIST_unit/BIST_flag
add wave uut/BIST_unit/BIST_start

# format signal names in waveform
configure wave -signalnamewidth 1

# run complete simulation
run -all

simstats
