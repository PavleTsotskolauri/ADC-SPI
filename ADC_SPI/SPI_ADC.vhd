Library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


entity SPI_ADC is
 generic (	data_length		: integer := 11;
		state_timer		: integer := 45			 
);
 port ( 	-- system signals:
			clk, rst		: in std_logic;	-- 25MHz clock
			rd_wr			: in std_logic;	-- Read/Write Pin
			ADC_data		: out std_logic_vector(11 downto 0);	-- Indication For ADC Value
			-- SPI interface
			SCK			: out std_logic;	-- SPI clock
			MOSI			: out std_logic;	-- SPI Master Output Slave Input
			MISO			: in 	std_logic;	-- SPI Master Input	Slave Output
			SS				: out std_logic;	-- SPI Slave Select
			-- Seven Segment Display Ports
			hex0			: out std_logic_vector(6 downto 0);
			hex1			: out std_logic_vector(6 downto 0);
			hex2			: out std_logic_vector(6 downto 0);
			hex3			: out std_logic_vector(6 downto 0)
			);
end SPI_ADC;


architecture SPI of SPI_ADC is

	-- ADC Commands
	CONSTANT ADC_CH0	: std_logic_vector(data_length downto 0)	:= "100010000000";-- ADC Channel 0
	CONSTANT ADC_CH1	: std_logic_vector(data_length downto 0)	:= "110010000000";-- ADC Channel 1
	CONSTANT ADC_CH2	: std_logic_vector(data_length downto 0)	:= "100110000000";-- ADC Channel 2
	CONSTANT ADC_CH3	: std_logic_vector(data_length downto 0)	:= "110110000000";-- ADC Channel 3
	CONSTANT ADC_CH4	: std_logic_vector(data_length downto 0)	:= "101010000000";-- ADC Channel 4
	CONSTANT ADC_CH5	: std_logic_vector(data_length downto 0)	:= "111010000000";-- ADC Channel 5
	CONSTANT ADC_CH6	: std_logic_vector(data_length downto 0)	:= "101110000000";-- ADC Channel 6
	CONSTANT ADC_CH7	: std_logic_vector(data_length downto 0)	:= "111110000000";-- ADC Channel 7
	
	-- FSM States
	type state is (idle, CONVST, wait_rd_wr, rd_wr_data);			-- FSM State
	signal PS, NS	: state;
	
	-- General Signals
	signal data_in 				: std_logic_vector(data_length downto 0);	-- ADC data
	signal aux_clk					: std_logic;										-- Auxilary Clock
	SIGNAL timer					: natural range 0 to state_timer;			-- timer for FSM
	shared variable i				: natural range 0 to state_timer;	
	signal std2integer			: integer range 0 to 2**12 - 1;				-- signal for std_logic_vector to integer conversion
	
	-- ADC Value on Seven Segment Display
function ssd (input : integer) 																		-- seven segment display (SSD) driver function
return std_logic_vector is
variable output : std_logic_vector(6 downto 0);								
begin 
	case input is																								
		when 0 				=> output			:= "1000000"; -- 0
		when 1				=> output			:= "1111001"; -- 1
		when 2				=> output			:= "0100100"; -- 2
		when 3				=> output			:= "0110000"; -- 3
		when 4				=> output			:= "0011001"; -- 4
		when 5				=> output			:= "0010010"; -- 5
		when 6				=> output			:= "0000010"; -- 6
		when 7				=> output			:= "1111000"; -- 7
		when 8				=> output 			:= "0000000"; -- 8
		when 9				=> output 			:= "0010000"; -- 9
		when others 		=> output 			:= "1111111"; -- OFF
	end case;
	return output;
end ssd;

begin
	-- Auxilary Clock
	process (clk)
		variable counter : natural;
	begin
		if (clk'event and clk = '1') then
			if(counter = 25) then
				counter := 0;
				aux_clk <= NOT aux_clk;
			else
				counter := counter + 1;
			end if;
		end if;
		
	end process;

	-- Lower Section of FSM
	process (aux_clk, rst)
	begin
		if(rst = '0') then	-- reset
			PS <= idle;
			i 	:= 0;
			data_in <= (others => '0');
		-- Send data to SPI bus:
		elsif (aux_clk'event AND aux_clk = '1') then	-- rising_edge
			if (i= timer-1) then
				PS <= NS;
				i	:= 0;
			else
				i 	:= i + 1;
			end if;
		-- Read data from SPI bus:
		elsif (aux_clk'event AND aux_clk = '0') then
			if(PS = rd_wr_data) then		
				data_in(11-i) <= MISO;		
			end if;
		end if;
	end process;
	
	-- Upper Section of FSM
	process (PS, aux_clk, rd_wr)
	begin	
		case PS is
			when idle =>
				SS		<= '0';
				SCK		<= '0';
				MOSI		<= 'U';
				timer 	<= 1;
				if (rd_wr = '0') then
					NS <= CONVST;
				else
					NS <= idle;
				end if;
			when CONVST =>
				SS		<= '1';
				SCK	<= '0';
				MOSI	<= 'U';
				timer <= 1;
				NS 	<= wait_rd_wr;
			when wait_rd_wr =>
				SS		<= '0';
				SCK	<= '0';
				MOSI	<= 'U';
				timer	<= 40;
				NS		<= rd_wr_data;
			when rd_wr_data =>
				SS		<= '0';
				SCK	<= NOT aux_clk;
				MOSI	<= ADC_CH5(11-i);
				timer	<= 12;
				NS <= idle;
			when others =>
				SS		<= '0';
				SCK	<= '0';
				MOSI	<= 'U';
				timer <= 1;
				NS <= idle;				
		end case;
	end process;
	ADC_data			<= data_in;
	std2integer <= to_integer(unsigned(data_in));
	hex0 			<= ssd(std2integer MOD 10);
	hex1 			<= ssd((std2integer / 10) MOD 10);
	hex2			<= ssd((std2integer / 100) MOD 10);
	hex3			<= ssd((std2integer / 1000));

end SPI;
