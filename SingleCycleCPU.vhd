library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SingleCycleCPU is
    port(
        clk  : in  std_logic;
        leds : out std_logic_vector(7 downto 0);
        buttons : in std_logic_vector(7 downto 0);

        PC_out      : out std_logic_vector(31 downto 0);
        Instr_out   : out std_logic_vector(31 downto 0);
        Result_out  : out std_logic_vector(31 downto 0)
    );
end entity;

architecture behave of SingleCycleCPU is

    signal PC    : std_logic_vector(31 downto 0) := (others => '0');
    signal Instr : std_logic_vector(31 downto 0);

    -- instruction fields
    signal opcode : std_logic_vector(6 downto 0);
    signal funct3 : std_logic_vector(2 downto 0);
    signal funct7 : std_logic_vector(6 downto 0);
    signal rs1, rs2, rd : std_logic_vector(4 downto 0);

    -- MainControl
    signal RegWrite : std_logic;
    signal ALUSrc   : std_logic;
    signal ALUE     : std_logic;
    signal Branch   : std_logic;
    signal Branchop : std_logic_vector(1 downto 0);
    signal MemWrite : std_logic;
    signal ResSrc   : std_logic; -- 1 = memory -> writeback

    -- register file wires
    signal rd1, rd2 : std_logic_vector(31 downto 0);

    -- immediate forms
    signal imm_I : std_logic_vector(31 downto 0);
    signal imm_S : std_logic_vector(31 downto 0);
    signal imm_B_signed : signed(31 downto 0);

    -- ALU
    signal B_sel : std_logic_vector(31 downto 0);
    signal ALUOp_internal : std_logic_vector(3 downto 0);
    signal ALU_result : std_logic_vector(31 downto 0);
    signal Zero_sig : std_logic;

    -- Memory
    signal MemReadData : std_logic_vector(31 downto 0);
    signal WriteBack : std_logic_vector(31 downto 0);

begin

    -- Instruction memory instance
    IMEM_inst: entity work.InstructionMemory
        port map(
            addr  => PC,
            Instr => Instr
        );

    Instr_out <= Instr;

    -- decode fields
    opcode <= Instr(6 downto 0);
    funct3 <= Instr(14 downto 12);
    rs1 <= Instr(19 downto 15);
    rs2 <= Instr(24 downto 20);
    rd  <= Instr(11 downto 7);
    funct7 <= Instr(31 downto 25);

    -- immediate extraction
    imm_I <= std_logic_vector(resize(signed(Instr(31 downto 20)), 32));
    imm_S <= std_logic_vector(resize(signed(Instr(31 downto 25) & Instr(11 downto 7)), 32));
    imm_B_signed <= resize(signed(Instr(31) & Instr(7) & Instr(30 downto 25) & Instr(11 downto 8) & '0'), 32);

	 -- Main Control
    MainControl_inst: entity work.MainControl
        port map(
            opcode => opcode,
            RegWrite => RegWrite,
            ALUSrc => ALUSrc,
            ALUE => ALUE,
            Branch => Branch,
            Branchop => Branchop,
            MemWrite => MemWrite,
            ResSrc => ResSrc,
            funct3 => funct3
        );

    -- Register file 
    RF_inst: entity work.Regfile
        port map(
            clk => clk,
            a1  => rs1,
            a2  => rs2,
            a3  => rd,
            we3 => RegWrite,
            wd3 => WriteBack,
            rd1 => rd1,
            rd2 => rd2
        );

    -- select B input for ALU (immediate or rd2)
		B_sel <= imm_S when (ALUSrc = '1' and opcode = "0100011") else
				imm_I when (ALUSrc = '1') else
				rd2;


    -- ALU control 
    ALUControl_inst: entity work.ALUControl
        port map(
            funct7 => funct7,
            funct3 => funct3,
            ALUE   => ALUE,
            ALUOp  => ALUOp_internal,
            isBranch => Branch
        );

    -- ALU extended w3
    ALU_inst: entity work.ALUextended
        port map(
            A => rd1,
            B => B_sel,
            ALUOp => ALUOp_internal,
            Result => ALU_result,
            Zero => Zero_sig
        );

    Result_out <= ALU_result;

    -- Data memory
    DMEM_inst: entity work.DataMemory
        port map(
            clk => clk,
            addr => ALU_result,
            wd => rd2,
            we => MemWrite,
            rd => MemReadData,
            leds_out => leds,
            buttons_in => buttons
        );

    -- write back selection (ResSrc == 1 => from memory)
    WriteBack <= MemReadData when ResSrc = '1' else ALU_result;

    -- PC update (BEQ when Branchop="01", BNE when "10")
    process(clk)
    begin
        if rising_edge(clk) then
            if Branch = '1' then
                if Branchop = "01" and Zero_sig = '1' then          -- BEQ
                    PC <= std_logic_vector( signed(PC) + imm_B_signed );
                elsif Branchop = "10" and Zero_sig = '0' then       -- BNE
                    PC <= std_logic_vector( signed(PC) + imm_B_signed );
                else
                    PC <= std_logic_vector( signed(PC) + to_signed(4,32) );
                end if;
            else
                PC <= std_logic_vector( signed(PC) + to_signed(4,32) );
            end if;
        end if;
    end process;

    PC_out <= PC;

end architecture;
