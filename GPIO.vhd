library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity GPIO is
    port(
        clk     : in  STD_LOGIC;
        wr_en   : in  STD_LOGIC;
        wr_addr : in  STD_LOGIC_VECTOR(31 downto 0);
        wr_data : in  STD_LOGIC_VECTOR(31 downto 0);
        rd_en   : in  STD_LOGIC;
        rd_addr : in  STD_LOGIC_VECTOR(31 downto 0);
        rd_data : out STD_LOGIC_VECTOR(31 downto 0);
        leds    : out STD_LOGIC_VECTOR(7 downto 0);
        buttons : in  STD_LOGIC_VECTOR(7 downto 0)
    );
end entity;

architecture behave of GPIO is
    constant LED_ADDR    : STD_LOGIC_VECTOR(31 downto 0) := x"00000008";
    constant BUTTON_ADDR : STD_LOGIC_VECTOR(31 downto 0) := x"0000000C";

    signal LED_reg : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal rd_data_reg: STD_LOGIC_VECTOR(31 downto 0) := (others => '0');

begin
    -- synchronous write to LED register on rising edge
    process(clk)
    begin
        if rising_edge(clk) then
            if wr_en = '1' and wr_addr = LED_ADDR then
                LED_reg <= wr_data(7 downto 0);
            end if;
        end if;
    end process;

    -- combinational read
    process(rd_en, rd_addr, LED_reg, buttons)
    begin
        if rd_en = '1' and rd_addr = BUTTON_ADDR then
            rd_data_reg <= (31 downto 8 => '0') & buttons;
        else
            rd_data_reg <= (others => '0');
        end if;
    end process;

    rd_data <= rd_data_reg;
    leds <= LED_reg;
end architecture;
