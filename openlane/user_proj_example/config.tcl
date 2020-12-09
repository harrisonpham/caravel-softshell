set script_dir [file dirname [file normalize [info script]]]

set ::env(DESIGN_NAME) user_proj_example

set ::env(VERILOG_FILES) "\
	$script_dir/../../verilog/rtl/defines.v \
	$script_dir/../../verilog/rtl/user_proj_example.v \
	$script_dir/../../softshell/rtl/softshell_top.v \
	$script_dir/../../softshell/rtl/rv_core.v \
	$script_dir/../../softshell/third_party/verilog-wishbone/rtl/wb_arbiter_5.v \
	$script_dir/../../softshell/third_party/verilog-wishbone/rtl/arbiter.v \
	$script_dir/../../softshell/third_party/verilog-wishbone/rtl/priority_encoder.v \
	$script_dir/../../softshell/third_party/verilog-wishbone/rtl/wb_mux_3.v \
	$script_dir/../../softshell/third_party/verilog-wishbone/rtl/wb_mux_4.v \
	$script_dir/../../softshell/third_party/picorv32_wb/mem_ff_wb.v \
	$script_dir/../../softshell/third_party/picorv32_wb/simpleuart.v \
	$script_dir/../../softshell/third_party/picorv32_wb/spimemio.v \
	$script_dir/../../softshell/third_party/picorv32_wb/gpio32_wb.v \
	$script_dir/../../softshell/third_party/picorv32_wb/picorv32.v"

#set ::env(VERILOG_INCLUDE_DIRS) "\
#	$script_dir/../../softshell"

set ::env(CLOCK_PORT) "wb_clk_i"
#set ::env(CLOCK_NET) "softshell.wb_clk_i"
set ::env(CLOCK_PERIOD) "20"

set ::env(FP_SIZING) absolute
set ::env(DIE_AREA) "0 0 2400 3000"
set ::env(DESIGN_IS_CORE) 0
set ::env(FP_PDN_CORE_RING) 0

#set ::env(GLB_RT_ALLOW_CONGESTION) 1
set ::env(GLB_RT_MAXLAYER) 5

set ::env(PL_TARGET_DENSITY) 0.45

# Diodes inserted using interactive.tcl.
set ::env(DIODE_INSERTION_STRATEGY) 0

set ::env(ROUTING_CORES) 6

set ::env(FP_PIN_ORDER_CFG) $script_dir/pin_order.cfg
# set ::env(FP_CONTEXT_DEF) $script_dir/../user_project_wrapper/runs/user_project_wrapper/tmp/floorplan/ioPlacer.def.macro_placement.def
# set ::env(FP_CONTEXT_LEF) $script_dir/../user_project_wrapper/runs/user_project_wrapper/tmp/merged_unpadded.lef
