library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_testbench is 
end entity i2c_testbench;

architecture tb of i2c_testbench is

    -- === 1. Константи ===
    constant CLK_PERIOD     : time := 20 ns; -- 50 МГц
    constant I2C_CLK_PERIOD : time := 10 us; -- 100 кГц
    constant TEST_BYTE      : std_logic_vector(7 downto 0) := x"A5"; -- Байт (10100101)

    -- === 2. Сигнали ===
    signal s_clk     : std_logic := '0';
    signal s_reset_n : std_logic;
    signal s_start_tx: std_logic := '0';
    signal s_byte_to_tx  : std_logic_vector(7 downto 0);
    signal s_tx_busy     : std_logic;
    signal s_ack_error   : std_logic;
    signal s_byte_received : std_logic_vector(7 downto 0);
    signal s_rx_done       : std_logic;

    -- Ініціалізуємо 'H' (Pull-up)
    signal s_scl : std_logic := 'H'; 
    signal s_sda : std_logic := 'H';

begin

    -- 3. Генератор CLK (50 МГц)
    s_clk <= not s_clk after CLK_PERIOD / 2;

    -- 4. Підключення Master (Tx)
    UUT_Master : entity work.i2c_master_tx
        port map (
            clk        => s_clk,
            reset_n    => s_reset_n,
            start_tx   => s_start_tx,
            byte_to_tx => s_byte_to_tx,
            tx_busy    => s_tx_busy,
            ack_error  => s_ack_error,
            scl        => s_scl,
            sda        => s_sda
        );

    -- 5. Підключення Slave (Rx) -- ВИПРАВЛЕНО ТУТ
    UUT_Slave : entity work.i2c_slave_rx
        port map (
            clk           => s_clk,
            reset_n       => s_reset_n, -- Було 'reset', стало 'reset_n'
            scl           => s_scl,
            sda           => s_sda,
            byte_received => s_byte_received,
            rx_done       => s_rx_done
        );

    -- 6. Стимули (Тестовий сценарій)
    stimulus_proc : process
    begin
        -- a) Скид
        s_reset_n <= '0';
        s_start_tx <= '0';
        wait for 100 ns;
        s_reset_n <= '1';
        wait for 100 ns;

        -- б) Готуємо дані
        s_byte_to_tx <= TEST_BYTE;
        wait for CLK_PERIOD * 10;

        -- в) Даємо команду "СТАРТ"
        s_start_tx <= '1';

        -- г) Чекаємо ОДИН ПОВНИЙ ТАКТ I2C
        wait for I2C_CLK_PERIOD;

        -- д) Знімаємо сигнал 'start'
        s_start_tx <= '0';

        -- е) Чекаємо, поки Master не стане "ВІЛЬНИЙ"
        wait until s_tx_busy = '0';
        
        wait for 1 us; 

        report "Simulation done";
        wait;
        
    end process stimulus_proc;

end architecture tb;




