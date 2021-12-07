library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity testram is
  port (
    ULX3S_CLK   : in  std_logic;
    ULX3S_RST_N : in  std_logic;
    
    -- LED outputs
    ULX3S_LED0  : out std_logic;
    ULX3S_LED1  : out std_logic;
    ULX3S_LED2  : out std_logic;
    ULX3S_LED3  : out std_logic;
    ULX3S_LED4  : out std_logic;
    ULX3S_LED5  : out std_logic;
    ULX3S_LED6  : out std_logic;
    ULX3S_LED7  : out std_logic;
    
    sdram_clk   : out   std_logic;                        -- Master Clock
    sdram_cke   : out   std_logic;                        -- Clock Enable    
    sdram_csn  : out   std_logic;                        -- Chip Select
    sdram_rasn : out   std_logic;                        -- Row Address Strobe
    sdram_casn : out   std_logic;                        -- Column Address Strobe
    sdram_wen  : out   std_logic;                        -- Write Enable
    sdram_d    : inout std_logic_vector(15 downto 0);    -- Data I/O (16 bits)
    sdram_dqm  : out   std_logic_vector(1 downto 0);     -- Output Disable / Write Mask
    sdram_a  : out   std_logic_vector(12 downto 0);    -- Address Input (12 bits)
    sdram_ba  : out   std_logic_vector(1 downto 0);              -- Bank Address
    
    gp    : inout std_logic_vector(27 downto 0);
    gn    : inout std_logic_vector(27 downto 0)
  );
end entity;

architecture testram_rtl of testram is

  component ecp5pll
    generic (
      in_hz : in natural := 25*1000000;
      out0_hz : in natural := 125*1000000;
      out1_hz : in natural := 25*1000000;
      out2_hz : in natural := 100*1000000;                 -- SDRAM core
      out3_hz : in natural := 100*1000000;
      out3_deg : in natural := 180  -- SDRAM chip 45-330:ok 0-30:not
    );
    port (
      clk_i : in std_logic := '0';
      clk_o : out   std_logic_vector(03 downto 0);
      locked : out   std_logic
    );
  end component ecp5pll;
  
  signal pll_locked : std_logic;
  signal clocks : std_logic_vector(03 downto 0);
  
  signal led       : std_logic_vector(7 downto 0);
  
begin
  (ULX3S_LED0, ULX3S_LED1, ULX3S_LED2, ULX3S_LED3, ULX3S_LED4, ULX3S_LED5, ULX3S_LED6, ULX3S_LED7) <= led;
  ecp5pll_inst : ecp5pll
    generic map (
      in_hz => 25*1000000,
      out0_hz => 125*1000000,
      out1_hz => 25*1000000,
      out2_hz => 100*1000000,                 -- SDRAM core
      out3_hz => 100*1000000,
      out3_deg => 180  -- SDRAM chip 45-330:ok 0-30:not
    )
    port map (
      clk_i => ULX3S_CLK,
      clk_o => clocks,
      locked => pll_locked
    );
  
end architecture;
