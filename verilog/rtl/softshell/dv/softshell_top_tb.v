`timescale 1 ns / 1 ps

`define MPRJ_IO_PADS 38
`define MPRJ_PWR_PADS 4		/* vdda1, vccd1, vdda2, vccd2 */
// `define USE_CUSTOM_DFFRAM
`define USE_OPENRAM
`define MEM_WORDS 256
`define COLS 1

// Models.
// `include "third_party/sky130/models/sram_1rw1r_32_256_8_sky130.v"
// `include "third_party/DFFRAM/models/DFFRAMBB.v"
// `include "third_party/DFFRAM/models/DFFRAM.v"
`include "third_party/picorv32/picosoc/spiflash.v"

// Gatelevel models.
//`ifdef GL
  `include "libs.ref/sky130_fd_sc_hd/verilog/primitives.v"
  `include "libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v"
  // `include "libs.ref/sky130_fd_sc_hvl/verilog/primitives.v"
  // `include "libs.ref/sky130_fd_sc_hvl/verilog/sky130_fd_sc_hvl.v"
//`endif

// Design.
`ifdef GL
  `include "../../../gl/user_proj_example.v"
`else
  `include "softshell_top.v"
  `include "rv_core.v"
  `include "pinmux.v"
  `include "pcpi_flexio.v"
  `include "third_party/verilog-wishbone/rtl/wb_arbiter_3.v"
  `include "third_party/verilog-wishbone/rtl/wb_arbiter_4.v"
  `include "third_party/verilog-wishbone/rtl/wb_arbiter_5.v"
  `include "third_party/verilog-wishbone/rtl/arbiter.v"
  `include "third_party/verilog-wishbone/rtl/priority_encoder.v"
  `include "third_party/verilog-wishbone/rtl/wb_mux_3.v"
  `include "third_party/verilog-wishbone/rtl/wb_mux_5.v"
  `include "third_party/picorv32_wb/mem_ff_wb.v"
  `include "third_party/picorv32_wb/simpleuart.v"
  `include "third_party/picorv32_wb/spimemio.v"
  `include "third_party/picorv32_wb/picorv32.v"
  `include "third_party/picorv32_wb/gpio32_wb.v"
  `include "third_party/wb2axip/rtl/afifo.v"
`endif

module softshell_top_tb;
  reg clk;
  reg resetb;

  wire wb_clk_i;
  wire wb_rst_i;
  reg wb_stb_i;
  reg wb_cyc_i;
  reg wb_we_i;
  reg [3:0] wb_sel_i;
  reg [31:0] wb_dat_i;
  reg [31:0] wb_adr_i;
  wire wb_ack_o;
  wire [31:0] wb_dat_o;

  reg  [127:0] la_data_in;
  wire [127:0] la_data_out;
  reg  [127:0] la_oen;

  wire [`MPRJ_IO_PADS-1:0] io_in;
  wire [`MPRJ_IO_PADS-1:0] io_out;
  wire [`MPRJ_IO_PADS-1:0] io_oeb;

  reg [`MPRJ_IO_PADS-1:0] io_in_reg;

  // Exclude flash pad and UART loopback.
  assign io_in[37:32] = io_in_reg[37:32];
  assign io_in[30:14] = io_in_reg[30:14];

  // UART loopback pin 32 (RX) to pin 31 (TX)
  assign io_in[31] = (!io_oeb[30]) ? (io_out[30]) : (1'bz);

  always #50 clk = ~clk;

  assign wb_clk_i = clk;
  assign wb_rst_i = ~resetb;

  integer i, address, data;
  initial begin
    $dumpfile("softshell_top_tb.fst");
    $dumpvars(0, softshell_top_tb);

    clk = 0;
    resetb = 0;

    io_in_reg = {`MPRJ_IO_PADS{1'b0}};

    la_data_in = 128'b0;
    la_oen = 128'b0;

    wb_stb_i = 0;
    wb_cyc_i = 0;
    wb_sel_i = 4'b0;
    wb_we_i = 0;
    wb_adr_i = 32'b0;
    wb_dat_i = 32'b0;

    #200;
    resetb = 1;
    #200;
    $display("Reset complete");

    $display("Holding CPUs in reset for RAM test");
    la_data_in[4:1] = 4'b1111;

    $display("Testing shared memory");
    for (i = 0; i < 32 * 4; i = i + 4) begin
      address = 32'h3000_0000 + i;
      data = $random;
      write(address, data);
      write(address + 4, ~data);
      read_assert(address, data);
      read_assert(address + 4, ~data);
    end
    for (i = 0; i < `SHARED_MEM_WORDS * 4; i = i + 4) begin
      address = 32'h3000_0000 + i;
      data = i;
      write(address, data);
      read_assert(address, data);
    end
    for (i = 0; i < `SHARED_MEM_WORDS * 4; i = i + 4) begin
      address = 32'h3000_0000 + i;
      data = i;
      read_assert(address, data);
    end

    $display("Releasing CPUs from reset");
    la_data_in[4:1] = 4'b1110;

    $display("Waiting for CPU GPIO toggles");
    // wait(io_out[7+14:0+14] != 8'h00);
    wait(io_out[37] == 1'b1);

    $display("Finished");
    $finish;
  end

`ifndef GL
  always begin
    wait(uut.cpus[0].core.trap == 1'b1);
    $error("CPU0 TRAP!");
    $finish;
  end

  always begin
    wait(uut.cpus[1].core.trap == 1'b1);
    $error("CPU1 TRAP!");
    $finish;
  end
`endif

`ifdef GL
  user_proj_example uut (
    .VPWR(1'b1),
    .VGND(1'b0),
`else
  softshell_top uut (
`endif
    .wb_clk_i(wb_clk_i),
    .wb_rst_i(wb_rst_i),

    .wbs_stb_i(wb_stb_i),
    .wbs_cyc_i(wb_cyc_i),
    .wbs_we_i(wb_we_i),
    .wbs_sel_i(wb_sel_i),
    .wbs_dat_i(wb_dat_i),
    .wbs_adr_i(wb_adr_i),
    .wbs_ack_o(wb_ack_o),
    .wbs_dat_o(wb_dat_o),

    // Logic Analyzer Signals
    .la_data_in(la_data_in),
    .la_data_out(la_data_out),
    .la_oen(la_oen),

    // IOs
    .io_in(io_in),
    .io_out(io_out),
    .io_oeb(io_oeb)
  );

  // Flash signals.
  wire flash_csb;
  wire flash_clk;
  wire flash_io0;
  wire flash_io1;
  wire flash_io2;
  wire flash_io3;

  assign flash_csb = (io_oeb[8] == 1'b0) ? (io_out[8]) : (1'bz);
  assign flash_clk = (io_oeb[9] == 1'b0) ? (io_out[9]) : (1'bz);
  assign flash_io0 = (io_oeb[10] == 1'b0) ? (io_out[10]) : (1'bz);
  assign flash_io1 = (io_oeb[11] == 1'b0) ? (io_out[11]) : (1'bz);
  assign flash_io2 = (io_oeb[12] == 1'b0) ? (io_out[12]) : (1'bz);
  assign flash_io3 = (io_oeb[13] == 1'b0) ? (io_out[13]) : (1'bz);
  assign io_in[10] = flash_io0;
  assign io_in[11] = flash_io1;
  assign io_in[12] = flash_io2;
  assign io_in[13] = flash_io3;

  spiflash flash_model (
    .csb(flash_csb),
    .clk(flash_clk),
    .io0(flash_io0),
    .io1(flash_io1),
    .io2(flash_io2),
    .io3(flash_io3)
  );

  task write;
    input [31:0] addr;
    input [31:0] data;
    begin
      @(posedge wb_clk_i) begin
        wb_stb_i = 1;
        wb_cyc_i = 1;
        wb_sel_i = 4'hF;
        wb_we_i = 1;
        wb_adr_i = addr;
        wb_dat_i = data;
        $display("W   [%0h]=%0h", addr, data);
      end
      // Wait for an ACK
      wait(wb_ack_o == 1);
      wait(wb_ack_o == 0);
      wb_cyc_i = 0;
      wb_stb_i = 0;
      $display("W D");
    end
  endtask

  task read;
    input [31:0] addr;
    begin
      @(posedge wb_clk_i) begin
        wb_stb_i = 1;
        wb_cyc_i = 1;
        wb_we_i = 0;
        wb_adr_i = addr;
        $display("R   [%0h]", addr);
      end
      // Wait for an ACK
      wait(wb_ack_o == 1);
      wait(wb_ack_o == 0);
      wb_cyc_i = 0;
      wb_stb_i = 0;
      $display("R D [%0h]=%0h", addr, wb_dat_o);
    end
  endtask

  task read_assert;
    input [31:0] addr;
    input [31:0] data;
    begin
      read(addr);
      if (wb_dat_o != data) begin
        $error("R!! %0h!=%0h", wb_dat_o, data);
        $fatal;
      end
    end
  endtask

endmodule
