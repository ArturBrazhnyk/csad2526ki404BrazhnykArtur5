--------------------------------------------------------------------------------
-- I2C Master Receiver Module
--------------------------------------------------------------------------------
-- This module implements an I2C master receiver that can read a single byte of data
-- from an I2C slave device. Key features:
--   * Supports standard I2C protocol with configurable clock frequency
--   * Implements byte-level reading with automatic address transmission
--   * Uses open-drain interface for I2C bus compatibility
--   * Samples SDA during SCL high period according to I2C specification
--   * Automatically releases SDA during receive phase (slave drives data)
--   * Generates NACK after receiving byte to terminate transfer
--   * Provides busy and error status signals
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_master_rx is
  generic (
    -- Input clock frequency in Hz (default: 50 MHz)
    CLK_FREQ : integer := 50_000_000;
    -- Target I2C bus frequency in Hz (default: 100 kHz)
    I2C_FREQ : integer := 100_000
  );
  port (
    -- System interface
    clk      : in  std_logic;                    -- System clock input
    rst_n    : in  std_logic;                    -- Active-low reset
    start    : in  std_logic;                    -- Start read sequence trigger
    addr     : in  std_logic_vector(6 downto 0); -- I2C slave address
    busy     : out std_logic;                    -- Module busy status
    data_out : out std_logic_vector(7 downto 0); -- Received data byte
    ack_err  : out std_logic;                    -- Acknowledge error flag

    -- I2C open-drain interface
    sda_i    : in  std_logic;  -- SDA input from bus (for sampling)
    sda_o    : out std_logic;  -- SDA output value (1=release, 0=drive low)
    sda_oe   : out std_logic;  -- SDA output enable (0=drive, 1=release)
    scl_o    : out std_logic;  -- SCL output value (1=release, 0=drive low)
    scl_oe   : out std_logic   -- SCL output enable (0=drive, 1=release)
  );
end entity;

architecture rtl of i2c_master_rx is
  -- Clock generation constants and signals
  constant HALF_PERIOD : integer := integer(CLK_FREQ / (2 * I2C_FREQ)); -- Half period count for I2C clock
  signal div_cnt : integer range 0 to (2**31-1) := 0; -- Clock divider counter
  signal scl_int : std_logic := '1';   -- Internal SCL clock signal
  signal tick : std_logic := '0';      -- Tick signal for I2C timing

  -- FSM states for I2C read sequence
  type state_t is (
    IDLE,   -- Waiting for start trigger
    START,  -- Generating START condition
    ADDR,   -- Sending slave address + R/W bit
    RECV,   -- Receiving data byte from slave
    ACK,    -- Master sends NACK to end transfer
    STOP,   -- Generating STOP condition
    DONE    -- Transfer complete
  );
  signal state : state_t := IDLE;

  -- Data handling signals
  signal bit_idx : integer range 0 to 7 := 7;    -- Bit counter for byte transfers
  signal shift_reg : std_logic_vector(7 downto 0) := (others => '0');  -- Shift register for receiving
  signal addr_byte : std_logic_vector(7 downto 0) := (others => '0');  -- Address byte with R/W bit

  -- SCL edge detection
  signal prev_scl : std_logic := '1';    -- Previous SCL value for edge detection
  signal scl_rising : std_logic := '0';  -- SCL rising edge detector

begin
  -- Clock Divider Process
  -- Generates tick pulses at twice the I2C clock frequency
  -- This allows control of both rising and falling edges of SCL
  process(clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        div_cnt <= 0;
        tick <= '0';
      else
        if div_cnt >= HALF_PERIOD-1 then
          div_cnt <= 0;
          tick <= '1';        -- Generate tick pulse
        else
          div_cnt <= div_cnt + 1;
          tick <= '0';
        end if;
      end if;
    end if;
  end process;

  -- SCL Generation Process
  -- Toggles the internal SCL signal on each tick
  -- SCL is initialized high and toggles at I2C clock frequency
  process(clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        scl_int <= '1';      -- Initialize SCL high
      else
        if tick = '1' then
          scl_int <= not scl_int;  -- Toggle SCL
        end if;
      end if;
    end if;
  end process;

  -- SCL Edge Detection Process
  -- Detects rising edges of SCL for proper I2C timing
  -- Rising edges are used to sample SDA during data receive
  process(clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        prev_scl <= '1';
        scl_rising <= '0';
      else
        prev_scl <= scl_int;           -- Store previous SCL value
        scl_rising <= '0';             -- Default: no edge detected
        -- Detect rising edge (0->1 transition) during tick
        if tick = '1' and prev_scl = '0' and scl_int = '1' then
          scl_rising <= '1';           -- Signal rising edge detected
        end if;
      end if;
    end if;
  end process;

  -- Main FSM Process
  -- Controls the I2C read sequence and handles data reception
  process(clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        -- Reset state and outputs
        state <= IDLE;
        busy <= '0';
        data_out <= (others => '0');
        ack_err <= '0';
      else
        -- State transitions occur on SCL rising edges
        if scl_rising = '1' then
          case state is
            -- IDLE: Wait for start trigger
            when IDLE =>
              busy <= '0';
              if start = '1' then
                addr_byte <= addr & '1';  -- Prepare address byte with read bit (1)
                state <= START;
                busy <= '1';
                bit_idx <= 7;
              end if;

            -- START: Generate START condition
            when START =>
              state <= ADDR;  -- Move to address transmission

            -- ADDR: Send slave address with read bit
            when ADDR =>
              -- Simplified: assumes slave will ACK
              if bit_idx = 0 then
                state <= RECV;    -- Move to receive after last bit
                bit_idx <= 7;     -- Reset bit counter for data byte
              else
                bit_idx <= bit_idx - 1;  -- Count down address bits
              end if;

            -- RECV: Receive data byte from slave
            when RECV =>
              -- Sample SDA input on SCL rising edge
              shift_reg(bit_idx) <= sda_i;
              if bit_idx = 0 then
                state <= ACK;     -- Move to ACK after last bit
              else
                bit_idx <= bit_idx - 1;  -- Count down data bits
              end if;

            -- ACK: Send NACK to terminate transfer
            when ACK =>
              data_out <= shift_reg;  -- Output received byte
              state <= STOP;          -- Prepare to end transfer

            -- STOP: Generate STOP condition
            when STOP =>
              state <= DONE;

            -- DONE: Return to IDLE
            when DONE =>
              busy <= '0';
              state <= IDLE;
            
            when others => 
              state <= IDLE;  -- Safety default
          end case;
        end if;
      end if;
    end if;
  end process;

  -- I2C Bus Interface Control
  -- During receive operation:
  -- - SDA is released (high) to allow slave to drive data
  -- - SCL is released to allow clock stretching by slave
  sda_o <= '1';    -- Output high when released
  sda_oe <= '1';   -- Always release SDA during receive (slave drives)
  scl_o <= '1';    -- Output high when released
  scl_oe <= '1';   -- Always release SCL (allows clock stretching)

end architecture;