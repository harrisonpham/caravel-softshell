// Flexible IO custom instruction for picorv32.
//
// SPDX-FileCopyrightText: (c) 2020 Harrison Pham <harrison@harrisonpham.com>
// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

module pcpi_flexio (
  input               clk,
  input               resetb,
  input               pcpi_valid,
  input       [31:0]  pcpi_insn,
  input       [31:0]  pcpi_rs1,
  input       [31:0]  pcpi_rs2,
  output              pcpi_wr,
  output      [31:0]  pcpi_rd,
  output reg          pcpi_wait,
  output reg          pcpi_ready,

  input               flexio_clk,
  input               flexio_resetb,
  input       [7:0]   flexio_in,
  output      [7:0]   flexio_out,
  output      [7:0]   flexio_oeb
);

  // fio_shift_cfg
  // opcode: custom1
  // rs1 =
  //        [31:24] output bit mask
  //        [23:20]
  //        [19:16] bits per clock
  //        [15: 0]
  // rs2 =
  //        [23: 0] clock div
  // rd  = n/a
  // funct7: 7'b0000001
  // funct3: don't care
  wire fio_shift_cfg_sel = pcpi_insn[6:0] == 7'b0101011 &&
                           pcpi_insn[31:25] == 7'b0000001;

  // fio_shift_write
  // opcode: custom1
  // rs1 = lsb write word
  // rs2 = n/a
  // rd  = n/a
  // funct7: 7'b0000010
  // funct3: don't care
  wire fio_shift_write_sel = pcpi_insn[6:0] == 7'b0101011 &&
                             pcpi_insn[31:25] == 7'b0000010;

  // fio_shift_read
  // rs1 = n/a
  // rs2 = n/a
  // rd  = readback word
  // opcode: custom1
  // funct7: 7'b0000011
  // funct3: don't care
  wire fio_shift_read_sel = pcpi_insn[6:0] == 7'b0101011 &&
                            pcpi_insn[31:25] == 7'b0000011;

  // Configuration registers.
  reg [7:0] cfg_out_bit_mask;
  reg [3:0] cfg_bits_per_clock;
  reg [23:0] cfg_clk_div;

  // Tieoff unused for now.
  assign pcpi_rd = 32'b0;
  assign pcpi_wr = 1'b0;

  // FIFO for output data.
  reg out_wr_en;
  reg [31:0] out_wr_data;
  wire out_wr_full;
  reg out_rd_en;
  wire [31:0] out_rd_data;
  wire out_rd_empty;

  afifo #(
    .LGFIFO(2),   // 4 level deep fifo
    .WIDTH(32),
    .OPT_REGISTER_READS(1'b0)
  ) out_fifo (
    .i_wclk(clk),
    .i_wr_reset_n(resetb),
    .i_wr(out_wr_en),
    .i_wr_data(out_wr_data),
    .o_wr_full(out_wr_full),

    .i_rclk(flexio_clk),
    .i_rd_reset_n(flexio_resetb),
    .i_rd(out_rd_en),
    .o_rd_data(out_rd_data),
    .o_rd_empty(out_rd_empty)
  );

  // Instruction registers.
  always @(posedge clk or negedge resetb) begin
    if (!resetb) begin
      pcpi_ready <= 1'b0;
      pcpi_wait <= 1'b0;

      out_wr_en <= 1'b0;
      out_wr_data <= 32'b0;
      cfg_out_bit_mask <= 8'b0;
      cfg_bits_per_clock <= 4'b0;
      cfg_clk_div <= 24'b0;
    end else if (pcpi_valid && !pcpi_ready) begin
      pcpi_ready <= 1'b1;
      pcpi_wait <= 1'b0;
      out_wr_en <= 1'b0;

      if (fio_shift_cfg_sel) begin
        cfg_out_bit_mask <= pcpi_rs1[31:24];
        cfg_bits_per_clock <= pcpi_rs1[19:16];
        cfg_clk_div <= pcpi_rs2[23:0];
      end else if (fio_shift_write_sel) begin
        if (out_wr_full) begin
          pcpi_ready <= 1'b0;
          pcpi_wait <= 1'b1;
        end else begin
          out_wr_data <= pcpi_rs1;
          out_wr_en <= 1'b1;
        end
      end
    end else begin
      pcpi_ready <= 1'b0;
      pcpi_wait <= 1'b0;
      out_wr_en <= 1'b0;
    end
  end

  // Clock gen.
  reg [23:0] clk_div_cnt;
  reg clk_en;

  always @(posedge flexio_clk or negedge flexio_resetb) begin
    if (!flexio_resetb) begin
      clk_div_cnt <= 24'd0;
      clk_en <= 1'b0;
    end else if (clk_div_cnt == cfg_clk_div) begin
      clk_div_cnt <= 24'd0;
      clk_en <= 1'b1;
    end else begin
      clk_div_cnt <= clk_div_cnt + 16'd1;
      clk_en <= 1'b0;
    end
  end

  // Output shift reg.
  reg [31:0] out_shift_reg;
  reg [4:0] out_shift_cnt;

  always @(posedge flexio_clk or negedge flexio_resetb) begin
    if (!flexio_resetb) begin
      out_shift_reg <= 32'b0;
      out_shift_cnt <= 5'd31;
      out_rd_en <= 1'b0;
    end else if (clk_en && out_shift_cnt == 5'd31 && !out_rd_empty) begin
      // Finished shifting out all bits, load value from shift FIFO.
      out_shift_reg <= out_rd_data;
      out_rd_en <= 1'b1;
      case (cfg_bits_per_clock)
        4'd2: out_shift_cnt <= 5'd16;
        4'd4: out_shift_cnt <= 5'd24;
        4'd8: out_shift_cnt <= 5'd28;
        default: out_shift_cnt <= 5'd0;
      endcase
    end else if (clk_en && out_shift_cnt != 5'd31) begin
      case (cfg_bits_per_clock)
        4'd2: out_shift_reg <= {out_shift_reg[29:0], 2'b00};
        4'd4: out_shift_reg <= {out_shift_reg[27:0], 4'b0};
        4'd8: out_shift_reg <= {out_shift_reg[23:0], 8'b0};
        default: out_shift_reg <= {out_shift_reg[30:0], 1'b0};
      endcase
      out_shift_cnt <= out_shift_cnt + 5'd1;
      out_rd_en <= 1'b0;
    end else begin
      out_rd_en <= 1'b0;
    end
  end

  assign flexio_out = out_shift_reg[31:24];
  assign flexio_oeb = ~cfg_out_bit_mask;

endmodule // module pcpi_flexio
