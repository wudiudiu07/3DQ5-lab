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
vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET VGA_Controller.v
vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET PB_Controller.v
vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET +define+SIMULATION SRAM_Controller.v
vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET tb_SRAM_Emulator.v
vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET experiment2a.v
vlog -sv -work rtl_work +define+DISABLE_DEFAULT_NET tb_experiment2a.v

# specify library for simulation
vsim -t 100ps -L altera_mf_ver -lib rtl_work tb_experiment2a

# Clear previous simulation
restart -f

view wave

add wave Clock_50

configure wave -signalnamewidth 1

# run complete simulation
run -all

destroy .structure
destroy .signals
destroy .source

simstats
