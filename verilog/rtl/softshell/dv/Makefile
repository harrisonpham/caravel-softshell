.SUFFIXES:

PATTERN = softshell_top

FIRMWARE_PATH = .

GCC_PATH ?= /opt/riscv32ic/bin
GCC_PREFIX ?= riscv32-unknown-elf

SIM_FLAGS ?= -DSIM -DFUNCTIONAL -DUSE_POWER_PINS
ifdef GL
	SIM_FLAGS += -DGL
endif

all:  ${PATTERN:=.fst}

%.vvp: %_tb.v firmware.hex
	iverilog -I $(PDK_ROOT)/sky130A -I ../rtl -I .. \
	$(SIM_FLAGS) \
	$< -o $@

%.fst: %.vvp
	vvp $< -fst

%.elf: %.c $(FIRMWARE_PATH)/sections_cpu0.lds $(FIRMWARE_PATH)/start.s
	${GCC_PATH}/${GCC_PREFIX}-gcc -march=rv32ic -mabi=ilp32 \
	-Wl,-Bstatic,-T,$(FIRMWARE_PATH)/sections_cpu0.lds,--strip-debug \
	-ffreestanding -nostdlib -o $@ $(FIRMWARE_PATH)/start.s $<

%.hex: %.elf
	${GCC_PATH}/${GCC_PREFIX}-objcopy -O verilog $< $@
	sed -i 's/@304/@000/g' $@

firmware.hex: $(PATTERN).hex
	ln -s $< firmware.hex

clean:
	rm -f *.vvp *.vcd *.fst *.log *.hex *.bin *.elf

.PHONY: clean all
