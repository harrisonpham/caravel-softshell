// Softshell Top.
//
// SPDX-FileCopyrightText: (c) 2020 Harrison Pham <hp@turtledevices.com>
// SPDX-License-Identifier: Apache-2.0

// Pads:
// io[37:6] - Mapped to 32-bit pinmux (gpios, flexio, uart)
// io[8] - Flash CSB
// io[9] - Flash CLK
// io[10] - Flash DIO0
// io[11] - Flash DIO1
// io[12] - Flash DIO2
// io[13] - Flash DIO3
//
// LA:
// la_data_in[0] - Wishbone reset (also resets CPUs)
// la_data_in[1] - CPU0 reset
// la_data_in[2] - CPU1 reset
// la_data_in[3] - CPU2 reset
// la_data_in[4] - CPU3 reset
//
// la_data_out[31:0] - GPIO out
// la_data_out[63:32] - GPIO in

// `include "third_party/verilog-wishbone/rtl/wb_arbiter_5.v"
// `include "third_party/verilog-wishbone/rtl/arbiter.v"
// `include "third_party/verilog-wishbone/rtl/priority_encoder.v"
// `include "third_party/verilog-wishbone/rtl/wb_mux_3.v"
// `include "third_party/verilog-wishbone/rtl/wb_mux_4.v"
// `include "rv_core.v"
// `include "third_party/picorv32_wb/mem_ff_wb.v"
// `include "third_party/picorv32_wb/simpleuart.v"
// `include "third_party/picorv32_wb/spimemio.v"

// Total shared memory in 32-bit words.
`define SHARED_MEM_WORDS 512

// Number of CPU cores.
// TODO(hdpham): Make this less terrible and dangerous to use.
`define NUM_CPUS 3
`define HAS_CPU3
// `define HAS_CPU4

module softshell_top (
`ifdef USE_POWER_PINS
  inout vdda1,  // User area 1 3.3V supply
  inout vdda2,  // User area 2 3.3V supply
  inout vssa1,  // User area 1 analog ground
  inout vssa2,  // User area 2 analog ground
  inout vccd1,  // User area 1 1.8V supply
  inout vccd2,  // User area 2 1.8v supply
  inout vssd1,  // User area 1 digital ground
  inout vssd2,  // User area 2 digital ground
`endif
  // Wishbone Slave ports (WB MI A)
  input wb_clk_i,
  input wb_rst_i,
  input wbs_stb_i,
  input wbs_cyc_i,
  input wbs_we_i,
  input [3:0] wbs_sel_i,
  input [31:0] wbs_dat_i,
  input [31:0] wbs_adr_i,
  output wbs_ack_o,
  output [31:0] wbs_dat_o,

  // Logic Analyzer Signals
  input  [127:0] la_data_in,
  output [127:0] la_data_out,
  input  [127:0] la_oen,

  // IOs
  input  [`MPRJ_IO_PADS-1:0] io_in,
  output [`MPRJ_IO_PADS-1:0] io_out,
  output [`MPRJ_IO_PADS-1:0] io_oeb
);

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

  // wire clk;
  // wire resetb;
  // assign clk = wb_clk_i;
  // assign resetb = ~wb_rst_i;

  // // Use a GPIO as a clock source just in case clocking through the wrapper
  // // isn't flexible enough. This is pretty nasty, but hopefully with enough
  // // muxing options we'll be okay.
  // // TODO(harrisonpham): Instantiate proper clock buffer / glitchless mux.
  // wire clk_ext;
  // reg clk_muxed;

  // wire [1:0] clk_sel;
  // reg clk_ext_div2;
  // assign clk_sel = la_data_in[1:0];
  // assign clk_ext = io_in[`MPRJ_IO_PADS-1];

  // // Reset is not synchronized! Be careful when releasing reset
  // // (do it after clock is stable).
  // // TODO(harrisonpham): Synchronize reset to clk_muxed domain.
  // wire resetb_muxed;
  // assign resetb_muxed = resetb & la_data_in[2];

  // always @(posedge clk_ext) begin
  //   if (!resetb) begin
  //     clk_ext_div2 <= 1'b0;
  //   end else begin
  //     clk_ext_div2 <= ~clk_ext_div2;
  //   end
  // end

  // always @* begin
  //   case (clk_sel)
  //   2'b00: clk_muxed = clk;
  //   2'b01: clk_muxed = clk_ext;
  //   2'b10: clk_muxed = clk_ext_div2;
  //   2'b11: clk_muxed = 1'b0;
  //   endcase
  // end

  // Async reset generator.
  // Resets from either a wishbone reset or a logic analyzer reset request.
  reg [2:0] reset_pipe;
  wire reset_in;
  wire reset;
  assign reset_in = wb_rst_i | la_data_in[0];
  assign reset = reset_pipe[2];
  always @(posedge wb_clk_i or posedge reset_in) begin
    if (reset_in) begin
      reset_pipe <= 3'b111;
    end else begin
      reset_pipe <= {reset_pipe[1:0], 1'b0};
    end
  end

  // CPU signals.
  wire [31:0] wbm_adr_i [`NUM_CPUS-1:0];
  wire [31:0] wbm_dat_i [`NUM_CPUS-1:0];
  wire [31:0] wbm_dat_o [`NUM_CPUS-1:0];
  wire        wbm_we_i  [`NUM_CPUS-1:0];
  wire [3:0]  wbm_sel_i [`NUM_CPUS-1:0];
  wire        wbm_stb_i [`NUM_CPUS-1:0];
  wire        wbm_ack_o [`NUM_CPUS-1:0];
  wire        wbm_err_o [`NUM_CPUS-1:0];
  wire        wbm_rty_o [`NUM_CPUS-1:0];
  wire        wbm_cyc_i [`NUM_CPUS-1:0];

  wire [31:0] gpio_in  [`NUM_CPUS-1:0];
  wire [31:0] gpio_out [`NUM_CPUS-1:0];
  wire [31:0] gpio_oeb [`NUM_CPUS-1:0];

  wire [7:0]  flexio_in  [`NUM_CPUS-1:0];
  wire [7:0]  flexio_out [`NUM_CPUS-1:0];
  wire [7:0]  flexio_oeb [`NUM_CPUS-1:0];

  wire cpu_reset[`NUM_CPUS-1:0];

  // Generate the CPUs
  genvar i;
  generate
    for (i = 0; i < `NUM_CPUS; i = i + 1) begin : cpus
      assign cpu_reset[i] = la_data_in[i + 1];

      rv_core #(
        // TODO(hdpham): Resize this once the design fits.
        .MEM_WORDS(32),
        // Boot from flash.
        // TODO(hdpham): Should we switch this back to RAM?
        .PROGADDR_RESET(SHARED_FLASH_ADDR | ((i + 1) << 16)),
        .CORE_ID(i)
      ) core (
        .wb_clk_i(wb_clk_i),
        .wb_rst_i(reset | cpu_reset[i]),

        .shared_ack_i(wbm_ack_o[i]),
        .shared_dat_i(wbm_dat_o[i]),
        .shared_cyc_o(wbm_cyc_i[i]),
        .shared_stb_o(wbm_stb_i[i]),
        .shared_we_o(wbm_we_i[i]),
        .shared_sel_o(wbm_sel_i[i]),
        .shared_adr_o(wbm_adr_i[i]),
        .shared_dat_o(wbm_dat_i[i]),

        .gpio_in(gpio_in[i]),
        .gpio_out(gpio_out[i]),
        .gpio_oeb(gpio_oeb[i]),

        .flexio_in(flexio_in[i]),
        .flexio_out(flexio_out[i]),
        .flexio_oeb(flexio_oeb[i])
      );
    end
  endgenerate

  // Shared memory.
  wire [31:0] mem_adr_i;
  wire [31:0] mem_dat_i;
  wire [3:0] mem_sel_i;
  wire mem_we_i;
  wire mem_cyc_i;
  wire mem_stb_i;
  wire mem_ack_o;
  wire [31:0] mem_dat_o;

  mem_ff_wb #(
    .MEM_WORDS(`SHARED_MEM_WORDS)
  ) shared_mem (
    .wb_clk_i(wb_clk_i),
    .wb_rst_i(reset),

    .wb_adr_i(mem_adr_i),
    .wb_dat_i(mem_dat_i),
    .wb_sel_i(mem_sel_i),
    .wb_we_i(mem_we_i),
    .wb_cyc_i(mem_cyc_i),

    .wb_stb_i(mem_stb_i),
    .wb_ack_o(mem_ack_o),
    .wb_dat_o(mem_dat_o)
  );

  // Pinmux.
  wire [31:0] pinmux_adr_i;
  wire [31:0] pinmux_dat_i;
  wire [3:0] pinmux_sel_i;
  wire pinmux_cyc_i;
  wire pinmux_stb_i;
  wire pinmux_we_i;
  wire [31:0] pinmux_dat_o;
  wire pinmux_ack_o;

  wire [31:0] pinmux_gpio_in;
  wire [31:0] pinmux_gpio_out;
  wire [31:0] pinmux_gpio_oeb;

  pinmux #(
    .NUM_INPUTS(1),
    .NUM_OUTPUTS(1 + `NUM_CPUS * 8),
    .NUM_GPIOS(32)
  ) pinmux (
    .wb_clk_i(wb_clk_i),
    .wb_rst_i(reset),

    .wb_adr_i(pinmux_adr_i),
    .wb_dat_i(pinmux_dat_i),
    .wb_sel_i(pinmux_sel_i),
    .wb_cyc_i(pinmux_cyc_i),
    .wb_stb_i(pinmux_stb_i),
    .wb_we_i(pinmux_we_i),

    .wb_dat_o(pinmux_dat_o),
    .wb_ack_o(pinmux_ack_o),

    .gpio_in(pinmux_gpio_in),
    .gpio_out(pinmux_gpio_out),
    .gpio_oeb(pinmux_gpio_oeb),

    .peripheral_in({uart_rx}),
    .peripheral_out({
`ifdef HAS_CPU4
                      flexio_out[3],
`endif
`ifdef HAS_CPU3
                      flexio_out[2],
`endif
                      flexio_out[1],
                      flexio_out[0],
                      uart_tx
                    }),
    .peripheral_oeb({
`ifdef HAS_CPU4
                      flexio_oeb[3],
`endif
`ifdef HAS_CPU3
                      flexio_oeb[2],
`endif
                      flexio_oeb[1],
                      flexio_oeb[0],
                      1'b0
                    })
  );

  // Uarts.
  wire [31:0] uart_adr_i;
  wire [31:0] uart_dat_i;
  wire [3:0] uart_sel_i;
  wire uart_we_i;
  wire uart_cyc_i;
  wire uart_stb_i;
  wire uart_ack_o;
  wire [31:0] uart_dat_o;

  wire uart_enabled;
  wire uart_tx;
  wire uart_rx;

  simpleuart_wb  #(
    .BASE_ADR(UART0_BASE_ADDR)
  ) uart0 (
    .wb_clk_i(wb_clk_i),
    .wb_rst_i(reset),

    .wb_adr_i(uart_adr_i),
    .wb_dat_i(uart_dat_i),
    .wb_sel_i(uart_sel_i),
    .wb_we_i(uart_we_i),
    .wb_cyc_i(uart_cyc_i),

    .wb_stb_i(uart_stb_i),
    .wb_ack_o(uart_ack_o),
    .wb_dat_o(uart_dat_o),

    .uart_enabled(uart_enabled),
    .ser_tx(uart_tx),
    .ser_rx(uart_rx)
  );

  // Flash.
  wire [31:0] flash_adr_i;
  wire [31:0] flash_dat_i;
  wire [3:0] flash_sel_i;
  wire flash_we_i;
  wire flash_cyc_i;
  wire flash_stb_i;
  wire flash_ack_o;
  wire [31:0] flash_dat_o;

  wire flash_cfg_we_i;
  wire flash_cfg_cyc_i;
  wire flash_cfg_stb_i;
  wire flash_cfg_ack_o;
  wire [31:0] flash_cfg_dat_o;

  wire flash_csb_oeb;
  wire flash_clk_oeb;
  wire flash_io0_oeb;
  wire flash_io1_oeb;
  wire flash_io2_oeb;
  wire flash_io3_oeb;
  wire flash_csb;
  wire flash_clk;
  wire flash_io0_do;
  wire flash_io1_do;
  wire flash_io2_do;
  wire flash_io3_do;
  wire flash_io0_di;
  wire flash_io1_di;
  wire flash_io2_di;
  wire flash_io3_di;

  // Mask off the unused upper flash address bits.
  wire [31:0] flash_adr_i_masked;
  assign flash_adr_i_masked = flash_adr_i & ~SHARED_FLASH_MASK;

  spimemio_wb flash (
    .wb_clk_i(wb_clk_i),
    .wb_rst_i(reset),

    .wb_adr_i(flash_adr_i_masked),
    .wb_dat_i(flash_dat_i),
    .wb_sel_i(flash_sel_i),
    .wb_we_i(flash_we_i | flash_cfg_we_i),
    .wb_cyc_i(flash_cyc_i | flash_cfg_cyc_i),

    .wb_flash_stb_i(flash_stb_i),
    .wb_cfg_stb_i(flash_cfg_stb_i),

    .wb_flash_ack_o(flash_ack_o),
    .wb_cfg_ack_o(flash_cfg_ack_o),

    .wb_flash_dat_o(flash_dat_o),
    .wb_cfg_dat_o(flash_cfg_dat_o),

    .pass_thru(1'b0),
    .pass_thru_csb(1'b0),
    .pass_thru_sck(1'b0),
    .pass_thru_sdi(1'b0),
    .pass_thru_sdo(),

    .flash_csb(flash_csb),
    .flash_clk(flash_clk),

    .flash_csb_oeb(flash_csb_oeb),
    .flash_clk_oeb(flash_clk_oeb),

    .flash_io0_oeb(flash_io0_oeb),
    .flash_io1_oeb(flash_io1_oeb),
    .flash_io2_oeb(flash_io2_oeb),
    .flash_io3_oeb(flash_io3_oeb),

    .flash_csb_ieb(),
    .flash_clk_ieb(),

    .flash_io0_ieb(),
    .flash_io1_ieb(),
    .flash_io2_ieb(),
    .flash_io3_ieb(),

    .flash_io0_do(flash_io0_do),
    .flash_io1_do(flash_io1_do),
    .flash_io2_do(flash_io2_do),
    .flash_io3_do(flash_io3_do),

    .flash_io0_di(flash_io0_di),
    .flash_io1_di(flash_io1_di),
    .flash_io2_di(flash_io2_di),
    .flash_io3_di(flash_io3_di)
  );

  // Interconnect bus.
  wire [31:0] mux_adr_i;
  wire [31:0] mux_dat_i;
  wire [3:0] mux_sel_i;
  wire mux_we_i;
  wire mux_cyc_i;
  wire mux_stb_i;
  wire mux_ack_o;
  wire [31:0] mux_dat_o;

  // Filter addresses from Caravel since we want to be absolutely sure it is
  // selecting us before letting it access the arbiter.  This is mostly needed
  // because the wb_intercon.v implementation in Caravel doesn't corrently
  // filter the wb_cyc_i signal to slaves.
  wire wbs_addr_sel;
  assign wbs_addr_sel = (wbs_adr_i & SOFTSHELL_MASK) == SOFTSHELL_ADDR;

  // Round-robin arbiter for shared resources.
`ifdef HAS_CPU4
  wb_arbiter_5 #(
`elsif HAS_CPU3
  wb_arbiter_4 #(
`else
  wb_arbiter_3 #(
`endif
    .ARB_TYPE("ROUND_ROBIN")
  ) arbiter (
    .clk(wb_clk_i),
    .rst(reset),

    .wbm0_adr_i(wbs_adr_i),
    .wbm0_dat_i(wbs_dat_i),
    .wbm0_dat_o(wbs_dat_o),
    .wbm0_we_i(wbs_we_i & wbs_addr_sel),
    .wbm0_sel_i(wbs_sel_i),
    .wbm0_stb_i(wbs_stb_i & wbs_addr_sel),
    .wbm0_ack_o(wbs_ack_o),
    .wbm0_err_o(),
    .wbm0_rty_o(),
    .wbm0_cyc_i(wbs_cyc_i & wbs_addr_sel),

    .wbm1_adr_i(wbm_adr_i[0]),
    .wbm1_dat_i(wbm_dat_i[0]),
    .wbm1_dat_o(wbm_dat_o[0]),
    .wbm1_we_i(wbm_we_i[0]),
    .wbm1_sel_i(wbm_sel_i[0]),
    .wbm1_stb_i(wbm_stb_i[0]),
    .wbm1_ack_o(wbm_ack_o[0]),
    .wbm1_err_o(wbm_err_o[0]),
    .wbm1_rty_o(wbm_rty_o[0]),
    .wbm1_cyc_i(wbm_cyc_i[0]),

    .wbm2_adr_i(wbm_adr_i[1]),
    .wbm2_dat_i(wbm_dat_i[1]),
    .wbm2_dat_o(wbm_dat_o[1]),
    .wbm2_we_i(wbm_we_i[1]),
    .wbm2_sel_i(wbm_sel_i[1]),
    .wbm2_stb_i(wbm_stb_i[1]),
    .wbm2_ack_o(wbm_ack_o[1]),
    .wbm2_err_o(wbm_err_o[1]),
    .wbm2_rty_o(wbm_rty_o[1]),
    .wbm2_cyc_i(wbm_cyc_i[1]),

`ifdef HAS_CPU3
    .wbm3_adr_i(wbm_adr_i[2]),
    .wbm3_dat_i(wbm_dat_i[2]),
    .wbm3_dat_o(wbm_dat_o[2]),
    .wbm3_we_i(wbm_we_i[2]),
    .wbm3_sel_i(wbm_sel_i[2]),
    .wbm3_stb_i(wbm_stb_i[2]),
    .wbm3_ack_o(wbm_ack_o[2]),
    .wbm3_err_o(wbm_err_o[2]),
    .wbm3_rty_o(wbm_rty_o[2]),
    .wbm3_cyc_i(wbm_cyc_i[2]),
`endif

`ifdef HAS_CPU4
    .wbm4_adr_i(wbm_adr_i[3]),
    .wbm4_dat_i(wbm_dat_i[3]),
    .wbm4_dat_o(wbm_dat_o[3]),
    .wbm4_we_i(wbm_we_i[3]),
    .wbm4_sel_i(wbm_sel_i[3]),
    .wbm4_stb_i(wbm_stb_i[3]),
    .wbm4_ack_o(wbm_ack_o[3]),
    .wbm4_err_o(wbm_err_o[3]),
    .wbm4_rty_o(wbm_rty_o[3]),
    .wbm4_cyc_i(wbm_cyc_i[3]),
`endif

    .wbs_adr_o(mux_adr_i),
    .wbs_dat_i(mux_dat_o),
    .wbs_dat_o(mux_dat_i),
    .wbs_we_o(mux_we_i),
    .wbs_sel_o(mux_sel_i),
    .wbs_stb_o(mux_stb_i),
    .wbs_ack_i(mux_ack_o),
    .wbs_err_i(1'b0),
    .wbs_rty_i(1'b0),
    .wbs_cyc_o(mux_cyc_i)
  );

  // Wishbone slave mux for shared memory and peripherals.
  wb_mux_5 interconnect (
    .wbm_adr_i(mux_adr_i),
    .wbm_dat_i(mux_dat_i),
    .wbm_dat_o(mux_dat_o),
    .wbm_we_i(mux_we_i),
    .wbm_sel_i(mux_sel_i),
    .wbm_stb_i(mux_stb_i),
    .wbm_ack_o(mux_ack_o),
    .wbm_err_o(),
    .wbm_rty_o(),
    .wbm_cyc_i(mux_cyc_i),

    .wbs0_adr_o(mem_adr_i),
    .wbs0_dat_i(mem_dat_o),
    .wbs0_dat_o(mem_dat_i),
    .wbs0_we_o(mem_we_i),
    .wbs0_sel_o(mem_sel_i),
    .wbs0_stb_o(mem_stb_i),
    .wbs0_ack_i(mem_ack_o),
    .wbs0_err_i(1'b0),
    .wbs0_rty_i(1'b0),
    .wbs0_cyc_o(mem_cyc_i),
    .wbs0_addr(SHARED_RAM_ADDR),
    .wbs0_addr_msk(SHARED_RAM_MASK),

    .wbs1_adr_o(uart_adr_i),
    .wbs1_dat_i(uart_dat_o),
    .wbs1_dat_o(uart_dat_i),
    .wbs1_we_o(uart_we_i),
    .wbs1_sel_o(uart_sel_i),
    .wbs1_stb_o(uart_stb_i),
    .wbs1_ack_i(uart_ack_o),
    .wbs1_err_i(1'b0),
    .wbs1_rty_i(1'b0),
    .wbs1_cyc_o(uart_cyc_i),
    .wbs1_addr(UART0_BASE_ADDR),
    .wbs1_addr_msk(UART0_ADDR_MASK),

    .wbs2_adr_o(flash_adr_i),
    .wbs2_dat_i(flash_dat_o),
    .wbs2_dat_o(flash_dat_i),
    .wbs2_we_o(flash_we_i),
    .wbs2_sel_o(flash_sel_i),
    .wbs2_stb_o(flash_stb_i),
    .wbs2_ack_i(flash_ack_o),
    .wbs2_err_i(1'b0),
    .wbs2_rty_i(1'b0),
    .wbs2_cyc_o(flash_cyc_i),
    .wbs2_addr(SHARED_FLASH_ADDR),
    .wbs2_addr_msk(SHARED_FLASH_MASK),

    .wbs3_adr_o(),
    .wbs3_dat_i(flash_cfg_dat_o),
    .wbs3_dat_o(),
    .wbs3_we_o(flash_cfg_we_i),
    .wbs3_sel_o(),
    .wbs3_stb_o(flash_cfg_stb_i),
    .wbs3_ack_i(flash_cfg_ack_o),
    .wbs3_err_i(1'b0),
    .wbs3_rty_i(1'b0),
    .wbs3_cyc_o(flash_cfg_cyc_i),
    .wbs3_addr(FLASH_CONFIG_ADDR),
    .wbs3_addr_msk(FLASH_CONFIG_MASK),

    .wbs4_adr_o(pinmux_adr_i),
    .wbs4_dat_i(pinmux_dat_o),
    .wbs4_dat_o(pinmux_dat_i),
    .wbs4_we_o(pinmux_we_i),
    .wbs4_sel_o(pinmux_sel_i),
    .wbs4_stb_o(pinmux_stb_i),
    .wbs4_ack_i(pinmux_ack_o),
    .wbs4_err_i(1'b0),
    .wbs4_rty_i(1'b0),
    .wbs4_cyc_o(pinmux_cyc_i),
    .wbs4_addr(PINMUX_BASE_ADDR),
    .wbs4_addr_msk(PINMUX_ADDR_MASK)
  );

  // Connect up GPIOs.
  wire [31:0] io_in_internal;

  // Internal wires for input ports.
  assign io_in_internal = io_in[37:6];

  assign pinmux_gpio_in = io_in_internal;

  assign gpio_in[0] = io_in_internal;
  assign gpio_in[1] = io_in_internal;
`ifdef HAS_CPU3
  assign gpio_in[2] = io_in_internal;
`endif
`ifdef HAS_CPU4
  assign gpio_in[3] = io_in_internal;
`endif
  // assign uart_rx = io_in_internal[24];

  assign flash_io0_di = io_in_internal[10-6];
  assign flash_io1_di = io_in_internal[11-6];
  assign flash_io2_di = io_in_internal[12-6];
  assign flash_io3_di = io_in_internal[13-6];

  assign io_out[5:0] = 6'b0;
  assign io_oeb[5:0] = {6{1'b1}};

  // TODO(hdpham): Add ability to disable or mux flash pins.
  // TODO(hdpham): Add pin mux to remap UART and other peripheral pins.

  // Internal wires for output ports to workaround LVS errors.
  wire [31:0] io_out_internal;
  wire [31:0] io_oeb_internal;

  assign io_out_internal = gpio_out[0] |
                           gpio_out[1] |
`ifdef HAS_CPU3
                           gpio_out[2] |
`endif
`ifdef HAS_CPU4
                           gpio_out[3] |
`endif
                           {24'b0, flash_io3_do, flash_io2_do,
                            flash_io1_do, flash_io0_do, flash_clk,
                            flash_csb, 2'b0} |
                           pinmux_gpio_out;
                           //{6'b0, uart_tx, 25'b0};
  assign io_oeb_internal = gpio_oeb[0] &
                           gpio_oeb[1] &
`ifdef HAS_CPU3
                           gpio_oeb[2] &
`endif
`ifdef HAS_CPU4
                           gpio_oeb[3] &
`endif
                           {{24{1'b1}}, flash_io3_oeb, flash_io2_oeb,
                            flash_io1_oeb, flash_io0_oeb, flash_clk_oeb,
                            flash_csb_oeb, 2'b11} &
                           pinmux_gpio_oeb;
                           //~{6'b0, uart_enabled, 25'b0};

  wire [31:0] io_out_internal_buf;
  wire [31:0] io_oeb_internal_buf;

//   // Hack to manually insert buffer so LVS is happy.
//   // TODO(hdpham): Wrap this to make non-technology specific.
//   generate
//     for (i = 0; i < 32; i = i + 1) begin
//       sky130_fd_sc_hd__buf_8 out_buf (
// `ifdef SIM
//         // TODO(hdpham): Figure out why the behavioral models don't work.
//         .VPWR(1'b1),
//         .VGND(1'b0),
//         .VPB(1'b1),
//         .VNB(1'b0),
// `endif
//         .X(io_out_internal_buf[i]),
//         .A(io_out_internal[i])
//       );

//       sky130_fd_sc_hd__buf_8 oeb_buf (
// `ifdef SIM
//         .VPWR(1'b1),
//         .VGND(1'b0),
//         .VPB(1'b1),
//         .VNB(1'b0),
// `endif
//         .X(io_oeb_internal_buf[i]),
//         .A(io_oeb_internal[i])
//       );
//     end
//   endgenerate

  assign io_out_internal_buf = io_out_internal;
  assign io_oeb_internal_buf = io_oeb_internal;

  assign io_out[37:6] = io_out_internal_buf;
  assign io_oeb[37:6] = io_oeb_internal_buf;

  assign la_data_out[31:0] = io_out_internal_buf;
  assign la_data_out[63:32] = io_oeb_internal_buf;

  // Tieoff unused.
  // TODO(hdpham): Tie this to useful things.
  assign la_data_out[127:64] = 64'b0;

endmodule // module softshell_top
