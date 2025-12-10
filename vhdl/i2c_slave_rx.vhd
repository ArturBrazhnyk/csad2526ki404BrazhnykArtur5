library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i2c_slave_rx is
    port (
        clk           : in  std_logic;                    
        reset_n       : in  std_logic; -- ВИПРАВЛЕНО: стало reset_n (Active Low)
        scl           : in  std_logic;                    
        sda           : inout std_logic;                  
        byte_received : out std_logic_vector(7 downto 0); 
        rx_done       : out std_logic                     
    );
end entity i2c_slave_rx;

architecture Behavioral of i2c_slave_rx is

    type state_type is (ST_IDLE, ST_RX_BYTE, ST_SEND_ACK, ST_WAIT_STOP);
    signal state : state_type := ST_IDLE;

    signal scl_meta, scl_sync, scl_prev : std_logic := '1';
    signal sda_meta, sda_sync, sda_prev : std_logic := '1';

    signal start_condition : std_logic;
    signal stop_condition  : std_logic;
    signal scl_rising_edge : std_logic;
    signal scl_falling_edge: std_logic;

    signal bit_counter : integer range 0 to 7 := 7;
    signal rx_buffer   : std_logic_vector(7 downto 0) := (others => '0');
    
    signal sda_out_en  : std_logic := '0'; 

begin

    -- 1. Синхронізація
    process(clk)
    begin
        if rising_edge(clk) then
            scl_meta <= scl;
            scl_sync <= scl_meta;
            scl_prev <= scl_sync; 

            sda_meta <= sda;
            sda_sync <= sda_meta;
            sda_prev <= sda_sync; 
        end if;
    end process;

    -- Детектори
    start_condition <= '1' when (scl_sync = '1' and sda_prev = '1' and sda_sync = '0') else '0';
    stop_condition  <= '1' when (scl_sync = '1' and sda_prev = '0' and sda_sync = '1') else '0';
    scl_rising_edge <= '1' when (scl_prev = '0' and scl_sync = '1') else '0';
    scl_falling_edge <= '1' when (scl_prev = '1' and scl_sync = '0') else '0';

    -- 2. FSM
    process(clk)
    begin
        if rising_edge(clk) then
            -- ВИПРАВЛЕНО: Логіка Active Low Reset
            if reset_n = '0' then
                state         <= ST_IDLE;
                sda_out_en    <= '0';
                bit_counter   <= 7;
                rx_done       <= '0';
                byte_received <= (others => '0');
                rx_buffer     <= (others => '0');
            else
                rx_done <= '0';

                if start_condition = '1' then
                    state       <= ST_RX_BYTE;
                    bit_counter <= 7;
                    sda_out_en  <= '0';
                elsif stop_condition = '1' then
                    if state = ST_WAIT_STOP then
                         byte_received <= rx_buffer; 
                         rx_done       <= '1';       
                    end if;
                    state      <= ST_IDLE;
                    sda_out_en <= '0';
                else
                    
                    case state is
                        when ST_IDLE =>
                            sda_out_en <= '0';

                        when ST_RX_BYTE =>
                            if scl_rising_edge = '1' then
                                rx_buffer(bit_counter) <= sda_sync; 
                                if bit_counter = 0 then
                                    state <= ST_SEND_ACK; 
                                else
                                    bit_counter <= bit_counter - 1;
                                end if;
                            end if;

                        when ST_SEND_ACK =>
                            -- ACK (притягуємо SDA)
                            if scl_falling_edge = '1' then
                                sda_out_en <= '1'; 
                            end if;
                            
                            -- Відпускаємо після проходження 9-го такту
                            if scl_falling_edge = '1' and sda_out_en = '1' then
                                state      <= ST_WAIT_STOP;
                                sda_out_en <= '0'; 
                            end if;

                        when ST_WAIT_STOP =>
                            sda_out_en <= '0';
                            
                    end case;
                end if;
            end if;
        end if;
    end process;

    sda <= '0' when sda_out_en = '1' else 'Z';

end Behavioral;


