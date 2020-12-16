# Softshell

Multicore RISC-V MCU for developing software defined peripherals.

## Configuration

### CPU / Private Peripheral Configuration
- 3 x 50 MHz picorv32 cores
- 32 word private "core coupled" memory for stack
- 32-bit private GPIO peripheral
- "flexio" custom instruction (high speed configurable 2/4/8-bit shift register)

### Shared Peripherals
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

## Caravel Top Level Wrapper

The top level wrapper for this project is the Caravel harness.  See
[Caravel Readme](README_caravel.md) for more information.
