// Flexible IO.
//
// SPDX-FileCopyrightText: (c) 2020 Harrison Pham <hp@turtledevices.com>
// SPDX-License-Identifier: Apache-2.0

module flexio #(
  parameter IO_BITS = 8,      // Number of IOs supported by this flexio.
  parameter SHIFT_BITS = 128  // Shift register bits.
)(
  // Wishbone slave.
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

  // GPIO.
  input [IO_BITS-1:0] io_in,
  output [IO_BITS-1:0] io_out,
  output [IO_BITS-1:0] io_oeb
);

  wire clk;
  wire rstb;
  assign clk = wb_clk_i;
  assign rstb = ~wb_rst_i;

  // Registers.
  reg [7:0] clk_compare;

  reg [SHIFT_BITS-1:0] shift_reg[0:IO_BITS-1];

  wire clk_en;
  reg [7:0] clk_count;

  always @(posedge clk) begin
    if (!rstb) begin
      clk_count <= 0;
    end else begin
      clk_count <= clk_count + 1;
    end
  end

  assign clk_en = clk_count == clk_compare;

  always @(posedge clk) betin
    if (!rstb) begin
      integer i;
      for (i = 0; i < IO_BITS; i++) begin
        shift_reg[i] <= {SHIFT_BITS{1'b0}};
      end
    end else if (clk_en) begin
      integer i;
      for (i = 0; i < IO_BITS; i++) begin
        shift_reg[i] <= shift_reg[i][SHIFT_BITS-2:0] & io_in[0];
      end
    end
  end

endmodule // module flexio
