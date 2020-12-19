
lef read /mnt/data/workspace/pdk/sky130A/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd.tlef
if {  [info exist ::env(EXTRA_LEFS)] } {
	set lefs_in $::env(EXTRA_LEFS)
	foreach lef_file $lefs_in {
		lef read $lef_file
	}
}
def read /project/openlane/user_proj_example/runs/16-12_10-43/results/routing/user_proj_example.def
load user_proj_example -dereference
cd /project/openlane/user_proj_example/runs/16-12_10-43/results/magic/
extract do local
extract no capacitance
extract no coupling
extract no resistance
extract no adjust
# extract warn all
extract

ext2spice lvs
ext2spice user_proj_example.ext
feedback save /project/openlane/user_proj_example/runs/16-12_10-43/logs/magic/magic_ext2spice.feedback.txt
# exec cp user_proj_example.spice /project/openlane/user_proj_example/runs/16-12_10-43/results/magic/user_proj_example.spice

