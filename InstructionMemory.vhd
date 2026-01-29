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

    -- IMEM: word-aligned constants (hex machine words)
    -- Program:
    -- 0: addi x1, x0, 8      -> 0x00800093
    -- 1: addi x2, x0, 42     -> 0x02A00113
    -- 2: sw   x2, 0(x1)      -> 0x0020A023
    -- 3: lw   x3, 0(x1)      -> 0x0000A183
    -- 4: addi x4, x0, 0      -> 0x00000213
    constant IMEM : mem_type := (
        0 => x"00800093",
        1 => x"02A00113",
        2 => x"0020A023",
        3 => x"0000A183",
        4 => x"00000213",
        others => (others => '0')
    );

begin
    -- select word by PC[9:2] (256 words)
    Instr <= IMEM(to_integer(unsigned(addr(9 downto 2))));
end architecture;
