library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity InstructionMemory is
    port(
        addr  : in  std_logic_vector(31 downto 0); -- byte address
        Instr : out std_logic_vector(31 downto 0)
    );
end entity;

architecture behave of InstructionMemory is
    type mem_type is array(0 to 255) of std_logic_vector(31 downto 0);
	 
--		constant IMEM : mem_type := (	
--    0 => x"00A00093", -- addi x1, x0, 10      setup x1
--    1 => x"00300113", -- addi x2, x0, 3       setup x2
--    2 => x"002081B3", -- add  x3, x1, x2
--    3 => x"40110233", -- sub  x4, x2, x1
--	 4 => x"00A00293", -- addi x5, x0, 10
--    5 => x"00508463", -- beq  x1, x5, 8    
--    6 => x"06300193", -- addi x3, x0, 99      skipped
--    others => (others => '0')
	 
	 constant IMEM : mem_type := (
    0  => x"00800093", -- addi x1, x0, 8    
    1  => x"02A00113", -- addi x2, x0, 42   
    2  => x"0020A023", -- sw   x2, 0(x1)    
    3  => x"0020A223", -- sw   x2, 4(x1)    
    4  => x"0000A183", -- lw   x3, 0(x1)   
    5  => x"0040A203", -- lw   x4, 4(x1)   
    others => (others => '0')
);

begin
    -- select word by PC[9:2] (256 words)
    Instr <= IMEM(to_integer(unsigned(addr(9 downto 2))));
end architecture;
