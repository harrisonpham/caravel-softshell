/*
 *  PicoSoC - A simple example SoC using PicoRV32
 *
 *  Copyright (C) 2017  Clifford Wolf <clifford@clifford.at>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *  Revision 1,  July 2019:  Added signals to drive flash_clk and flash_csb
 *  output enable (inverted), tied to reset so that the flash is completely
 *  isolated from the processor when the processor is in reset.
 *
 *  Also: Made ram_wenb a 4-bit bus so that the memory access can be made
 *  byte-wide for byte-wide instructions.
 */

`ifdef PICORV32_V
`error "rv_core.v must be read before picorv32.v!"
`endif

`define PICORV32_REGS mgmt_soc_regs

// `include "third_party/picorv32_wb/picorv32.v"
// `include "third_party/picorv32_wb/gpio32_wb.v"

module rv_core #(
  // Size of memory in 32-bit words.
  parameter MEM_WORDS = 256,
  // Reset PC for CPU, address in shared memory.
  parameter PROGADDR_RESET = 32'h1000_0000,
  parameter CORE_ID = 0
)(
  // Core clock and resets.
  input wb_clk_i,
  input wb_rst_i,

  // WB Master (to shared peripherals)
  input shared_ack_i,
  input [31:0] shared_dat_i,
  output shared_cyc_o,
  output shared_stb_o,
  output shared_we_o,
  output [3:0] shared_sel_o,
  output [31:0] shared_adr_o,
  output [31:0] shared_dat_o,

  input [31:0]  gpio_in,
  output [31:0] gpio_out,
  output [31:0] gpio_oeb,

  input [7:0]   flexio_in,
  output [7:0]  flexio_out,
  output [7:0]  flexio_oeb
);

  // Stack base address, mapped to end of private CCM.
  parameter [31:0] STACKADDR = (4*(MEM_WORDS));
  // IRQ handler start address, mapped to private CCM.
  parameter [31:0] PROGADDR_IRQ = 32'h0000_0000;

  // Slave base addresses.
  parameter CCM_ADDR_MASK     = 32'hffff_0000;
  parameter CCM_BASE_ADDR     = 32'h0000_0000;

  parameter GPIO_ADDR_MASK    = 32'hffff_0000;
  parameter GPIO_BASE_ADDR    = 32'h2000_0000;

  parameter SHARED_ADDR_MASK  = 32'hff00_0000;
  parameter SHARED_BASE_ADDR  = 32'h3000_0000;

  // Flex IO custom instruction.
  wire pcpi_valid;
  wire [31:0] pcpi_insn;
  wire [31:0] pcpi_rs1;
  wire [31:0] pcpi_rs2;
  wire pcpi_wr;
  wire [31:0] pcpi_rd;
  wire pcpi_wait;
  wire pcpi_ready;

  pcpi_flexio flexio (
    .clk(wb_clk_i),
    .resetb(~wb_rst_i),
    .pcpi_valid(pcpi_valid),
    .pcpi_insn(pcpi_insn),
    .pcpi_rs1(pcpi_rs1),
    .pcpi_rs2(pcpi_rs2),
    .pcpi_wr(pcpi_wr),
    .pcpi_rd(pcpi_rd),
    .pcpi_wait(pcpi_wait),
    .pcpi_ready(pcpi_ready),

    .flexio_clk(wb_clk_i),
    .flexio_resetb(~wb_rst_i),
    .flexio_in(flexio_in),
    .flexio_out(flexio_out),
    .flexio_oeb(flexio_oeb)
  );

  // Wishbone internal master bus.
  wire [31:0] cpu_adr_o;
  wire [31:0] cpu_dat_i;
  wire [3:0] cpu_sel_o;
  wire cpu_we_o;
  wire cpu_cyc_o;
  wire cpu_stb_o;
  wire [31:0] cpu_dat_o;
  wire cpu_ack_i;
  wire mem_instr;

  // Extra CPU signals.
  wire trap;
  wire [31:0] irq;

  assign irq = 32'b0;

  picorv32_wb #(
    .STACKADDR(STACKADDR),
    .PROGADDR_RESET(PROGADDR_RESET),
    .PROGADDR_IRQ(PROGADDR_IRQ),
    .BARREL_SHIFTER(1),
    .COMPRESSED_ISA(1),
    .ENABLE_MUL(0),
    .ENABLE_DIV(0),
    .ENABLE_IRQ(1),
    .ENABLE_IRQ_QREGS(0),
    .ENABLE_COUNTERS64(0),
    .ENABLE_PCPI(1)
  ) cpu (
    .wb_clk_i(wb_clk_i),
    .wb_rst_i(wb_rst_i),
    .trap(trap),
    .irq(irq),
    .mem_instr(mem_instr),
    .wbm_adr_o(cpu_adr_o),
    .wbm_dat_i(cpu_dat_i),
    .wbm_stb_o(cpu_stb_o),
    .wbm_ack_i(cpu_ack_i),
    .wbm_cyc_o(cpu_cyc_o),
    .wbm_dat_o(cpu_dat_o),
    .wbm_we_o(cpu_we_o),
    .wbm_sel_o(cpu_sel_o),

    .pcpi_valid(pcpi_valid),
    .pcpi_insn(pcpi_insn),
    .pcpi_rs1(pcpi_rs1),
    .pcpi_rs2(pcpi_rs2),
    .pcpi_wr(pcpi_wr),
    .pcpi_rd(pcpi_rd),
    .pcpi_wait(pcpi_wait),
    .pcpi_ready(pcpi_ready)
  );

  // Wishbone CCM slave.
  wire [31:0] mem_adr_i;
  wire [31:0] mem_dat_i;
  wire [3:0]  mem_sel_i;
  wire mem_we_i;
  wire mem_cyc_i;
  wire mem_stb_i;
  wire mem_ack_o;
  wire [31:0] mem_dat_o;

  mem_ff_wb #(
    .MEM_WORDS(MEM_WORDS)
  ) soc_mem (
    .wb_clk_i(wb_clk_i),
    .wb_rst_i(wb_rst_i),

    .wb_adr_i(mem_adr_i),
    .wb_dat_i(mem_dat_i),
    .wb_sel_i(mem_sel_i),
    .wb_we_i(mem_we_i),
    .wb_cyc_i(mem_cyc_i),

    .wb_stb_i(mem_stb_i),
    .wb_ack_o(mem_ack_o),
    .wb_dat_o(mem_dat_o)
  );

  // Wishbone GPIO slave.
  wire [31:0] gpio_adr_i;
  wire [31:0] gpio_dat_i;
  wire [3:0]  gpio_sel_i;
  wire gpio_we_i;
  wire gpio_cyc_i;
  wire gpio_stb_i;
  wire gpio_ack_o;
  wire [31:0] gpio_dat_o;

  gpio32_wb gpio (
    .wb_clk_i(wb_clk_i),
    .wb_rst_i(wb_rst_i),
    .wb_adr_i(gpio_adr_i),
    .wb_dat_i(gpio_dat_i),
    .wb_sel_i(gpio_sel_i),
    .wb_we_i(gpio_we_i),
    .wb_cyc_i(gpio_cyc_i),
    .wb_stb_i(gpio_stb_i),
    .wb_ack_o(gpio_ack_o),
    .wb_dat_o(gpio_dat_o),
    .gpio_in(gpio_in),
    .gpio_out(gpio_out),
    .gpio_oeb(gpio_oeb)
  );

  // Wishbone interconnect.
  wb_mux_3 interconnect (
    .wbm_adr_i(cpu_adr_o),
    .wbm_dat_i(cpu_dat_o),
    .wbm_dat_o(cpu_dat_i),
    .wbm_we_i(cpu_we_o),
    .wbm_sel_i(cpu_sel_o),
    .wbm_stb_i(cpu_stb_o),
    .wbm_ack_o(cpu_ack_i),
    .wbm_err_o(),
    .wbm_rty_o(),
    .wbm_cyc_i(cpu_cyc_o),

    .wbs0_adr_o(shared_adr_o),
    .wbs0_dat_i(shared_dat_i),
    .wbs0_dat_o(shared_dat_o),
    .wbs0_we_o(shared_we_o),
    .wbs0_sel_o(shared_sel_o),
    .wbs0_stb_o(shared_stb_o),
    .wbs0_ack_i(shared_ack_i),
    .wbs0_err_i(),
    .wbs0_rty_i(),
    .wbs0_cyc_o(shared_cyc_o),
    .wbs0_addr(SHARED_BASE_ADDR),
    .wbs0_addr_msk(SHARED_ADDR_MASK),

    .wbs1_adr_o(mem_adr_i),
    .wbs1_dat_i(mem_dat_o),
    .wbs1_dat_o(mem_dat_i),
    .wbs1_we_o(mem_we_i),
    .wbs1_sel_o(mem_sel_i),
    .wbs1_stb_o(mem_stb_i),
    .wbs1_ack_i(mem_ack_o),
    .wbs1_err_i(),
    .wbs1_rty_i(),
    .wbs1_cyc_o(mem_cyc_i),
    .wbs1_addr(CCM_BASE_ADDR),
    .wbs1_addr_msk(CCM_ADDR_MASK),

    .wbs2_adr_o(gpio_adr_i),
    .wbs2_dat_i(gpio_dat_o),
    .wbs2_dat_o(gpio_dat_i),
    .wbs2_we_o(gpio_we_i),
    .wbs2_sel_o(gpio_sel_i),
    .wbs2_stb_o(gpio_stb_i),
    .wbs2_ack_i(gpio_ack_o),
    .wbs2_err_i(),
    .wbs2_rty_i(),
    .wbs2_cyc_o(gpio_cyc_i),
    .wbs2_addr(GPIO_BASE_ADDR),
    .wbs2_addr_msk(GPIO_ADDR_MASK)
  );

endmodule // module rv_core

// Implementation note:
// Replace the following two modules with wrappers for your SRAM cells.

module mgmt_soc_regs (
  input clk, wen,
  input [5:0] waddr,
  input [5:0] raddr1,
  input [5:0] raddr2,
  input [31:0] wdata,
  output [31:0] rdata1,
  output [31:0] rdata2
);
  reg [31:0] regs [0:31];

  always @(posedge clk)
    if (wen) regs[waddr[4:0]] <= wdata;

  assign rdata1 = regs[raddr1[4:0]];
  assign rdata2 = regs[raddr2[4:0]];
endmodule
