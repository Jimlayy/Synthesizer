library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart is
    Generic (
        clk_freq  : integer := 100000000;
        baud_rate : integer := 31250
    );
    port (
        clk      : in  std_logic;
        btnC     : in  std_logic;
        rx       : in  std_logic;
        led      : out unsigned(15 downto 0);
        
        -- Utgångar för färdigtolkad MIDI
        note_on  : out std_logic := '0';
        note_num : out std_logic_vector(6 downto 0) := (others => '0');
        velocity : out std_logic_vector(6 downto 0) := (others => '0')
    );
end uart;

architecture func of uart is

    signal rst : std_logic;

    -- UART konstanter
    constant baud      : integer := clk_freq / baud_rate;        
    constant half_baud : integer := baud / 2;

    -- UART tillstånd och signaler
    type state_t is (IDLE, START, DATA, STOPP);
    signal state    : state_t := IDLE;
    signal baud_cnt : integer range 0 to baud := 0;
    signal bit_cnt  : integer range 0 to 7 := 0;
    signal shift    : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_sync  : std_logic_vector(1 downto 0) := "11";

    -- Interna signaler mellan UART och MIDI-parser
    signal data_out : std_logic_vector(7 downto 0) := (others => '0');
    signal data_rdy : std_logic := '0';
    signal last_status : std_logic_vector(3 downto 0) := "0000";

    -- MIDI-parser tillstånd och signaler
    type parse_state_t is (WAIT_STATUS, WAIT_NOTE, WAIT_VEL);
    signal pstate    : parse_state_t := WAIT_STATUS;
    signal note_buf  : std_logic_vector(6 downto 0) := (others => '0');
    signal is_noteon : std_logic := '0';

begin

    -- 1. Synkronisera reset-knappen
    process(clk)
    begin
        if rising_edge(clk) then
            rst <= btnC;
        end if;
    end process;

    -- 2. Synkronisera den inkommande RX-signalen (förhindrar metastabilitet)
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                rx_sync <= "11";
            else
                rx_sync <= rx_sync(0) & rx;
            end if;
            -- led <= unsigned(x"000" & "00" & rx_sync);
        end if;
    end process;

    -- 3. UART RX Tillståndsmaskin
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                data_rdy <= '0';
            else
                case state is
                    when IDLE =>
                        data_rdy <= '0';
                        if rx_sync(1) = '0' then   -- falling edge = start bit
                            baud_cnt <= 0;
                            state <= START;
                        end if;

                    when START =>                  -- wait to center of start bit
                        if baud_cnt = half_baud - 1 then
                            baud_cnt <= 0;
                            state <= DATA;
                            bit_cnt <= 0;
                        else
                            baud_cnt <= baud_cnt + 1;
                        end if;

                    when DATA =>
                        if baud_cnt = baud - 1 then
                            baud_cnt <= 0;
                            shift <= rx_sync(1) & shift(7 downto 1);
                            if bit_cnt = 7 then
                                state <= STOPP;
                            else
                                bit_cnt <= bit_cnt + 1;
                            end if;
                        else
                            baud_cnt <= baud_cnt + 1;
                        end if;

                    when STOPP =>
                        if baud_cnt = baud - 1 then
                            data_out <= shift;
                            data_rdy <= '1';       -- Skicka en puls till MIDI-parsern
                            state    <= IDLE;
                            baud_cnt <= 0;
                        else
                            baud_cnt <= baud_cnt + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;

    -- 4. MIDI-parser Tillståndsmaskin
    process(clk)
    begin
        if rising_edge(clk) then  
            if rst = '1' then
                pstate <= WAIT_STATUS;
                note_on <= '0';
                
            -- Kör ENDAST logiken under den enda klockcykel som data_rdy är '1'
            elsif data_rdy = '1' then
                
                -- Filtrera bort realtidsmeddelanden (t.ex. MIDI klocka >= 248)
                if unsigned(data_out) >= 248 then
                    null; -- Gör ingenting, stanna i nuvarande tillstånd
                
                else 
                    case pstate is
                        when WAIT_STATUS =>
                            -- Kollar om MSB är 1 (Ny Status-byte)
                            if data_out(7) = '1' then
                                -- Spara statusen i minnet för framtida Running Status
                                last_status <= data_out(7 downto 4);
                                
                                if data_out(7 downto 4) = x"9" then
                                    is_noteon <= '1';
                                    pstate    <= WAIT_NOTE;
                                elsif data_out(7 downto 4) = x"8" then
                                    is_noteon <= '0';
                                    pstate    <= WAIT_NOTE;
                                else
                                    -- Okänt/annat kommando, ignorera
                                    pstate <= WAIT_STATUS;
                                end if;
                                
                            -- Om MSB är 0, men vi är i WAIT_STATUS, är det Running Status!
                            else
                                if last_status = x"9" then
                                    is_noteon <= '1';
                                    note_buf <= data_out(6 downto 0);
                                    pstate   <= WAIT_VEL;
                                elsif last_status = x"8" then
                                    is_noteon <= '0';
                                    note_buf <= data_out(6 downto 0);
                                    pstate   <= WAIT_VEL;
                                end if;
                            end if;

                        when WAIT_NOTE =>
                            -- Säkerhetskoll: Data-bytes måste ha MSB = 0
                            if data_out(7) = '0' then
                                note_buf <= data_out(6 downto 0);
                                pstate   <= WAIT_VEL;
                            else
                                -- Fick en oväntad status-byte, börja om
                                pstate <= WAIT_STATUS;
                            end if;

                        when WAIT_VEL =>
                            if data_out(7) = '0' then
                                velocity <= data_out(6 downto 0);
                                note_num <= note_buf;
                                
                                -- Slå på tonen om kommandot var Note On OCH velocity > 0
                                if is_noteon = '1' and data_out(6 downto 0) /= "0000000" then
                                    note_on <= '1';
                                else
                                    note_on <= '0';
                                end if;
                                
                                -- Gå tillbaka till WAIT_NOTE för att stödja "Running Status" 
                                --pstate <= WAIT_NOTE;
                                pstate <= WAIT_STATUS;
                            else
                                pstate <= WAIT_STATUS;
                            end if;
                    end case;
                end if;
            end if;
        end if;
    end process;

end func;