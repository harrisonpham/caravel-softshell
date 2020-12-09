// Flexible IO instruction for picorv32.
//
// SPDX-FileCopyrightText: (c) 2020 Harrison Pham <hp@turtledevices.com>
// SPDX-License-Identifier: Apache-2.0

module pcpi_flexio (
  input         clk,
  input         resetb,
  output        pcpi_valid,
  output [31:0] pcpi_insn,
  output [31:0] pcpi_rs1,
  output [31:0] pcpi_rs2,
  input         pcpi_wr,
  input  [31:0] pcpi_rd,
  input         pcpi_wait,
  input         pcpi_ready
);

  reg [7:0] current_buffer_a [3:0];
  reg [7:0] current_buffer_b [3:0];
  reg current_valid;

  integer i;

  always @(posedge clk) begin
    if (!resetb) begin
      current_valid <= 1'b0;
      current_buffer_a <= 32'b0;
      current_buffer_b <= 32'b0;
    end else if (current_valid && shift_en) begin
      for (i = 0; i < 4; i = i + 1) begin
        current_buffer_a[i] <= {1'b0, current_buffer_a[i][7:1]};
        current_buffer_b[i] <= {1'b0, current_buffer_b[i][7:1]};
      end
    end
  end



endmodule // module pcpi_flexio
