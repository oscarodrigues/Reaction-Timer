library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reactiontimer is
port(
		clk, reset, start, response : in std_logic;
		a3, a2, a1, a0, s : out std_logic_vector(6 downto 0);
		done : out std_logic
		);
end entity reactiontimer;

architecture behavioural of reactiontimer is

type state_type is (s0, s1, s2, s3, s4);
signal state : state_type;

signal dividedclk_s : std_logic := '1';
signal dividedclk_ms : std_logic :='1';

signal avgtime : std_logic_vector(15 downto 0);
signal reactiontime : std_logic_vector(15 downto 0);
signal C : std_logic_vector(4 downto 0) := "11101";

signal address : integer := 0;

signal display : std_logic_vector(15 downto 0) := "0000000000000000";

type memory_array is array (0 to 29) of std_logic_vector(3 downto 0);
signal memory : memory_array :=	 ( "1111",  -- f 
												"1010",  -- a
												"1001",  -- 9
												"1011",  -- b
												"1100",  -- c
												"1110",  -- e
												"1001",  -- 9
												"1000",  -- 8
												"0111",  -- 7
												"1001",  -- 9
												"0101",  -- 5
												"0001",  -- 1
												"1001",  -- 9
												"1010",  -- a
												"1101",  -- d
												"1100",  -- b
												"1001",  -- 9
												"1111",  -- f
												"0110",  -- 6
												"0011",  -- 3
												"1001",  -- 9
												"0110",  -- 6
												"1010",  -- a
												"1100",  -- c
												"1001",  -- 9
												"1010",  -- a
												"0111",  -- 7
												"1011",  -- b
												"0001",  -- 1
												"1001"); -- 9

-------------------------------
-- BINARY TO BCD TRANSLATION --
-------------------------------

function to_bcd (bin : std_logic_vector(15 downto 0) := "0000000000000000") return std_logic_vector is

variable i : integer := 0;
variable thousands : unsigned (3 downto 0) := "0000";
variable hundreds : unsigned (3 downto 0) := "0000";
variable tens : unsigned(3 downto 0)  := "0000";
variable ones : unsigned(3 downto 0)  := "0000";
variable datain : unsigned(15 downto 0) := unsigned(bin);
variable bcdout : std_logic_vector(15 downto 0);

begin

for i in 15 downto 0 loop
	if (thousands > "0101" or thousands = "0101") then
		thousands := thousands + 3;
	end if;
	if (hundreds > "0101" or hundreds = "0101") then
		hundreds := hundreds + 3;
	end if;
	if (tens > "0101" or tens = "0101") then
		tens := tens + 3;
	end if;
	if (ones > "0101" or ones = "0101") then
		ones := ones + 3;
	end if;
	thousands(3 downto 1) := thousands(2 downto 0);
	thousands(0) := hundreds(3);
	hundreds(3 downto 1) := hundreds(2 downto 0);
	hundreds(0) := tens(3);
	tens(3 downto 1) := tens(2 downto 0);
	tens(0) := ones(3);
	ones(3 downto 1) := ones(2 downto 0);
	ones(0) := datain(i);
end loop;
bcdout := (std_logic_vector(thousands) & std_logic_vector(hundreds) & std_logic_vector(tens) & std_logic_vector(ones));
return bcdout;
end function;
												
begin

---------------------------------
-- STATE CHANGING (SECONDS) --
---------------------------------

state_changing_ms : process (reset, dividedclk_s, state, start, address, response, C)
	begin
		if (reset = '1') then
			state <= s0;
		elsif (dividedclk_s' event and dividedclk_s = '1') then
			case (state) is
			when s0 =>
				if (start = '0') then
					state <= s1;
				else
					state <= s0;
				end if;
			when s1 =>
				if (address = 1 or address = 5 or address = 8 or address = 11 or address = 15 or address = 19 or address = 23 or address = 28) then
					state <= s2;
				else
					state <= s3;
				end if;
			when s2 =>
				if (response = '0') then
					state <= s3;
				end if;
			when s3 =>
				if (C = "00000") then
					state <= s4;
				else
					state <= s1;
				end if;
			when s4 =>
				state <= s0;
			when others =>
				state <= s0;
			end case;
		end if;
	end process;
	
------------------------------------
-- REACTION TIMER (SECONDS) --
------------------------------------

reactiontiming_ms : process (reset, dividedclk_s, state, start, response)
	begin
		if (reset = '1') then
			address <= 0;
			C <= "11101";
			done <= '0';
		elsif (dividedclk_s' event and dividedclk_s = '1') then
			case (state) is
			when s0 => 
				if (start = '0') then
					address <= 0;
					C <= "11101";
					done <= '0';
				end if;
			when s1 =>
					address <= address + 1;
			when s2 =>
			when s3 => 
				C <= std_logic_vector(unsigned(C) - 1);
			when s4 =>
				done <= '1';
			end case;
		end if;
	end process;
	
------------------------------------
-- REACTION TIMER (MILLISECONDS) --
------------------------------------

reactiontiming_s : process (reset, dividedclk_ms, state, reactiontime)
	begin
		if (reset = '1') then
			reactiontime <= "0000000000000000";
			avgtime <= "0000000000000000";
			display <= to_bcd(bin => reactiontime);
		elsif (dividedclk_ms' event and dividedclk_ms = '1') then
			case (state) is
			when s0 =>
				if (start = '0') then
					reactiontime <= "0000000000000000";
					avgtime <= "0000000000000000";
				end if;
			when s1 =>
			when s2 =>
				if (response = '1') then
					reactiontime <= std_logic_vector(unsigned(reactiontime) + 1);
				end if;
				display <= to_bcd(bin => reactiontime);
			when s3 =>
			when s4 =>
				avgtime <= "000" & reactiontime(15 downto 3);
				display <= to_bcd(bin => avgtime);
			end case;
		end if;
	end process;

----------------
-- CLOCK (ms) --
----------------

clkdivider_ms: process (clk)
variable count_ms : integer := 0;
	begin
		if (clk'event and clk = '1') then
			if (count_ms = 25000) then
				dividedclk_ms <= not dividedclk_ms;
				count_ms := 0;
			else
				count_ms := count_ms + 1;
			end if;
		end if;
	end process;
	
---------------
-- CLOCK (s) --
---------------

clkdivider_s : process (dividedclk_ms)
variable count_s : integer := 0;
	begin
		if (dividedclk_ms'event and dividedclk_ms = '1') then
			if (count_s = 100) then
				dividedclk_s <= not dividedclk_s;
				count_s := 0;
			else
				count_s := count_s + 1;
			end if;
		end if;
	end process;
	
---------------------
-- 7SD TRANSLATION --
---------------------
		
with display(15 downto 12) select
a3 <= 		"1000000" when "0000",
				"1111001" when "0001",
				"0100100" when "0010",
				"0110000" when "0011",
				"0011001" when "0100",
				"0010010" when "0101",
				"0000010" when "0110",
				"1111000" when "0111",
				"0000000" when "1000",
				"0010000" when "1001",
				"0001000" when "1010",
				"0000011" when "1011",
				"1000110" when "1100",
				"0100001" when "1101",
				"0000110" when "1110",
				"0001110" when "1111",
				"0111111" when others;

with display(11 downto 8) select
a2 <= 		"1000000" when "0000",
				"1111001" when "0001",
				"0100100" when "0010",
				"0110000" when "0011",
				"0011001" when "0100",
				"0010010" when "0101",
				"0000010" when "0110",
				"1111000" when "0111",
				"0000000" when "1000",
				"0010000" when "1001",
				"0001000" when "1010",
				"0000011" when "1011",
				"1000110" when "1100",
				"0100001" when "1101",
				"0000110" when "1110",
				"0001110" when "1111",
				"0111111" when others;
				
with display(7 downto 4) select
a1 <= 		"1000000" when "0000",
				"1111001" when "0001",
				"0100100" when "0010",
				"0110000" when "0011",
				"0011001" when "0100",
				"0010010" when "0101",
				"0000010" when "0110",
				"1111000" when "0111",
				"0000000" when "1000",
				"0010000" when "1001",
				"0001000" when "1010",
				"0000011" when "1011",
				"1000110" when "1100",
				"0100001" when "1101",
				"0000110" when "1110",
				"0001110" when "1111",
				"0111111" when others;

with display(3 downto 0) select
a0 <= 		"1000000" when "0000",
				"1111001" when "0001",
				"0100100" when "0010",
				"0110000" when "0011",
				"0011001" when "0100",
				"0010010" when "0101",
				"0000010" when "0110",
				"1111000" when "0111",
				"0000000" when "1000",
				"0010000" when "1001",
				"0001000" when "1010",
				"0000011" when "1011",
				"1000110" when "1100",
				"0100001" when "1101",
				"0000110" when "1110",
				"0001110" when "1111",
				"0111111" when others;

with memory(address) select
s <=  		"1000000" when "0000",
				"1111001" when "0001",
				"0100100" when "0010",
				"0110000" when "0011",
				"0011001" when "0100",
				"0010010" when "0101",
				"0000010" when "0110",
				"1111000" when "0111",
				"0000000" when "1000",
				"0010000" when "1001",
				"0001000" when "1010",
				"0000011" when "1011",
				"1000110" when "1100",
				"0100001" when "1101",
				"0000110" when "1110",
				"0001110" when "1111",
				"0111111" when others;					
				
end architecture behavioural;