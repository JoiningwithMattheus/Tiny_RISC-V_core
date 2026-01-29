library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity Regfile is
    port(
        clk : in  std_logic;
        a1  : in  std_logic_vector(4 downto 0);  
        a2  : in  std_logic_vector(4 downto 0);
        a3  : in  std_logic_vector(4 downto 0);  
        we3 : in  std_logic;
        wd3 : in  std_logic_vector(31 downto 0);
        rd1 : out std_logic_vector(31 downto 0);
        rd2 : out std_logic_vector(31 downto 0)
    );
end entity;


architecture behave of regfile is
    type ramtype is array (31 downto 0) of std_logic_vector(31 downto 0);
    signal mem : ramtype;

    signal wb_en   : std_logic := '0';
    signal wb_addr : std_logic_vector(4 downto 0) := (others => '0');
    signal wb_data : std_logic_vector(31 downto 0) := (others => '0');
begin

    -- write-back register
    process(clk)
    begin
        if rising_edge(clk) then
            wb_en   <= we3;
            wb_addr <= a3;
            wb_data <= wd3;

            if we3 = '1' and a3 /= "00000" then
                mem(to_integer(unsigned(a3))) <= wd3;
            end if;
        end if;
    end process;

    -- read with forwarding from previous write
    process(all)
    begin
        -- RD1
        if a1 = "00000" then
            rd1 <= (others => '0');
        elsif wb_en = '1' and a1 = wb_addr then
            rd1 <= wb_data;
        else
            rd1 <= mem(to_integer(unsigned(a1)));
        end if;

        -- RD2
        if a2 = "00000" then
            rd2 <= (others => '0');
        elsif wb_en = '1' and a2 = wb_addr then
            rd2 <= wb_data;
        else
            rd2 <= mem(to_integer(unsigned(a2)));
        end if;
    end process;
end architecture;
