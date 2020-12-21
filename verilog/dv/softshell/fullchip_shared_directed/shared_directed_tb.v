// SPDX-FileCopyrightText: 2020 Efabless Corporation
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
// SPDX-License-Identifier: Apache-2.0

`default_nettype none
`timescale 1 ns / 1 ps

`include "caravel.v"
`include "spiflash.v"
`include "tbuart.v"

`ifdef GL
  `include "gl/user_proj_example.v"
  `include "gl/user_project_wrapper.v"
`else
  `include "user_project_wrapper.v"
  `include "user_proj_example.v"
  `include "softshell/rtl/softshell_top.v"
  `include "softshell/rtl/rv_core.v"
  `include "softshell/rtl/pinmux.v"
  `include "softshell/rtl/pcpi_flexio.v"
  `default_nettype wire
  // NOTE: There's a single missing wire declaration in these modules that
  // don't affect anything so just work around it in sim for now.
  `include "softshell/third_party/verilog-wishbone/rtl/wb_arbiter_3.v"
  `include "softshell/third_party/verilog-wishbone/rtl/wb_arbiter_4.v"
  `include "softshell/third_party/verilog-wishbone/rtl/wb_arbiter_5.v"
  `default_nettype none
  `include "softshell/third_party/verilog-wishbone/rtl/arbiter.v"
  `include "softshell/third_party/verilog-wishbone/rtl/priority_encoder.v"
  `include "softshell/third_party/verilog-wishbone/rtl/wb_mux_3.v"
  `include "softshell/third_party/verilog-wishbone/rtl/wb_mux_5.v"
  `include "softshell/third_party/picorv32_wb/mem_ff_wb.v"
  // NOTE: We can't re-include these because they are also included in Caravel.
  // Fortunately this isn't an issue because we are using identical versions,
  // but in the future we should rename the modules.
  // `include "softshell/third_party/picorv32_wb/simpleuart.v"
  // `include "softshell/third_party/picorv32_wb/spimemio.v"
  // `include "softshell/third_party/picorv32_wb/picorv32.v"
  `include "softshell/third_party/picorv32_wb/gpio32_wb.v"
  `include "softshell/third_party/wb2axip/rtl/afifo.v"
`endif

module shared_directed_tb;
  reg clock;
  reg RSTB;
  reg power1, power2;

  wire gpio;
  wire uart_tx;
  wire [37:0] mprj_io;
  wire [15:0] checkbits;

  assign checkbits = mprj_io[31:16];
  assign uart_tx = mprj_io[6];

  always #20 clock = ~clock;

  // Loopback Softshell UART.
  assign mprj_io[36] = mprj_io[37];

  // Tie off Softshell flash DI so Softshell doesn't propagate X's.
  reg softshell_flash_di;
  assign mprj_io[11] = softshell_flash_di;

  // Also tie off management SPI slave DI.
  assign mprj_io[3] = 1'b1;

  initial begin
    $dumpfile("shared_directed_tb.fst");
    $dumpvars(0, shared_directed_tb);

    clock = 1'b0;

    // Repeat cycles of 1000 clock edges as needed to complete testbench
    repeat (200) begin
      repeat (1000) @(posedge clock);
      // $display("+1000 cycles");
    end
    $error("%c[1;31m",27);
    $error("Monitor: Timeout");
    $error("%c[0m",27);
    $finish;
  end

  initial begin
    // Wait for test start.
    wait(gpio == 1'b1);
    $display("Softshell test started");

    // Wait for a few UART toggles.
    wait(mprj_io[37] == 1'b1);
    wait(mprj_io[37] == 1'b0);
    wait(mprj_io[37] == 1'b1);
    wait(mprj_io[37] == 1'b0);

    // Wait for test finish.
    wait(gpio == 1'b0);
    #100;
    $display("Softshell test finished");
    $finish;
  end

  // Release reset
  initial begin
    RSTB <= 1'b0;
    #1000;
    RSTB <= 1'b1;
    #2000;

    // Simulate tying the flash DI pin high much later.
    softshell_flash_di = 1'b1;
  end

  // Power-up sequence
  initial begin
    power1 <= 1'b0;
    power2 <= 1'b0;
    #200;
    power1 <= 1'b1;
    #200;
    power2 <= 1'b1;
  end

  always @(mprj_io) begin
    $display("IO state = %b", mprj_io);
  end

`ifndef GL
  always begin
    wait(uut.soc.trap == 1'b1);
    $error("Management CPU TRAP");
    #1000;
    $finish;
  end
`endif

  wire flash_csb;
  wire flash_clk;
  wire flash_io0;
  wire flash_io1;

  wire VDD1V8;
  wire VDD3V3;
  wire VSS;

  assign VDD3V3 = power1;
  assign VDD1V8 = power2;
  assign VSS = 1'b0;

  caravel uut (
    .vddio    (VDD3V3),
    .vssio    (VSS),
    .vdda     (VDD3V3),
    .vssa     (VSS),
    .vccd     (VDD1V8),
    .vssd     (VSS),
    .vdda1    (VDD3V3),
    .vdda2    (VDD3V3),
    .vssa1    (VSS),
    .vssa2    (VSS),
    .vccd1    (VDD1V8),
    .vccd2    (VDD1V8),
    .vssd1    (VSS),
    .vssd2    (VSS),
    .clock    (clock),
    .gpio     (gpio),
    .mprj_io  (mprj_io),
    .flash_csb(flash_csb),
    .flash_clk(flash_clk),
    .flash_io0(flash_io0),
    .flash_io1(flash_io1),
    .resetb   (RSTB)
  );

  spiflash #(
    .FILENAME("shared_directed.hex")
  ) spiflash (
    .csb(flash_csb),
    .clk(flash_clk),
    .io0(flash_io0),
    .io1(flash_io1),
    .io2(),
    .io3()
  );

  // Testbench UART
  tbuart tbuart (
    .ser_rx(uart_tx)
  );

endmodule
