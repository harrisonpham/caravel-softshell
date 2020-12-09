// Inferred RAM to work around limitations in Openlane.
//
// Wishbone interface based on mem_wb.v from Caravel.

`default_nettype none
module mem_ff_wb #(
  parameter MEM_WORDS = 256
)(
  input wb_clk_i,
  input wb_rst_i,

  input [31:0] wb_adr_i,
  input [31:0] wb_dat_i,
  input [3:0] wb_sel_i,
  input wb_we_i,
  input wb_cyc_i,
  input wb_stb_i,

  output wb_ack_o,
  output [31:0] wb_dat_o
);

  localparam ADR_WIDTH = $clog2(MEM_WORDS);

  wire valid;
  wire ram_wen;
  wire [3:0] wen; // write enable

  assign valid = wb_cyc_i & wb_stb_i;
  assign ram_wen = wb_we_i && valid;

  assign wen = wb_sel_i & {4{ram_wen}} ;

  /*
      Ack Generation
          - write transaction: asserted upon receiving adr_i & dat_i
          - read transaction : asserted one clock cycle after receiving the adr_i & dat_i
  */

  reg wb_ack_read;
  reg wb_ack_o;

  always @(posedge wb_clk_i) begin
    if (wb_rst_i == 1'b 1) begin
      wb_ack_read <= 1'b0;
      wb_ack_o <= 1'b0;
    end else begin
      // wb_ack_read <= {2{valid}} & {1'b1, wb_ack_read[1]};
      wb_ack_o    <= wb_we_i? (valid & !wb_ack_o): wb_ack_read;
      wb_ack_read <= (valid & !wb_ack_o) & !wb_ack_read;
    end
  end

  ff32_ram #(
    .ADDR_WIDTH(ADR_WIDTH)
  ) ram (
    .clk(wb_clk_i),

    .addr(wb_adr_i[ADR_WIDTH+1:2]),
    .din(wb_dat_i),
    .dout(wb_dat_o),

    .en(valid),
    .wmask(wen)
  );
endmodule
`default_nettype wire

// Single port 32-bit inferred RAM.
module ff32_ram #(
  parameter ADDR_WIDTH = 8
)(
  input clk,

  input [ADDR_WIDTH-1:0] addr,
  input [31:0] din,
  output reg [31:0] dout,

  input en,
  input [3:0] wmask
);
  reg [7:0] ram0 [(1<<ADDR_WIDTH)-1:0];
  reg [7:0] ram1 [(1<<ADDR_WIDTH)-1:0];
  reg [7:0] ram2 [(1<<ADDR_WIDTH)-1:0];
  reg [7:0] ram3 [(1<<ADDR_WIDTH)-1:0];

`ifdef SIM
  integer i;
  initial begin
    for (i = 0; i < (1<<ADDR_WIDTH); i = i + 1) begin
      ram0[i] = 8'b0;
      ram1[i] = 8'b0;
      ram2[i] = 8'b0;
      ram3[i] = 8'b0;
    end
  end
`endif

  // Write.
  always @(posedge clk) begin
    if (en) begin
      if (wmask[0])
        ram0[addr] <= din[7:0];
      if (wmask[1])
        ram1[addr] <= din[15:8];
      if (wmask[2])
        ram2[addr] <= din[23:16];
      if (wmask[3])
        ram3[addr] <= din[31:24];
    end
  end

  // Read.
  always @(posedge clk) begin
    if (en) begin
      dout[7:0] <= ram0[addr];
      dout[15:8] <= ram1[addr];
      dout[23:16] <= ram2[addr];
      dout[31:24] <= ram3[addr];
    end
  end
endmodule // module ff32_ram
