library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity midiConverter is
    Port (
        clk       : in  std_logic;
        btnC      : in  std_logic;
        byte_in   : in  std_logic_vector(7 downto 0); --:= "0001000";
        byte_rdy  : in  std_logic := '0';
        note_on   : out std_logic := '0';                      -- '1' = note on
        note_num  : out std_logic_vector(6 downto 0) := (others => '0');  -- MIDI note 0–127
        velocity  : out std_logic_vector(6 downto 0) := (others => '0')
    );
end midiConverter;

architecture func of midiConverter is
    signal rst : std_logic;
    type parse_state_t is (WAIT_STATUS, WAIT_NOTE, WAIT_VEL);
    signal pstate   : parse_state_t := WAIT_STATUS;
    signal note_buf : std_logic_vector(6 downto 0) := (others => '0');
    signal is_noteon: std_logic := '0';
    signal run : std_logic := '0';


     -- if unsigned(byte_in) >= 248 then
    --     null; -- Gör ingenting, stanna i nuvarande tillstånd
    -- else 
begin
    process(clk)
    begin
        if rising_edge(clk) then
            rst <= btnC;
        end if;
    end process;
    
    process(clk)
    begin
        if rising_edge(clk) then  

            if rst = '1' then
                pstate <= WAIT_STATUS;
                note_on <= '0';
            elsif run = '0' and byte_rdy = '1' then
                run <= '1';
            elsif run = '1' then
                if unsigned(byte_in) >= 248 then
                    null; -- Gör ingenting, stanna i nuvarande tillstånd
                else 
                    case pstate is
                        when WAIT_STATUS =>
                            -- Note On: 0x9n (n = channel), Note Off: 0x8n
                            if byte_in(7) = '1' then
                                is_noteon <= byte_in(4);  -- '1' = Note On, '0' = Note Off
                                pstate    <= WAIT_NOTE;
                            end if;

                        when WAIT_NOTE =>
                            note_buf <= byte_in(6 downto 0);
                            pstate   <= WAIT_VEL;

                        when WAIT_VEL =>
                            velocity <= byte_in(6 downto 0);
                            note_num <= note_buf;
                            -- Note Off or velocity=0 means release
                            note_on  <= is_noteon and (byte_in(6) or byte_in(5) or
                                        byte_in(4) or byte_in(3) or byte_in(2) or
                                        byte_in(1) or byte_in(0));
                            run <= '0';
                            pstate   <= WAIT_STATUS;
                    end case;
                end if;
            end if;
        end if;
    end process;
end func;