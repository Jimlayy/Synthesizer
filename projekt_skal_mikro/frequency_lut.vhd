library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity frequency_lut is
    Port (
        clk: in std_logic;
        note_num : in  std_logic_vector(6 downto 0);  -- MIDI note number
        freq_hz  : out std_logic_vector(15 downto 0)  -- Frequency in Hz
    );
end frequency_lut;

architecture func of frequency_lut is
begin
    process(clk)
    begin
        if rising_edge(clk) then
            case to_integer(unsigned(note_num)) is
                -- === Octave 2 (C2–B2) ===
                when 36 => freq_hz <= std_logic_vector(to_unsigned(65,   16)); -- C2
                when 37 => freq_hz <= std_logic_vector(to_unsigned(69,   16)); -- C#2/Db2
                when 38 => freq_hz <= std_logic_vector(to_unsigned(73,   16)); -- D2
                when 39 => freq_hz <= std_logic_vector(to_unsigned(78,   16)); -- D#2/Eb2
                when 40 => freq_hz <= std_logic_vector(to_unsigned(82,   16)); -- E2
                when 41 => freq_hz <= std_logic_vector(to_unsigned(87,   16)); -- F2
                when 42 => freq_hz <= std_logic_vector(to_unsigned(93,   16)); -- F#2/Gb2
                when 43 => freq_hz <= std_logic_vector(to_unsigned(98,   16)); -- G2
                when 44 => freq_hz <= std_logic_vector(to_unsigned(104,  16)); -- G#2/Ab2
                when 45 => freq_hz <= std_logic_vector(to_unsigned(110,  16)); -- A2
                when 46 => freq_hz <= std_logic_vector(to_unsigned(117,  16)); -- A#2/Bb2
                when 47 => freq_hz <= std_logic_vector(to_unsigned(123,  16)); -- B2
                -- === Octave 3 (C3–B3) ===
                when 48 => freq_hz <= std_logic_vector(to_unsigned(131,  16)); -- C3
                when 49 => freq_hz <= std_logic_vector(to_unsigned(139,  16)); -- C#3
                when 50 => freq_hz <= std_logic_vector(to_unsigned(147,  16)); -- D3
                when 51 => freq_hz <= std_logic_vector(to_unsigned(156,  16)); -- D#3
                when 52 => freq_hz <= std_logic_vector(to_unsigned(165,  16)); -- E3
                when 53 => freq_hz <= std_logic_vector(to_unsigned(175,  16)); -- F3
                when 54 => freq_hz <= std_logic_vector(to_unsigned(185,  16)); -- F#3
                when 55 => freq_hz <= std_logic_vector(to_unsigned(196,  16)); -- G3
                when 56 => freq_hz <= std_logic_vector(to_unsigned(208,  16)); -- G#3
                when 57 => freq_hz <= std_logic_vector(to_unsigned(220,  16)); -- A3
                when 58 => freq_hz <= std_logic_vector(to_unsigned(233,  16)); -- A#3
                when 59 => freq_hz <= std_logic_vector(to_unsigned(247,  16)); -- B3
                -- === Octave 4 (C4–B4) — middle octave ===
                when 60 => freq_hz <= std_logic_vector(to_unsigned(262,  16)); -- C4 (middle C)
                when 61 => freq_hz <= std_logic_vector(to_unsigned(277,  16)); -- C#4
                when 62 => freq_hz <= std_logic_vector(to_unsigned(294,  16)); -- D4
                when 63 => freq_hz <= std_logic_vector(to_unsigned(311,  16)); -- D#4
                when 64 => freq_hz <= std_logic_vector(to_unsigned(330,  16)); -- E4
                when 65 => freq_hz <= std_logic_vector(to_unsigned(349,  16)); -- F4
                when 66 => freq_hz <= std_logic_vector(to_unsigned(370,  16)); -- F#4
                when 67 => freq_hz <= std_logic_vector(to_unsigned(392,  16)); -- G4
                when 68 => freq_hz <= std_logic_vector(to_unsigned(415,  16)); -- G#4
                when 69 => freq_hz <= std_logic_vector(to_unsigned(440,  16)); -- A4 (concert A)
                when 70 => freq_hz <= std_logic_vector(to_unsigned(466,  16)); -- A#4
                when 71 => freq_hz <= std_logic_vector(to_unsigned(494,  16)); -- B4
                -- === Octave 5 (C5–B5) ===
                when 72 => freq_hz <= std_logic_vector(to_unsigned(523,  16)); -- C5
                when 73 => freq_hz <= std_logic_vector(to_unsigned(554,  16)); -- C#5
                when 74 => freq_hz <= std_logic_vector(to_unsigned(587,  16)); -- D5
                when 75 => freq_hz <= std_logic_vector(to_unsigned(622,  16)); -- D#5
                when 76 => freq_hz <= std_logic_vector(to_unsigned(659,  16)); -- E5
                when 77 => freq_hz <= std_logic_vector(to_unsigned(698,  16)); -- F5
                when 78 => freq_hz <= std_logic_vector(to_unsigned(740,  16)); -- F#5
                when 79 => freq_hz <= std_logic_vector(to_unsigned(784,  16)); -- G5
                when 80 => freq_hz <= std_logic_vector(to_unsigned(831,  16)); -- G#5
                when 81 => freq_hz <= std_logic_vector(to_unsigned(880,  16)); -- A5
                when 82 => freq_hz <= std_logic_vector(to_unsigned(932,  16)); -- A#5
                when 83 => freq_hz <= std_logic_vector(to_unsigned(988,  16)); -- B5
                -- === C6 (top note) ===
                when 84 => freq_hz <= std_logic_vector(to_unsigned(1046, 16)); -- C6
                -- Safety default
                when others => freq_hz <= (others => '0');
            end case;
        end if;
    end process;
end func;