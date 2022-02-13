module top (
  input         clk_25mhz,
  // Buttons
  input [6:0]   btn,
  output sdram_csn,       // chip select
  output sdram_clk,       // clock to SDRAM
  output sdram_cke,       // clock enable to SDRAM
  output sdram_rasn,      // SDRAM RAS
  output sdram_casn,      // SDRAM CAS
  output sdram_wen,       // SDRAM write-enable
  output [12:0] sdram_a,  // SDRAM address bus
  output  [1:0] sdram_ba, // SDRAM bank-address
  output  [1:0] sdram_dqm,// byte select
  inout  [15:0] sdram_d,  // data bus to/from SDRAM
  inout  [27:0] gp,gn,
  // Leds
  output reg [7:0]  led
);

  testram testram_i(
    .ULX3S_CLK(clk_25mhz),
    .ULX3S_RST_N(btn[0]),
    .ULX3S_LED0(led[0]),
    .ULX3S_LED1(led[1]),
    .ULX3S_LED2(led[2]),
    .ULX3S_LED3(led[3]),
    .ULX3S_LED4(led[4]),
    .ULX3S_LED5(led[5]),
    .ULX3S_LED6(led[6]),
    .ULX3S_LED7(led[7]),
    .sdram_clk(sdram_clk),
    .sdram_cke(sdram_cke),
    .sdram_csn(sdram_csn),
    .sdram_rasn(sdram_rasn),
    .sdram_casn(sdram_casn),
    .sdram_wen(sdram_wen),
    .sdram_d(sdram_d),
    .sdram_dqm(sdram_dqm),
    .sdram_a(sdram_a),
    .sdram_ba(sdram_ba),
    .gp(gp),
    .gn(gn));
   
endmodule
