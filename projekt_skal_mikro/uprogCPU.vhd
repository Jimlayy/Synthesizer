library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- TODO:
-- SEQ i micro Program Counter -- DONE
-- Exekvering av K1 och K2 -- DONE

--CPU interface
entity uprogCPU is
  port(clk: in std_logic;
		btnC : in std_logic;     -- reset button (middle of the five), active high
		JC : in std_logic_vector(7 downto 0);
		JB : out std_logic_vector(7 downto 0);
		led : out unsigned(15 downto 0)
	);
end entity;

architecture func of uprogCPU is

	signal rst : std_logic;       -- synchronous clear

	-- audio signals
	signal current_note_on  : std_logic;
    signal current_note_num : std_logic_vector(6 downto 0);
    signal current_velocity : std_logic_vector(6 downto 0);

	-- micro Memory component
	component uMem
		port(uAddr : in unsigned(13 downto 0);
			uData : out unsigned(31 downto 0));
	end component;

	-- program Memory component
	component pMem
		port(pAddr : in unsigned(31 downto 0);
			pData : out unsigned(31 downto 0));
	end component;

	-- micro memory signals
	signal uM : unsigned(31 downto 0); -- micro Memory output
	alias ALU : unsigned (3 downto 0) is uM(31 downto 28);
	alias TB : unsigned(2 downto 0) is uM(27 downto 25);
	alias FB : unsigned(2 downto 0) is uM(24 downto 22);
	alias S : std_logic is uM(21);  -- (0 = GRx styr MUX, 1 = M styr MUX)
	alias P : std_logic is uM(20); -- (0 = NOP, 1 : PC++)
	alias LC : unsigned(1 downto 0) is uM(19 downto 18);
	alias SEQ : unsigned(3 downto 0) is uM(17 downto 14);
	alias uAddr : unsigned(13 downto 0) is uM(13 downto 0);

	-- program memory signals
	signal PM : unsigned(31 downto 0); -- Program Memory output

	-- local registers
	signal uPC : unsigned(13 downto 0); -- micro Program Counter
	signal PC : unsigned(9 downto 0); -- Program Counter
	signal IR : unsigned(31 downto 0); -- Instruction Register
	signal ASR : unsigned(31 downto 0); -- Address Register
	signal AR : unsigned(31 downto 0); -- Accumulator Register
	

	-- general registers
	signal GR0 : unsigned(31 downto 0); 
	signal GR1 : unsigned(31 downto 0);
	signal GR2 : unsigned(31 downto 0);
	signal GR3 : unsigned(31 downto 0);

	-- loop counter
	signal loop_counter : unsigned(7 downto 0);

	-- IR signals
	alias OP : unsigned (3 downto 0) is IR(31 downto 28);
	alias GRx : unsigned(1 downto 0) is IR(27 downto 26);
	alias M : unsigned(1 downto 0) is IR(25 downto 24);
	alias Ra : unsigned(3 downto 0) is IR(23 downto 20);
	alias Const : unsigned(19 downto 0) is IR(19 downto 0);

	-- local combinatorials
	signal DATA_BUS : unsigned(31 downto 0); -- Data Bus

	-- flags
	signal Z : std_logic;
	signal N : std_logic; 
	signal C : std_logic;
	signal O : std_logic;
	signal L : std_logic;

	-- K1
	signal k1_adr : unsigned(13 downto 0);
	signal k2_adr : unsigned(13 downto 0);

	type k1_t is array(0 to 12) of unsigned(13 downto 0);
	constant k1_c : k1_t := 
	(b"00_0000_0000_1010", -- 0000 LOAD -- FUNKAR
	 b"00_0000_0000_1100", -- 0001 STORE
	 b"00_0000_0000_1110", -- 0010 ADD 
	 b"00_0000_0001_0010", -- 0011 SUB -- FUNKAR
	 b"00_0000_0001_0110", -- 0100 AND
	 b"00_0000_0001_1010", -- 0101 LSR
	 b"00_0000_0010_0000", -- 0110 BRA
	 b"00_0000_0010_0100", -- 0111 BNE
	 b"00_0000_0010_1000", -- 1000 HALT -- FUNKAR
	 b"00_0000_0010_1001", -- 1001 CMP
	 b"00_0000_0010_1100", -- 1010 BGE
	 b"00_0000_0011_0001", -- 1011 BEQ
	 b"00_0000_0011_0011"  -- 1100 LDI
	 );
	signal k1 : k1_t := k1_c;

	-- K2
	type k2_t is array(0 to 3) of unsigned(13 downto 0);
	constant k2_c : k2_t := 
	(b"00_0000_0000_0011", -- Direktadressering
	 b"00_0000_0000_0100", -- Immediate
	 b"00_0000_0000_0101", -- Indirekt adressering
	 b"00_0000_0000_0111"  -- Indexerad adressering
	 );
	signal k2 : k2_t := k2_c; 


begin
	led(7 downto 0) <= unsigned(JC);
	JB(0) <= GR1(0);        -- Ljudsignalen
	JB(7 downto 1) <= (others => '0');

	k1_adr <= k1(to_integer(OP));
	k2_adr <= k2(to_integer(M));

	e_uart: entity work.uart
		port map(
			clk => clk, 
			btnC => btnC,
			
			rx => JC(3),
			led => led,

			note_on   => current_note_on,
			note_num  => current_note_num,
			velocity  => current_velocity
		);

	-- e_midiConverter: entity work.midiConverter
	-- 	port map(
	-- 		clk => clk, 
	-- 		btnC => btnC,

	-- 		byte_in => internal_byte_data,
	-- 		byte_rdy => internal_byte_rdy,

	-- 		note_on   => current_note_on,
	-- 		note_num  => current_note_num,
	-- 		velocity  => current_velocity
	-- 	);

	process(clk)
	begin
		if rising_edge(clk) then
			rst <= btnC; -- syncronize the reset signal
			--led <= GR0(15 downto 0);
		end if;
	end process;



	-- ALU
	process(clk)
		variable vAR_comp : unsigned(32 downto 0); 

	begin
		if rising_edge(clk) then
			if (rst = '1') then
				AR <= (others => '0');
				Z <= '0';
				N <= '0';
				O <= '0';
				C <= '0';
			else
				case ALU is
					when "0001" => -- BUSS
						AR <= DATA_BUS;
					when "0100" => -- AR + BUSS
						vAR_comp := ("0" & AR) + ("0" & DATA_BUS);

						C <= vAR_comp(32);

						AR <= vAR_comp(31 downto 0);
						if ((AR(31) = DATA_BUS(31)) and (DATA_BUS(31) /= vAR_comp(31))) then
							O <= '1';
						else 
							O <= '0';
						end if;

						N <= vAR_comp(31);

						if (vAR_comp(31 downto 0) = x"00000000") then
							Z <= '1';
						else 
							Z <= '0';
						end if;
					when "0101" => -- AR - BUSS
						vAR_comp := ("0" & AR) - ("0" & DATA_BUS);
						AR <= vAR_comp(31 downto 0);
						if (vAR_comp(31 downto 0) = 0) then
							Z <= '1';
						else 
							Z <= '0';
						end if;
						if(vAR_comp(31) = '1') then
							N <= '1';
						else 
							N <= '0';
						end if;
						if ((AR(31) /= DATA_BUS(31)) and (vAR_comp(31) /= AR(31))) then
							O <= '1';
						else
							O <= '0';
						end if;
						C <= '0';
					when "1000" => -- AR + BUSS (inga flaggor)
						AR <= AR + DATA_BUS;
					when others => -- NOP
						NULL;
				end case; 
			end if;
		end if;
	end process;

	-- mPC : micro Program Counter
	process(clk)
	begin
		if rising_edge(clk) then
			if (rst = '1') then
				uPC <= (others => '0');
			else 
				case SEQ is 
					when "0000" =>
						uPC <= uPC + 1;
					when "0001" =>
						uPC <= k1_adr;
					when "0010" =>
						uPC <= k2_adr;
					when "0011" =>
						uPC <= (others => '0');
					when "0100" =>
						if(Z = '0') then
							uPC <= uAddr;
						else 
							uPC <= uPC + 1;
						end if;
					when "0101" =>
						uPC <= uAddr;
					when "1000" =>
						if(Z = '1') then
							uPC <= uAddr;
						else 
							uPC <= uPC + 1;
						end if;
					when "1001" =>
						if(N = '1') then
							uPC <= uAddr;
						else 
							uPC <= uPC + 1;
						end if;
					when "1010" =>
						if(C = '1') then
							uPC <= uAddr;
						else 
							uPC <= uPC + 1;
						end if;
					when "1011" =>
						if(O = '1') then
							uPC <= uAddr;
						else 
							uPC <= uPC + 1;
						end if;
					when "1100" =>
						if(L = '1') then
							uPC <= uAddr;
						else 
							uPC <= uPC + 1;
						end if;
					when "1101" =>
						if(C = '0') then
							uPC <= uAddr;
						else 
							uPC <= uPC + 1;
						end if;
					when "1110" =>
						if(O = '0') then
							uPC <= uAddr;
						else 
							uPC <= uPC + 1;
						end if;
					when "1111" =>
						uPC <= uPC;
						-- halt
					when others =>
							NULL; --nop
				end case;
			end if;
		end if;
	end process;

	-- LC : loop counter
	process(clk)
	begin
		if rising_edge(clk) then
			if(rst = '1') then
				loop_counter <= (others => '0');
			else 
				case LC is
					when "01" => 
						loop_counter <= loop_counter - 1;
					when "10" =>
						loop_counter <= DATA_BUS(7 downto 0);
					when "11" =>
						loop_counter <= "0" & uAddr(6 downto 0);
					when others =>
						NULL;
				end case; 
			end if;
		end if;
	end process;

	-- IR : Instruction Register
	process(clk)
	begin
		if rising_edge(clk) then
			if (rst = '1') then
				IR <= (others => '0');
			elsif (FB = "001") then
				IR <= DATA_BUS;
			end if;
		end if;
	end process;

	-- ASR : Address Register
	process(clk)
	begin
		if rising_edge(clk) then
			if (rst = '1') then
				ASR <= (others => '0');
			elsif (FB = "111") then
				ASR <= DATA_BUS;
			end if;
		end if;
	end process;

	-- GR0 : General Register 0
    process(clk)
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                GR0 <= (others => '0');
            elsif (FB = "110" and GRx = "00") then
                GR0 <= DATA_BUS;
            end if;
        end if;
    end process;

    -- GR1 : General Register 1
    process(clk)
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                GR1 <= (others => '0');
            elsif (FB = "110" and GRx = "01") then 
                GR1 <= DATA_BUS;
            end if;
        end if;
    end process;

    -- GR2 : General Register 2
    process(clk)
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                GR2 <= (others => '0');
            elsif (FB = "110" and GRx = "10") then 
                GR2 <= DATA_BUS;
            end if;
        end if;
    end process;

	-- GR3 : General Register 3
    process(clk)
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                GR3 <= (others => '0');
            elsif (FB = "110" and GRx = "11") then 
                GR3 <= DATA_BUS;
            end if;
        end if;
    end process;

	-- PC : Program Counter
	process(clk)
	begin
		if rising_edge(clk) then
			if (rst = '1') then
				PC <= (others => '0');
			else  
				if (FB = "011") then
					PC <= DATA_BUS(9 downto 0);
				elsif (P = '1') then
					PC <= PC + 1;
				end if;
			end if;
		end if;
	end process;


	-- micro memory component connection
	U0 : uMem port map(uAddr=>uPC, uData=>uM);

	-- program memory component connection
	U1 : pMem port map(pAddr=>ASR, pData=>PM);

	-- Data bus assignment (Kombinatorisk multiplexer)
    DATA_BUS <= 
		x"FFF" & IR(19 downto 0) when (TB = "001" and IR(19) = '1') else
        
		x"000" & IR(19 downto 0) when (TB = "001" and IR(19) = '0') else

		-- unsigned(x"000000" & "0" & current_note_num) when (TB = "010" and ASR = x"0000007F") else
        unsigned(x"000000" & "0" & current_note_num) when (TB = "010" and ASR = x"0000007F" and current_note_on = '1') else
        (others => '0')                              when (TB = "010" and ASR = x"0000007F" and current_note_on = '0') else

        PM when (TB = "010") else
        "0000000000000000000000" & PC when (TB = "011") else
        AR when (TB = "100") else
        -- Registerläsning direkt ut på bussen:
        GR0 when (TB = "110" and S = '0' and GRx = "00") else
        GR1 when (TB = "110" and S = '0' and GRx = "01") else
        GR2 when (TB = "110" and S = '0' and GRx = "10") else
        GR3 when (TB = "110" and S = '0' and GRx = "11") else
        GR3 when (TB = "110" and S = '1' and M = "11") else
        (others => '0');
					
	
end architecture;
