// Any-to-any pin mux for slow speed peripherals.
//
// SPDX-FileCopyrightText: (c) 2020 Harrison Pham <hp@turtledevices.com>
// SPDX-License-Identifier: Apache-2.0

module pinmux #(
  // Number of peripheral inputs.  Maximum is 255.
  parameter NUM_INPUTS = 8,
  // Number of peripheral outputs.  Maximum is 255.
  parameter NUM_OUTPUTS = 8,
  // Total number of GPIOs.  Maximum is 255.
  parameter NUM_GPIOS = 32
) (
  input wb_clk_i,
  input wb_rst_i,

  input [31:0] wb_adr_i,
  input [31:0] wb_dat_i,
  input [3:0] wb_sel_i,
  input wb_cyc_i,
  input wb_stb_i,
  input wb_we_i,

  output reg [31:0] wb_dat_o,
  output reg wb_ack_o,

  input  [NUM_GPIOS-1:0] gpio_in,
  output [NUM_GPIOS-1:0] gpio_out,
  output [NUM_GPIOS-1:0] gpio_oeb,

  output [NUM_INPUTS-1:0]  peripheral_in,
  input  [NUM_OUTPUTS-1:0] peripheral_out,
  input  [NUM_OUTPUTS-1:0] peripheral_oeb
);
  localparam PINMUX_IN_SEL_ADDR  = 16'h1000;
  localparam PINMUX_OUT_SEL_ADDR = 16'h2000;

  // Number of bits required for the selection registers.  Theses are sized + 1
  // to make room for the default selection of 0.
  localparam INPUT_REG_BITS = $clog2(NUM_GPIOS + 1);
  localparam OUTPUT_REG_BITS = $clog2(NUM_OUTPUTS + 1);

  // Internal aliases for the input / outputs.  Shifted by one so that selection
  // of 0 resolves to nothing.
  wire [NUM_GPIOS:0] gpio_in_int;
  wire [NUM_OUTPUTS:0] peripheral_out_int;
  wire [NUM_OUTPUTS:0] peripheral_oeb_int;
  assign gpio_in_int = {gpio_in, 1'b0};
  assign peripheral_out_int = {peripheral_out, 1'b0};
  assign peripheral_oeb_int = {peripheral_oeb, 1'b1};

  // Input select registers, where the register value is the GPIO number to
  // route to the peripheral_in.
  reg [INPUT_REG_BITS-1:0] reg_mux_in [NUM_INPUTS-1:0];

  // Output select registers, where the register value is the peripheral_out
  // index to route to the GPIO.
  reg [OUTPUT_REG_BITS-1:0] reg_mux_out [NUM_GPIOS-1:0];

  wire slave_sel;
  wire slave_write_en;
  assign slave_sel = (wb_stb_i && wb_cyc_i);
  assign slave_write_en = (|wb_sel_i && wb_we_i);

  wire pinmux_in_sel;
  wire pinmux_out_sel;
  assign pinmux_in_sel = |(wb_adr_i[15:0] & PINMUX_IN_SEL_ADDR);
  assign pinmux_out_sel = |(wb_adr_i[15:0] & PINMUX_OUT_SEL_ADDR);

  integer i;
  always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
      for (i = 0; i < NUM_INPUTS; i = i + 1) begin
        reg_mux_in[i] <= {INPUT_REG_BITS{1'b0}};
      end
      for (i = 0; i < NUM_GPIOS; i = i + 1) begin
        reg_mux_out[i] <= {OUTPUT_REG_BITS{1'b0}};
      end
      wb_ack_o <= 1'b0;
      wb_dat_o <= 32'b0;
    end else begin
      wb_ack_o <= 1'b0;

      if (slave_sel && !wb_ack_o) begin
        wb_ack_o <= 1'b1;

        if (pinmux_in_sel) begin
          wb_dat_o <= reg_mux_in[wb_adr_i[INPUT_REG_BITS-1+2:0+2]];
          if (slave_write_en) begin
            reg_mux_in[wb_adr_i[INPUT_REG_BITS-1+2:0+2]] <=
              wb_dat_i[INPUT_REG_BITS-1:0];
          end
        end else if (pinmux_out_sel) begin
          wb_dat_o <= reg_mux_out[wb_adr_i[OUTPUT_REG_BITS-1+2:0+2]];
          if (slave_write_en) begin
            reg_mux_out[wb_adr_i[OUTPUT_REG_BITS-1+2:0+2]] <=
              wb_dat_i[OUTPUT_REG_BITS-1:0];
          end
        end
      end
    end
  end

  // Generate peripheral input selection muxes.
  genvar j;
  generate
    for (j = 0; j < NUM_INPUTS; j = j + 1) begin
      assign peripheral_in[j] = gpio_in_int[reg_mux_in[j]];
    end
  endgenerate

  // Generate peripheral output select muxes.
  generate
    for (j = 0; j < NUM_GPIOS; j = j + 1) begin
      assign gpio_out[j] = peripheral_out_int[reg_mux_out[j]];
      assign gpio_oeb[j] = peripheral_oeb_int[reg_mux_out[j]];
    end
  endgenerate

endmodule // module softshell_pinmux
