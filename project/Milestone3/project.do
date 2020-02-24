onbreak {resume}
transcript on

set PrefMain(saveLines) 50000
.main clear

if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

# load designs

# insert files specific to your design here

vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET convert_hex_to_seven_segment.v
vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET VGA_Controller.v
vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET PB_Controller.v
vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET +define+SIMULATION SRAM_Controller.v
vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET tb_SRAM_Emulator.v
vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET +define+SIMULATION UART_Receive_Controller.v
vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET VGA_SRAM_interface.v
vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET UART_SRAM_interface.v
vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET Clock_100_PLL.v
vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET project.v
vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET M1_interface.v
vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET M2_interface.v
vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET M3_interface.v
vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET dual_port_RAM1.v
vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET dual_port_RAM0.v
# vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET tb_project.v
vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET tb_project_v2.v

# specify library for simulation
# vsim -t 100ps -L altera_mf_ver -lib rtl_work tb_project
vsim -t 100ps -L altera_mf_ver -lib rtl_work tb_project_v2

# Clear previous simulation
restart -f

# activate waveform simulation
view wave

# add waveforms
# workaround for no block comments: call another .do file, or as many as you like
# or just add the waveforms here like done the labs
do add_my_waveforms.do
#do add_some_more_waveforms.do

# format signal names in waveform
configure wave -signalnamewidth 1

# run complete simulation
run -all

destroy .structure
destroy .signals
destroy .source

simstats
