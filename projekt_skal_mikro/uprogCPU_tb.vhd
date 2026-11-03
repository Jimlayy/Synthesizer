LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY uprogCPU_tb IS
END uprogCPU_tb;

ARCHITECTURE func OF uprogCPU_tb IS

  --Component Declaration for the Unit Under Test (UUT)
  COMPONENT uprogCPU
  PORT(clk: in std_logic;
       btnC : in std_logic;     -- reset button (middle of the five), active high
       JC : in std_logic_vector(7 downto 0);
       JB : out std_logic_vector(7 downto 0);
       led : out unsigned(15 downto 0));
  END COMPONENT;

  --Inputs
  signal clk : std_logic:= '0';
  signal rst : std_logic:= '0';
  signal JC : std_logic_vector(7 downto 0) := "00000000";
  signal JB : std_logic_vector(7 downto 0) := (others => '0');
  signal led : unsigned(15 downto 0) := (others => '0');

  --Clock period definitions
  constant clk_period : time:= 10 ns; -- 100 MHz

BEGIN
  -- Instantiate the Unit Under Test (UUT)
  uut: uprogCPU PORT MAP (
    clk => clk,
    btnC => rst,
    JC => JC,
    JB => JB,
    led => led
  );
		
  -- Clock process definitions
  clk_process :process
  begin
    clk <= '0';
    wait for clk_period/2;
    clk <= '1';
    wait for clk_period/2;
  end process;

	rst <= '1', '0' after 17 ns;

  stimulus_process : process
  begin
    -- 1. Let the system idle at '1' for a bit after reset clears
    JC(3) <= '1';
    wait for 50 us;
    -- Initiera ledningen (Idle är '1' i UART)
    -- Skicka 0x90 (Binärt: 1001 0000)
    -- OBS: UART skickar LSB (minst signifikanta biten) först!
    JC(3) <= '0'; wait for 32 us;  -- STARTBIT (alltid 0)

    JC(3) <= '0'; wait for 32 us;  -- Bit 0
    JC(3) <= '0'; wait for 32 us;  -- Bit 1
    JC(3) <= '0'; wait for 32 us;  -- Bit 2
    JC(3) <= '0'; wait for 32 us;  -- Bit 3
    JC(3) <= '1'; wait for 32 us;  -- Bit 4
    JC(3) <= '0'; wait for 32 us;  -- Bit 5
    JC(3) <= '0'; wait for 32 us;  -- Bit 6
    JC(3) <= '1'; wait for 32 us;  -- Bit 7 (MSB)

    JC(3) <= '1'; wait for 32 us;  -- STOPPBIT (alltid 1)

-- Nu kommer data_rdy blinka till, data_out kommer vara 0x90, 
-- och tillståndsmaskinen kommer hoppa till WAIT_NOTE!
    -- 2. Send START BIT ('0')
    JC(3) <= '0';
    wait for 32 us;
    
    -- 3. Send DATA BITS (LSB first for UART: 0x45 is "01000101")
    JC(3) <= '1'; wait for 32 us; -- Bit 0
    JC(3) <= '0'; wait for 32 us; -- Bit 1
    JC(3) <= '1'; wait for 32 us; -- Bit 2
    JC(3) <= '0'; wait for 32 us; -- Bit 3
    JC(3) <= '0'; wait for 32 us; -- Bit 4
    JC(3) <= '1'; wait for 32 us; -- Bit 5
    JC(3) <= '0'; wait for 32 us; -- Bit 6
    JC(3) <= '0'; wait for 32 us; -- Bit 7
    -- 4. Send STOP BIT ('1')
    JC(3) <= '1';
    wait for 32 us;
    
    -- Lägg in en liten paus mellan byten (frivilligt, men simulerar verkligheten)
    wait for 50 us;

    -- 2. Send START BIT ('0')
    JC(3) <= '0';
    wait for 32 us;
    
    -- 3. Send DATA BITS (LSB first for UART: 0x40 is "01000000")
    JC(3) <= '0'; wait for 32 us; -- Bit 0
    JC(3) <= '0'; wait for 32 us; -- Bit 1
    JC(3) <= '0'; wait for 32 us; -- Bit 2
    JC(3) <= '0'; wait for 32 us; -- Bit 3
    JC(3) <= '0'; wait for 32 us; -- Bit 4
    JC(3) <= '0'; wait for 32 us; -- Bit 5
    JC(3) <= '1'; wait for 32 us; -- Bit 6
    JC(3) <= '0'; wait for 32 us; -- Bit 7
    
    -- 4. Send STOP BIT ('1')
    JC(3) <= '1';
    wait for 32 us;

-- Nu har hela "Note On"-meddelandet tagits emot!
-- note_on kommer att slå om till '1', note_num blir 0x45 och velocity blir 0x40.
    -- Keep idling
    wait;
    end process;
END;

