library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity R_Type_CPU is
    port(
        clk   : in  STD_LOGIC;
        Instr : in  STD_LOGIC_VECTOR(31 downto 0);
        Zero  : out STD_LOGIC;
		  Result_out : out STD_LOGIC_VECTOR(31 downto 0);
		  Branch : out STD_LOGIC;
--		  BranchImm  : out STD_LOGIC_VECTOR(31 downto 0)
		  BranchImm  : out signed(31 downto 0);
		  WriteBack_out : out std_logic_vector(31 downto 0);
		  Branchop : out STD_LOGIC_VECTOR(1 downto 0);
		  leds : out STD_LOGIC_VECTOR(7 downto 0)
    );
end R_Type_CPU;

architecture behave of R_Type_CPU is

    -- RISC-V fields
    signal opcode  : STD_LOGIC_VECTOR(6 downto 0);  -- Instr[6:0]
    signal funct7  : STD_LOGIC_VECTOR(6 downto 0);  -- Instr[31:25]
    signal funct3  : STD_LOGIC_VECTOR(2 downto 0);  -- Instr[14:12]
    signal rs1, rs2, rd : STD_LOGIC_VECTOR(4 downto 0); -- rs1: Instr[19:15], rs2: Instr[24:20], rd: Instr[11:7]

    -- control signals
    signal RegWrite : STD_LOGIC;
    signal ALUSrc   : STD_LOGIC;
    signal ALUE     : STD_LOGIC;
    signal ALUOp    : STD_LOGIC_VECTOR(3 downto 0);
	 
	 -- B-Type
	 signal BranchCtrl : std_logic;

    -- datapath
    signal rd1, rd2 : STD_LOGIC_VECTOR(31 downto 0);
    signal result   : STD_LOGIC_VECTOR(31 downto 0);
    signal zero_sig : STD_LOGIC;

    -- immediate and ALU B input
    signal imm      : std_logic_vector(31 downto 0);
	 signal imm_I    : std_logic_vector(31 downto 0);
	 signal imm_S    : std_logic_vector(31 downto 0);
    signal B_sel    : std_logic_vector(31 downto 0);
	 
	 -- Memory Data
	 signal MemReadData : std_logic_vector(31 downto 0);
	 signal MemWrite : std_logic;
	 signal ResSrc : std_logic; -- 0 = ALU, 1 = MEM
	 signal WriteBack : std_logic_vector(31 downto 0);
	 
	 signal leds_sig : std_logic_vector(7 downto 0);

begin

    opcode <= Instr(6 downto 0);
    rd     <= Instr(11 downto 7);
    funct3 <= Instr(14 downto 12);
    rs1    <= Instr(19 downto 15);
    rs2    <= Instr(24 downto 20);
    funct7 <= Instr(31 downto 25);

    imm_I <= std_logic_vector (resize (signed(Instr(31 downto 20)), 32));
	 
	 imm_S <= std_logic_vector (resize (signed(Instr(31 downto 25) & Instr(11 downto 7)), 32));

	 imm <= imm_I when opcode = "0000011" or opcode = "0010011" else
			  imm_S when opcode = "0100011" else
			  (others => '0');
    -- register RD2 or sign-extended IMMEDIATE
    B_sel <= imm when ALUSrc = '1' else rd2;
 
--    BranchImm <= std_logic_vector(
--                resize(signed(Instr(31) & Instr(7) & Instr(30 downto 25) & Instr(11 downto 8) & '0'), 32));
BranchImm <= resize(signed( Instr(31) & Instr(7) & Instr(30 downto 25) & Instr(11 downto 8) & '0' ), 32);


    Control_Unit: entity work.MainControl
        port map(
            opcode   => opcode,
            RegWrite => RegWrite,
            ALUSrc   => ALUSrc,
            ALUE     => ALUE,
				Branch   => BranchCtrl,
				MemWrite => Memwrite,
				ResSrc => ResSrc,
				funct3 => funct3,
				Branchop => Branchop
        );
	 DataMem: entity work.DataMemory
		  port map(
				clk => clk,
				addr => result,
				wd => rd2,
				we => MemWrite,
				rd => MemReadData,
				leds_out => leds_sig,
				buttons_in => (others => '0')
				);
	WriteBack <= MemReadData when ResSrc = '1' else result;
				

    ALUCT: entity work.ALUControl
        port map(
            funct7 => funct7,
            funct3 => funct3,
            ALUE   => ALUE,
            ALUOp  => ALUOp,
				isBranch => BranchCtrl
        );

    RF: entity work.Regfile
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

    ALU1: entity work.ALUextended
        port map(
            A      => rd1,
            B      => B_sel,
            ALUOp  => ALUOp,
            Result => result,
            Zero   => zero_sig
        );
	 Branch <= BranchCtrl;
	 Result_out <= Result;
    Zero <= zero_sig;
	 WriteBack_out <= WriteBack;
	 leds <= leds_sig;

end architecture behave;
