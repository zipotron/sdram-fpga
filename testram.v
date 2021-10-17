`default_nettype none
module testram (
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

  // ===============================================================
  // System Clock generation
  // ===============================================================
  wire clk_sdram_locked;
  wire [3:0] clocks;

  ecp5pll
  #(
      .in_hz( 25*1000000),
    .out0_hz(125*1000000),
    .out1_hz( 25*1000000),
    .out2_hz(100*1000000),                 // SDRAM core
    .out3_hz(100*1000000), .out3_deg(180)  // SDRAM chip 45-330:ok 0-30:not
  )
  ecp5pll_inst
  (
    .clk_i(clk_25mhz),
    .clk_o(clocks),
    .locked(clk_sdram_locked)
  );

  wire clk_hdmi  = clocks[0];
  wire clk_vga   = clocks[1];
  wire clk_cpu   = clocks[1];
  wire clk_sdram = clocks[2];
  assign sdram_clk = clocks[3];
  assign sdram_cke = 1'b1;

  // ===============================================================
  // Reset generation
  // ===============================================================
  reg [15:0] pwr_up_reset_counter = 0;
  wire       pwr_up_reset_n = &pwr_up_reset_counter;
  wire       reset = ~pwr_up_reset_n | ~btn[0];

  always @(posedge clk_cpu) begin
     if (!pwr_up_reset_n)
       pwr_up_reset_counter <= pwr_up_reset_counter + 1;
  end

  // ===============================================================
  // Diagnostic leds
  // ===============================================================
  wire [15:0] diag16;

  generate
    genvar i;
      for(i = 0; i < 4; i = i+1) begin
        assign gn[17-i] = diag16[8+i];
        assign gp[17-i] = diag16[12+i];
        assign gn[24-i] = diag16[i];
        assign gp[24-i] = diag16[4+i];
      end
  endgenerate

  // ===============================================================
  // Signals
  // ===============================================================
  reg         state;
  reg [7:0]   addr;
  reg         req;
  reg         we;
  reg [22:0]  cnt;

  wire [31:0] dout;
  wire        valid;
  wire [31:0] din = addr;
  wire        ack;

  // ===============================================================
  // Test SDRAM by showing counter on leds
  // ===============================================================
  always @(posedge clk_cpu) begin
    if (reset) begin
      addr <= 0;
      cnt <= 0;
      req <= 0;
      we <= 0;
      state <= 0;
      led <= 0;
    end else begin
      cnt <= cnt + 1;                // Delay counter
      if (cnt == 0) req <= 1;        // Start request when counter is zero
      if (state == 0) begin          // write 256 values
	we <= 1;
	led <= din;                  // Put value written on leds (writes too fast to see this)
        if (ack) begin               // Cancel request on ack, and increment address
	  req <= 0;
          addr <= addr + 1;
	  cnt <= 0;                  // Fast write
	  if (&addr) begin           // Switch to read
            addr <= 0;
	    state <= 1;
	    we <= 0;
	    cnt <= 0;
	  end
        end  
      end else begin                 // read
	if (ack) begin
	  req <= 0;
	  addr <= addr + 1;
	end
	if (valid) led <= dout[7:0]; // Put valid data read on leds
      end
    end
  end

  // ===============================================================
  // VHDL SDRAM controller
  // ===============================================================
  sdram sdram_i (
   .sdram_a(sdram_a),
   .sdram_dq(sdram_d),
   .sdram_dqml(sdram_dqm[0]),
   .sdram_dqmh(sdram_dqm[1]),
   .sdram_cs_n(sdram_csn),
   .sdram_ba(sdram_ba),
   .sdram_we_n(sdram_wen),
   .sdram_ras_n(sdram_rasn),
   .sdram_cas_n(sdram_casn),
   // system interface
   .addr(addr),
   .data(din),
   .ack(ack),
   .req(req),
   .we(we),
   .valid(valid),
   .q(dout),
   .clk(clk_cpu),
   .reset(reset)
  );

  // Diagnostic leds
  assign diag16 = {reset, valid, ack, state, addr};

endmodule

