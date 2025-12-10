library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_master_tx is
    generic (
        SYS_CLK_FREQ : integer := 50_000_000; 
        I2C_CLK_FREQ : integer := 100_000 
    );
    port (
        clk         : in  std_logic;
        reset_n     : in  std_logic;
        start_tx    : in  std_logic;
        byte_to_tx  : in  std_logic_vector(7 downto 0);
        tx_busy     : out std_logic;
        ack_error   : out std_logic;
        scl         : inout std_logic;
        sda         : inout std_logic
    );
end entity i2c_master_tx;

architecture rtl of i2c_master_tx is

    -- Розрахунок дільника. Наприклад, 50MHz / 100kHz = 500 тактів.
    -- I2C цикл буде мати 4 фази (квадранти) для стабільності.
    constant DIVIDER_MAX : integer := (SYS_CLK_FREQ / I2C_CLK_FREQ) / 4; 
    signal cnt : integer range 0 to DIVIDER_MAX;
    
    -- Стани автомату
    type t_state is (ST_IDLE, ST_START, ST_TX_DATA, ST_RX_ACK, ST_STOP);
    signal state : t_state;

    -- Внутрішні сигнали
    signal bit_cnt : integer range 0 to 7;
    signal data_reg : std_logic_vector(7 downto 0);
    signal sda_en : std_logic := '0'; -- '1' = тягнемо SDA в 0
    signal scl_en : std_logic := '0'; -- '1' = тягнемо SCL в 0
    
    -- Додаткові прапорці для керування фазами I2C
    -- phase 0: SCL=0, зміна даних
    -- phase 1: SCL=0 -> 1 (rising)
    -- phase 2: SCL=1, читання даних
    -- phase 3: SCL=1 -> 0 (falling)
    signal phase : integer range 0 to 3 := 0;
    
    signal s_ack_error : std_logic := '0';
    signal s_tx_busy : std_logic := '0';

begin

    -- ================================================================
    -- ЄДИНИЙ ПРОЦЕС (Sychronous Logic)
    -- Керує всім, працює від 50 MHz, використовує лічильник
    -- ================================================================
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            state <= ST_IDLE;
            cnt <= 0;
            phase <= 0;
            sda_en <= '0';
            scl_en <= '0';
            s_tx_busy <= '0';
            s_ack_error <= '0';
            data_reg <= (others => '0');
            bit_cnt <= 7;
            
        elsif rising_edge(clk) then
            
            -- 1. Дільник частоти (генерація фаз)
            if state /= ST_IDLE then
                if cnt = DIVIDER_MAX - 1 then
                    cnt <= 0;
                    if phase = 3 then
                        phase <= 0;
                    else
                        phase <= phase + 1;
                    end if;
                else
                    cnt <= cnt + 1;
                end if;
            else
                -- В IDLE скидаємо лічильники
                cnt <= 0;
                phase <= 0;
            end if;

            -- 2. Автомат станів
            case state is
                
                -- ОЧІКУВАННЯ
                when ST_IDLE =>
                    s_tx_busy <= '0';
                    sda_en <= '0'; -- SDA відпущена (1)
                    scl_en <= '0'; -- SCL відпущена (1)
                    
                    if start_tx = '1' then
                        state <= ST_START;
                        data_reg <= byte_to_tx;
                        bit_cnt <= 7;
                        s_tx_busy <= '1';
                        s_ack_error <= '0';
                        phase <= 0; -- Починаємо з фази 0
                    end if;

                -- СТАРТ: SDA падає, поки SCL високий
                when ST_START =>
                    -- Фаза 0..1: SCL=1, SDA=1
                    -- Фаза 2: SCL=1, SDA=0 (START!)
                    -- Фаза 3: SCL=0, SDA=0
                    
                    if cnt = 0 then -- Виконуємо дію на початку фази
                        case phase is
                            when 0 => scl_en <= '0'; sda_en <= '0'; -- Підготовка
                            when 1 => scl_en <= '0'; sda_en <= '0';
                            when 2 => scl_en <= '0'; sda_en <= '1'; -- START: SDA -> 0
                            when 3 => scl_en <= '1'; sda_en <= '1'; -- SCL -> 0
                                      state <= ST_TX_DATA; -- Перехід
                            when others => null;
                        end case;
                    end if;

                -- ПЕРЕДАЧА БІТІВ
                when ST_TX_DATA =>
                    if cnt = 0 then
                        case phase is
                            when 0 => -- SCL=0, Змінюємо дані
                                scl_en <= '1';
                                if data_reg(bit_cnt) = '0' then
                                    sda_en <= '1'; -- '0'
                                else
                                    sda_en <= '0'; -- 'Z' (1)
                                end if;
                                
                            when 1 => -- SCL -> 1 (Rising)
                                scl_en <= '0';
                                
                            when 2 => -- SCL=1, Тримаємо
                                scl_en <= '0';
                                
                            when 3 => -- SCL -> 0 (Falling)
                                scl_en <= '1';
                                if bit_cnt = 0 then
                                    state <= ST_RX_ACK;
                                else
                                    bit_cnt <= bit_cnt - 1;
                                end if;
                        end case;
                    end if;

                -- ОТРИМАННЯ ACK
                when ST_RX_ACK =>
                    if cnt = 0 then
                        case phase is
                            when 0 => -- SCL=0, Відпускаємо SDA
                                scl_en <= '1';
                                sda_en <= '0'; -- Slave має керувати лінією
                                
                            when 1 => -- SCL -> 1
                                scl_en <= '0';
                                
                            when 2 => -- SCL=1, Читаємо ACK
                                scl_en <= '0';
                                if sda = '1' then -- Якщо SDA=1, це NACK (помилка)
                                    s_ack_error <= '1';
                                end if;
                                
                            when 3 => -- SCL -> 0
                                scl_en <= '1';
                                state <= ST_STOP;
                        end case;
                    end if;

                -- СТОП: SDA піднімається, поки SCL високий
                when ST_STOP =>
                     if cnt = 0 then
                        case phase is
                            when 0 => -- SCL=0, SDA=0
                                scl_en <= '1';
                                sda_en <= '1';
                                
                            when 1 => -- SCL -> 1 (Rising)
                                scl_en <= '0'; -- SCL=1, SDA=0
                                
                            when 2 => -- SDA -> 1 (Rising) = STOP!
                                scl_en <= '0';
                                sda_en <= '0'; -- SDA=1
                                
                            when 3 => -- Завершення
                                state <= ST_IDLE;
                        end case;
                    end if;
                    
            end case;
        end if;
    end process;

    -- Виходи (Open-Drain логіка)
    scl <= '0' when scl_en = '1' else 'Z';
    sda <= '0' when sda_en = '1' else 'Z';
    
    tx_busy <= s_tx_busy;
    ack_error <= s_ack_error;

end architecture rtl;



