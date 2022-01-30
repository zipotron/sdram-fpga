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
    sdram_a  : out   unsigned(12 downto 0);    -- Address Input (12 bits)
    sdram_ba  : out   unsigned(1 downto 0);              -- Bank Address
    
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
  
  component sdram
  generic (
    -- clock frequency (in MHz)
    --
    -- This value must be provided, as it is used to calculate the number of
    -- clock cycles required for the other timing values.
    clk_freq : natural := 100;

    -- 32-bit controller interface
    ADDR_WIDTH : natural := 23;
    DATA_WIDTH : natural := 32;

    -- SDRAM interface
    SDRAM_ADDR_WIDTH : natural := 13;
    SDRAM_DATA_WIDTH : natural := 16;
    SDRAM_COL_WIDTH  : natural := 9;
    SDRAM_ROW_WIDTH  : natural := 13;
    SDRAM_BANK_WIDTH : natural := 2;

    -- The delay in clock cycles, between the start of a read command and the
    -- availability of the output data.
    CAS_LATENCY : natural := 2; -- 2=below 133MHz, 3=above 133MHz

    -- The number of 16-bit words to be bursted during a read/write.
    BURST_LENGTH : integer := 2;

    -- timing values (in nanoseconds)
    --
    -- These values can be adjusted to match the exact timing of your SDRAM
    -- chip (refer to the datasheet).
    T_DESL : real :=  50000.0; -- startup delay
    T_MRD  : real :=     12.0; -- mode register cycle time
    T_RC   : real :=     60.0; -- row cycle time
    T_RCD  : real :=     18.0; -- RAS to CAS delay
    T_RP   : real :=     18.0; -- precharge to activate delay
    T_WR   : real :=     12.0; -- write recovery time
    T_REFI : real :=   7800.0  -- average refresh interval
  );
  port (
    -- reset
    reset : in std_logic := '0';

    -- clock
    clk : in std_logic;

    -- address bus
    addr : in unsigned(ADDR_WIDTH-1 downto 0);

    -- input data bus
    data : in std_logic_vector(DATA_WIDTH-1 downto 0);

    -- When the write enable signal is asserted, a write operation will be performed.
    we : in std_logic;

    -- When the request signal is asserted, an operation will be performed.
    req : in std_logic;

    -- The acknowledge signal is asserted by the SDRAM controller when
    -- a request has been accepted.
    ack : out std_logic;

    -- The valid signal is asserted when there is a valid word on the output
    -- data bus.
    valid : out std_logic;

    -- output data bus
    q : out std_logic_vector(DATA_WIDTH-1 downto 0);

    -- SDRAM interface (e.g. AS4C16M16SA-6TCN, IS42S16400F, etc.)
    sdram_a     : out unsigned(SDRAM_ADDR_WIDTH-1 downto 0);
    sdram_ba    : out unsigned(SDRAM_BANK_WIDTH-1 downto 0);
    sdram_dq_in : in std_logic_vector(SDRAM_DATA_WIDTH-1 downto 0);
    sdram_dq_out: out std_logic_vector(SDRAM_DATA_WIDTH-1 downto 0);
    sdram_cke   : out std_logic;
    sdram_cs_n  : out std_logic;
    sdram_ras_n : out std_logic;
    sdram_cas_n : out std_logic;
    sdram_we_n  : out std_logic;
    sdram_dqml  : out std_logic;
    sdram_dqmh  : out std_logic
  );
  end component sdram;

  signal pll_locked : std_logic;
  signal clocks : std_logic_vector(03 downto 0);
  signal clk_hdmi : std_logic;
  signal clk_vga : std_logic;
  signal clk_cpu : std_logic;
  signal clk_sdram : std_logic;
  
  signal led       : std_logic_vector(7 downto 0) := (others => '0');
  
  signal pwr_up_reset_counter : std_logic_vector(15 downto 0) := (others => '0');
  signal pwr_up_reset_n : std_logic :='0';
  signal reset : std_logic;
  
  -- Internal signals
  signal state : std_logic;
  signal addr : unsigned(15 downto 0);
  signal req : std_logic;
  signal we : std_logic;
  signal cnt : unsigned(16 downto 0);
  signal err : std_logic;
  signal done : std_logic;
  
  signal dout : std_logic_vector(31 downto 0);
  signal valid : std_logic;
  signal din : std_logic_vector(31 downto 0);
  signal ack : std_logic;
  
  signal sdram_d_switch : std_logic_vector(15 downto 0);
  
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
    
    sdram_d_switch <= sdram_d when sdram_wen = '1' else (others => '0');
    sdram_d <= sdram_d_switch when sdram_wen = '0' else (others => '0');
    
    pwr_up_reset_n <= and pwr_up_reset_counter;
    reset <= pwr_up_reset_n or not ULX3S_RST_N;
    process (clk_cpu)
    begin
      if rising_edge(clk_cpu) and pwr_up_reset_n = '0' then
        pwr_up_reset_counter <= std_logic_vector( unsigned(pwr_up_reset_counter) + 1);
      end if;
    end process;
    
    din <= (not std_logic_vector(addr), std_logic_vector(addr));
    
    process (clk_sdram)
    begin
      if rising_edge(clk_cpu) then
        if reset = '1' then
          addr <= (others => '0');
          cnt <= (others => '0');
          req <= '0';
          we <= '0';
          state <= '0';
          led <= (others => '0');
          err <= '0';
          done <= '0';
        else
          cnt <= cnt + 1;
          if cnt = 0 then
            req <= '1';
          end if;
          if state = '0' then
            we <= '1';
            led <= din(15 downto 8);
            if ack = '1' then
              req <= '0';
              addr <= addr + 1;
              cnt <= (others => '0');
              if and addr then
                addr <= (others => '0');
                state <= '1';
                we <= '0';
                cnt <= (others => '0');
              end if;
            end if;
            else
              if ack = '1' then
                req <= '0';
              end if;
              if valid = '1' then
                led <= dout(12 downto 5);
                if dout /= din then
                  err <= '1';
                end if;
                addr <= addr + 1;
                if and std_logic_vector(addr) then 
                  done <= '1';
                end if;
              end if;
            end if;
        end if;
      end if;
    end process;
    
    inst_sdram : sdram
    generic map (
      ADDR_WIDTH => 16
    )
    port map (
      sdram_a => sdram_a,
      sdram_dq_in => sdram_d_switch,
      sdram_dq_out => sdram_d_switch,
      sdram_dqml => sdram_dqm(0),
      sdram_dqmh => sdram_dqm(1),
      sdram_cs_n => sdram_csn,
      sdram_ba => sdram_ba,
      sdram_we_n => sdram_wen,
      sdram_ras_n => sdram_rasn,
      sdram_cas_n => sdram_casn,
       -- system interface
      addr => addr,
      data => din,
      ack => ack,
      req => req,
      we => we,
      valid => valid,
      q => dout,
      clk => clk_sdram,
      reset => reset
    );
    
end architecture;
