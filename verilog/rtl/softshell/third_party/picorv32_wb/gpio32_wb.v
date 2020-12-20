// Simple 32-bit GPIO peripheral.
//
// Derived from gpio_wb.v from Caravel.

`default_nettype none
module gpio32_wb # (
    parameter GPIO_DATA = 8'h 00,
    parameter GPIO_ENA  = 8'h 04,
    parameter GPIO_PU   = 8'h 08,
    parameter GPIO_PD   = 8'h 0c
) (
    input wb_clk_i,
    input wb_rst_i,

    input [31:0] wb_dat_i,
    input [31:0] wb_adr_i,
    input [3:0] wb_sel_i,
    input wb_cyc_i,
    input wb_stb_i,
    input wb_we_i,

    output [31:0] wb_dat_o,
    output wb_ack_o,

    input [31:0]  gpio_in,
    output [31:0] gpio_out,
    output [31:0] gpio_oeb
);

    wire resetn;
    wire valid;
    wire ready;
    wire [3:0] iomem_we;

    assign resetn = ~wb_rst_i;
    assign valid = wb_stb_i && wb_cyc_i;

    assign iomem_we = wb_sel_i & {4{wb_we_i}};
    assign wb_ack_o = ready;

    gpio32 #(
        .GPIO_DATA(GPIO_DATA),
        .GPIO_ENA(GPIO_ENA),
        .GPIO_PD(GPIO_PD),
        .GPIO_PU(GPIO_PU)
    ) gpio_ctrl (
        .clk(wb_clk_i),
        .resetn(resetn),

        .iomem_addr(wb_adr_i),
        .iomem_valid(valid),
        .iomem_wstrb(iomem_we[0]),
        .iomem_wdata(wb_dat_i),
        .iomem_rdata(wb_dat_o),
        .iomem_ready(ready),

        .gpio_in(gpio_in),
        .gpio_out(gpio_out),
        .gpio_oeb(gpio_oeb)
    );

endmodule

module gpio32 #(
    parameter GPIO_DATA = 8'h 00,
    parameter GPIO_ENA  = 8'h 04,
    parameter GPIO_PU   = 8'h 08,
    parameter GPIO_PD   = 8'h 0c
) (
    input clk,
    input resetn,

    input gpio_in_pad,

    input [31:0] iomem_addr,
    input iomem_valid,
    input iomem_wstrb,
    input [31:0] iomem_wdata,
    output reg [31:0] iomem_rdata,
    output reg iomem_ready,

    input [31:0]  gpio_in,
    output [31:0] gpio_out,
    output [31:0] gpio_oeb
);

    reg [31:0] gpio_out;		// GPIO output data
    reg [31:0] gpio_pu;		// GPIO pull-up enable
    reg [31:0] gpio_pd;		// GPIO pull-down enable
    reg [31:0] gpio_oeb;    // GPIO output enable (sense negative)

    wire gpio_sel;
    wire gpio_oeb_sel;
    wire gpio_pu_sel;
    wire gpio_pd_sel;

    assign gpio_sel     = (iomem_addr[7:0] == GPIO_DATA);
    assign gpio_oeb_sel = (iomem_addr[7:0] == GPIO_ENA);
    assign gpio_pu_sel  = (iomem_addr[7:0] == GPIO_PU);
    assign gpio_pd_sel  = (iomem_addr[7:0] == GPIO_PD);

    always @(posedge clk) begin
        if (!resetn) begin
            gpio_out <= 32'h0;
            gpio_oeb <= 32'hffff_ffff;
        end else begin
            iomem_ready <= 0;
            if (iomem_valid && !iomem_ready) begin
                iomem_ready <= 1'b 1;

                if (gpio_sel) begin
                    iomem_rdata <= gpio_in;
                    if (iomem_wstrb) gpio_out <= iomem_wdata;

                end else if (gpio_oeb_sel) begin
                    iomem_rdata <= ~gpio_oeb;
                    if (iomem_wstrb) gpio_oeb <= ~iomem_wdata;

                end else if (gpio_pu_sel) begin
                    iomem_rdata <= gpio_pu;
                    if (iomem_wstrb) gpio_pu <= iomem_wdata;

                end else if (gpio_pd_sel) begin
                    iomem_rdata <= gpio_pd;
                    if (iomem_wstrb) gpio_pd <= iomem_wdata;

                end

            end
        end
    end

endmodule
`default_nettype wire
