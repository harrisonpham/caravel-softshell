# Softshell

Multicore RISC-V MCU for developing software defined peripherals.  This design
is targetted for the first Google-sponsored MPW shuttle Nov/Dec 2020.

## Configuration

### CPU / Private Peripheral Configuration
- 3 x 50 MHz picorv32 cores
- 32 word private "core coupled" memory for stack
- 32-bit private GPIO peripheral
- "flexio" custom instruction (high speed configurable 2/4/8-bit shift register)

### Shared Peripherals
- Round-robin arbiter
- 512 word (2KB) shared memory
- XIP QSPI flash controller
- UART
- Pinmux crossbar

## Memory Map

### CPU Private
```
// Local memory (for stack, etc).
parameter CCM_ADDR_MASK     = 32'hffff_0000;
parameter CCM_BASE_ADDR     = 32'h0000_0000;

// Local GPIO peripheral.
parameter GPIO_ADDR_MASK    = 32'hffff_0000;
parameter GPIO_BASE_ADDR    = 32'h2000_0000;

// Access to the shared peripheral space.
parameter SHARED_ADDR_MASK  = 32'hff00_0000;
parameter SHARED_BASE_ADDR  = 32'h3000_0000;
```

### Shared
```
// Softshell base address (used for filtering addresses from Caravel).
parameter SOFTSHELL_MASK    = 32'hff00_0000;
parameter SOFTSHELL_ADDR    = 32'h3000_0000;

// Slave base addresses.
parameter SHARED_RAM_MASK   = 32'hfff0_0000;
parameter SHARED_RAM_ADDR   = 32'h3000_0000;

parameter SHARED_FLASH_MASK = 32'hfff0_0000;
parameter SHARED_FLASH_ADDR = 32'h3040_0000;

parameter FLASH_CONFIG_MASK = 32'hffff_0000;
parameter FLASH_CONFIG_ADDR = 32'h3080_0000;
parameter PINMUX_ADDR_MASK  = 32'hffff_0000;
parameter PINMUX_BASE_ADDR  = 32'h3081_0000;
parameter UART0_ADDR_MASK   = 32'hffff_0000;
parameter UART0_BASE_ADDR   = 32'h3082_0000;
```

## Pins and Debug

```
User IOs
--------
io[37:6] - Mapped to 32-bit pinmux (gpios, flexio, uart)
io[8] - Flash CSB       (muxable to Caravel passthru for programming)
io[9] - Flash CLK       (muxable to Caravel passthru for programming)
io[10] - Flash DIO0     (muxable to Caravel passthru for programming)
io[11] - Flash DIO1     (muxable to Caravel passthru for programming)
io[12] - Flash DIO2
io[13] - Flash DIO3

Wishbone Access from Caravel
----------------------------
Access to entire shared memory space (RAM, XIP Flash, etc)

Debug from Caravel
------------------
la_data_in[0] - Wishbone reset (also resets CPUs)
la_data_in[1] - CPU0 reset
la_data_in[2] - CPU1 reset
la_data_in[3] - CPU2 reset (if implemented)
la_data_in[4] - CPU3 reset (if implemented)

la_data_out[31:0] - GPIO out
la_data_out[63:32] - GPIO in

Note: CPU resets are not synchronized while the wishbone reset is.
```

## Verification

The `softshell_top` and `user_proj_example` modules are verified using the
same testbench.

It performs these basic tests:
- Memory read/write tests from Caravel SoC wishbone interface.
- Memory tests from Softshell CPU 0.
- GPIO in / out tests from Softshell CPU 0.
- Flexio tests.
- Flash XIP execution.

Testing execution from each CPU is a manual process requiring manually editing
the linker script, flash memory load address, and which CPU is released from
reset in the test bench.  Not holding unused CPUs in reset will cause the X's
to propagate everywhere in GL sims.

1. Build the picorv32 toolchain and install at `/opt/riscv32ic/bin`.  We only
   need the `riscv32ic` mach.
2. Configure `PDK_ROOT`.
3. Run the testbench.
    ```
    # For behavioral sims.
    cd verilog/rtl/softshell/dv && make clean; make

    # For GL (this will take a long time).
    cd verilog/rtl/softshell/dv && make clean; make GL=1
    ```

There are plans to do a full top level Caravel testbench soon.

## Building

Due to the limited timeline, this design is built with two different versions
of openlane / PDKs.  You'll need to have both `mpw-one-a` and `mpw-one-b`
available on your machine to do a full build.  Note that `mpw-one-a` corresponds
to `OPENLANE_TAG=rc5`.

### Softshell `user_proj_example` and Wrapper `user_project_wrapper` Macros

Requires `mpw-one-a` openlane and PDK.  To make the routing work harder, it's
preferred to edit the openlane `tritonRoute.param` file and add
`drouteEndIterNum:${ROUTING_OPT_ITERS}` which we later set to try harder during
wrapper routing.

1. Configure `OPENLANE_ROOT` and `PDK_ROOT` to point to `mpw-one-a` versions.
2. Harden the macro, this will take 8 - 12 hours on a modern 12 core machine.
    ```
    cd openlane && make user_proj_example OPENLANE_TAG=rc5
    ```
3. Review the `final_summary_report.csv` file.  Expect LVS errors only on the
   output pins of the macro (pin mismatches) and a few antenna violations.
   There should be zero DRC errors, if you get some you will need to rerun to
   get a different seed (or manually edit the GDS).  Manually review the
   log files to confirm that the antenna ratios are reasonable and that any LVS
   errors are safe (pin mismatches are generally safe, compare the GL netlist
   and spice extracted netlist to confirm).
3. Copy the results from the run folder into the appropriate locations.  This is
   done primarily so it's easy to switch between run snapshots to compare.
    ```
    cd openlane/user_proj_example && ./copy_results.sh runs/<result tag>
    ```
4. Harden the wrapper macro.
    ```
    cd openlane && make user_project_wrapper OPENLANE_TAG=rc5
    ```
5. Review the `final_summary_report.csv` file to confirm 0 DRC/LVS/antenna
   violations.

### Top Level Caravel

Requires `mpw-one-b` openlane and PDK.  Probably not strictly necessary but
safest to use what eFabless will use.

1. Configure `OPENLANE_ROOT` and `PDK_ROOT` to point to `mpw-one-b` versions.
2. Extract and build the final caravel gds.
    ```
    make uncompress && make ship
    ```
3. Check results, and recompress.  This will take a while since we use `xz`
   compression.
    ```
    make compress
    ```

## Caravel Top Level Wrapper Details

The top level wrapper for this project is the Caravel harness.  See
[Caravel Readme](README_caravel.md) for more information.
