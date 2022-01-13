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
  signal clk_hdmi : std_logic;
  signal clk_vga : std_logic;
  signal clk_cpu : std_logic;
  signal clk_sdram : std_logic;
  
  signal led       : std_logic_vector(7 downto 0) := (others => '0');
  
  signal pwr_up_reset_counter : std_logic_vector(26 downto 0) := (others => '0');
  signal pwr_up_reset_n : std_logic :='0';
  signal reset : std_logic;
  
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
    clk_hdmi <= clocks(0);
    clk_vga <= clocks(1);
    clk_cpu <= clocks(1);
    clk_sdram <= clocks(2);
    sdram_clk <= clocks(3);
    
    --pwr_up_reset_n <= '1' when not unsigned(pwr_up_reset_counter) = 0 else '0';
    pwr_up_reset_n <= pwr_up_reset_counter(20) and pwr_up_reset_counter(21) and pwr_up_reset_counter(22) and pwr_up_reset_counter(23) and pwr_up_reset_counter(24) and pwr_up_reset_counter(25) and pwr_up_reset_counter(26);
    reset <= pwr_up_reset_n or not ULX3S_RST_N;
    process (clk_cpu)
    begin
      if rising_edge(clk_cpu) then
        if pwr_up_reset_n = '0' then
          pwr_up_reset_counter <= std_logic_vector( unsigned(pwr_up_reset_counter) + 1);
        end if;
      end if;
    end process;
    
    led(0) <= pwr_up_reset_n;
    led(7 downto 1) <= pwr_up_reset_counter(26 downto 20); -- Prueba temporal
end architecture;
