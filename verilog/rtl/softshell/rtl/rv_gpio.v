// Simple GPIO and mux module.

module rv_gpio #(
  NUM_GPIOS = 32
)(
  input  [NUM_GPIOS-1:0]io_in,
  output [NUM_GPIOS-1:0]io_out,
  output [NUM_GPIOS-1:0]io_oeb,

  output uart_rx,
  input uart_tx
);



endmodule  // module rv_gpio
