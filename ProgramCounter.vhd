library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity ProgramCounter is
    port(
        clk        : in  STD_LOGIC;
        Zero       : out STD_LOGIC;
        Result_out : out STD_LOGIC_VECTOR(31 downto 0);
		  PC_out : out std_logic_vector(31 downto 0);
		  WriteBack : out std_logic_vector(31 downto 0);
		  leds : out std_logic_vector(7 downto 0)
    );
end entity;
architecture behave of ProgramCounter is

    type mem_type is array(0 to 255) of std_logic_vector(31 downto 0);
--    constant IMEM : mem_type := (
--	 
--        0 => "000000000101" & "00000" & "000" & "00001" & "0010011",
--        1 => "000000000101" & "00000" & "000" & "00010" & "0010011",
--        2 => "0" & "000000" & "00010" & "00001" & "000" & "0100" & "0" & "1100011",
--        3 => "000000000001" & "00000" & "000" & "00011" & "0010011",
--        4 => "000000000010" & "00000" & "000" & "00011" & "0010011",
--        others => (others => '0')
--    );

--		constant IMEM : mem_type := (
--			0 => "000000001000" & "00000" & "000" & "00001" & "0010011",  -- addi x1,x0,8
--			1 => "000000001111" & "00000" & "000" & "00010" & "0010011",  -- addi x2,x0,15
--			2 => "0000000" & "00010" & "00000" & "010" & "00000" & "0100011", -- sw x2,0(x1)
--			3 => "000000000000" & "00000" & "010" & "00100" & "0000011", -- lw x4,0(x3)
--			4 => "0000000" & "00010" & "00011" & "010" & "00000" & "0100011", -- sw x2,0(x3)
--			5 => "000000000000" & "00011" & "010" & "00100" & "0000011", -- lw x4,0(x3)
--			6 => "000000000011" & "00000" & "000" & "00101" & "0010011", -- addi x5,x0,3
--			others => (others => '0')

--		constant IMEM : mem_type := (
--			0 => "000000001000" & "00000" & "000" & "00001" & "0010011",  -- addi x1,x0,8
--			1 => "000000001010" & "00000" & "000" & "00010" & "0010011",  -- addi x2,x0,10
--			2 => "0000000" & "00010" & "00001" & "100" & "00011" & "0110011", -- R-XOR x3, x1, x2
--			3 => "000000011001" & "00000" & "110" & "00100" & "0010011", -- ori x4, x0, 25 
--			4 => "0" & "000000" & "00010" & "00001" & "001" & "0100" & "0" & "1100011", -- bne x1, x2, +8
--			5 => "000000011111" & "00000" & "000" & "00011" & "0010011", -- 
--			6 => "000000011000" & "00000" & "000" & "00011" & "0010011",
--			others => (others => '0')
--);

	constant IMEM : mem_type := (
  0 => "000000001000" & "00000" & "000" & "00001" & "0010011",  -- addi x1, x0, 8
  1 => "000000101010" & "00000" & "000" & "00010" & "0010011",  -- addi x2, x0, 42
  -- sw x2,0(x1)  -> S-type: imm[11:5] rs2 rs1 funct3 imm[4:0] opcode
  2 => "0000000" & "00010" & "00001" & "010" & "00000" & "0100011",
  3 => "000000000000" & "00001" & "010" & "00011" & "0000011",  -- lw x3,0(x1)
  4 => "000000000000" & "00000" & "000" & "00100" & "0010011",  -- addi x4,x0,0
  others => (others => '0')
);

    signal PC       : std_logic_vector(31 downto 0) := (others => '0');
    signal Instr    : std_logic_vector(31 downto 0);
    signal Branch   : std_logic;
    signal BranchImm: signed(31 downto 0);
	 signal Branchop : std_logic_vector(1 downto 0);

begin
    Instr <= IMEM(to_integer(unsigned(PC(9 downto 2))));

    CPU: entity work.R_Type_CPU
        port map(
            clk        => clk,
            Instr      => Instr,
            Zero       => Zero,
            Result_out => Result_out,
            Branch     => Branch,
            BranchImm  => BranchImm,
				WriteBack_out => WriteBack,
				Branchop => Branchop,
				leds => leds
        );
process(clk)
begin
    if rising_edge(clk) then
	     if Branch = '1' then 
				if Branchop = "01" and Zero = '1' then -- BEQ
					PC <= std_logic_vector( signed(PC) + BranchImm );
				elsif Branchop = "10" and Zero = '0' then -- BNE
				   PC <= std_logic_vector( signed(PC) + BranchImm );
				else
					PC <= std_logic_vector( signed(PC) + to_signed(4, 32) );
				end if;
        else
            PC <= std_logic_vector( signed(PC) + to_signed(4, 32) );
        end if;
    end if;
end process;
PC_out <= PC;

end architecture;
