-- MultiCycleCPU.vhd (cleaned, compile-ready)
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity MultiCycleCPU is
    port(
        clk        : in  std_logic;
        Zero       : out std_logic;
        Result_out : out std_logic_vector(31 downto 0);
        PC_out     : out std_logic_vector(31 downto 0);
        WriteBack  : out std_logic_vector(31 downto 0);
        Instr_out  : out std_logic_vector(31 downto 0);
		  state_out  : out std_logic_vector(2 downto 0)
    );
end entity;

architecture rtl of MultiCycleCPU is

    -- Datapath registers
    signal PC      : std_logic_vector(31 downto 0) := (others => '0');
    signal IR      : std_logic_vector(31 downto 0) := (others => '0');
    signal MDR     : std_logic_vector(31 downto 0) := (others => '0');
    signal A_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal B_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal ALUOut  : std_logic_vector(31 downto 0) := (others => '0');
    signal Imm     : std_logic_vector(31 downto 0) := (others => '0');

    -- Decoded fields (combinational)
    signal opcode  : std_logic_vector(6 downto 0);
    signal rd      : std_logic_vector(4 downto 0);
    signal funct3  : std_logic_vector(2 downto 0);
    signal rs1     : std_logic_vector(4 downto 0);
    signal rs2     : std_logic_vector(4 downto 0);
    signal funct7  : std_logic_vector(6 downto 0);

    -- RF / ALU
    signal rd1, rd2 : std_logic_vector(31 downto 0);
    signal ALU_A    : std_logic_vector(31 downto 0);
    signal ALU_B    : std_logic_vector(31 downto 0);
    signal ALUResult: std_logic_vector(31 downto 0);
    signal Zero_sig : std_logic;
	 
	 -- add in declarations
	 signal MemAddr_reg        : std_logic_vector(31 downto 0) := (others => '0');
	 signal MemWriteEnable_reg : std_logic := '0';
	 signal MemWriteData_reg   : std_logic_vector(31 downto 0) := (others => '0');
	 signal MemReadEnable_reg  : std_logic := '0';  -- optional if you use read enable


    -- IMEM output
    signal IMEM_out : std_logic_vector(31 downto 0);

    -- FSM states
    type state_type is (sIF, sID, sEX, sMEM, sWB);
    signal state : state_type := sIF;

    -- Control signals (combinational from MainControl and latched in ID)
    signal RegWrite_ctrl_comb : std_logic;
    signal ALUSrc_ctrl_comb   : std_logic;
    signal ALUE_ctrl_comb     : std_logic;
    signal MemWrite_ctrl_comb : std_logic;
    signal ResSrc_ctrl_comb   : std_logic;
    signal Branch_ctrl_comb   : std_logic;
    signal Branchop_ctrl_comb : std_logic_vector(1 downto 0);

    signal RegWrite_ctrl_reg : std_logic := '0';
    signal ALUSrc_ctrl_reg   : std_logic := '0';
    signal ALUE_ctrl_reg     : std_logic := '0';
    signal MemWrite_ctrl_reg : std_logic := '0';
    signal ResSrc_ctrl_reg   : std_logic := '0';
    signal Branch_ctrl_reg   : std_logic := '0';
    signal Branchop_ctrl_reg : std_logic_vector(1 downto 0) := (others => '0');

    -- ALU control output
    signal ALUOp_signal : std_logic_vector(3 downto 0);
	 signal ALUOp_local : std_logic_vector(3 downto 0);

    -- Single-driver control outputs & helpers
    signal RegWrite_drive : std_logic := '0';
    signal WB_data        : std_logic_vector(31 downto 0);

    -- IR / PC write request signals (combinational from state)
    signal IRWrite : std_logic := '0';
    signal PCWrite : std_logic := '0';

begin

    -- Combinational decode
    opcode <= IR(6 downto 0);
    rd     <= IR(11 downto 7);
    funct3 <= IR(14 downto 12);
    rs1    <= IR(19 downto 15);
    rs2    <= IR(24 downto 20);
    funct7 <= IR(31 downto 25);

    -- Instruction memory
    IMEM_inst: entity work.InstructionMemory
        port map(
            addr  => PC,       -- change to PC(9 downto 2) if IMEM expects a word index
            Instr => IMEM_out  -- match your entity's output port name (Instr/dout/instr)
        );

    -- Expose IR
    Instr_out <= IR;

    -- MainControl + ALUControl (combinational)!!!
    CU: entity work.MainControl
        port map(
            opcode   => opcode,
            RegWrite => RegWrite_ctrl_comb,
            ALUSrc   => ALUSrc_ctrl_comb,
            ALUE     => ALUE_ctrl_comb,
            Branch   => Branch_ctrl_comb,
            Branchop => Branchop_ctrl_comb,
            MemWrite => MemWrite_ctrl_comb,
            ResSrc   => ResSrc_ctrl_comb,
            funct3   => funct3
        );

    ALUCT: entity work.ALUControl
        port map(
            funct7 => funct7,
            funct3 => funct3,
            ALUE   => ALUE_ctrl_reg,    -- latched in ID
            ALUOp  => ALUOp_signal,
            isBranch => Branch_ctrl_reg  -- latched in ID
        );
		 ALUOp_local <= "0000" when state = sIF else ALUOp_signal;

    -- Register file
    RF: entity work.Regfile
        port map(
            clk => clk,
            a1  => rs1,
            a2  => rs2,
            a3  => rd,
            we3 => RegWrite_drive,
            wd3 => WB_data,
            rd1 => rd1,
            rd2 => rd2
        );

    ALU1: entity work.ALUextended
        port map(
            A      => ALU_A,
            B      => ALU_B,
            ALUOp  => ALUOp_local,
            Result => ALUResult,
            Zero   => Zero_sig
        );

    Result_out <= ALUResult;
    Zero <= Zero_sig;

    -- Data memory
    DataMemInst: entity work.DataMemory
    port map(
        clk => clk,
        addr => MemAddr_reg,
        wd => MemWriteData_reg,
        we => MemWriteEnable_reg,
        rd => MDR,
        buttons_in => (others => '0')
    );


    -- ALU operand selection (combinational)
    -- IF: ALU computes PC+4 (ALU_A=PC, ALU_B=4)
    -- EX branch: compute PC + Imm (ALU_A=PC, ALU_B=Imm)
    -- Normal EX: ALU_A=A_reg; ALU_B = Imm if ALUSrc_ctrl_reg='1' else B_reg
    process(state, PC, A_reg, B_reg, Imm, ALUSrc_ctrl_reg, Branch_ctrl_reg)
    begin
        if state = sIF then
            ALU_A <= PC;
            ALU_B <= std_logic_vector(to_signed(4, 32));
        elsif state = sEX and Branch_ctrl_reg = '1' then
            ALU_A <= PC;
            ALU_B <= Imm;
        else
            ALU_A <= A_reg;
            if ALUSrc_ctrl_reg = '1' then
                ALU_B <= Imm;
            else
                ALU_B <= B_reg;
            end if;
        end if;
    end process;

    -- WB data selection and regfile write enable (single-driver)
    WB_data <= MDR when (ResSrc_ctrl_reg = '1' and state = sWB) else ALUOut;
    RegWrite_drive <= '1' when (RegWrite_ctrl_reg = '1' and state = sWB) else '0';

    -- IRWrite / PCWrite combinational derived from state
    process(state)
    begin
        IRWrite <= '0';
        PCWrite <= '0';
        if state = sIF then
            IRWrite <= '1';
            PCWrite <= '1';
        end if;
    end process;

    -- Sequential datapath and FSM progression (single process)
    -- Latches and state transitions occur on rising edge of clk.
    process(clk)
        variable bimm12 : std_logic_vector(12 downto 0);
    begin
        if rising_edge(clk) then

            -- actions depending on current state (sample / latch) ---
            if state = sIF then
                if IRWrite = '1' then
                    IR <= IMEM_out;  -- sample fetched instruction
                end if;
                if PCWrite = '1' then
                    PC <= ALUResult; -- PC + 4 (ALUResult computed combinationally earlier)
                end if;

            elsif state = sID then
                -- latch register operands
                A_reg <= rd1;
                B_reg <= rd2;

                -- build immediate depending on instruction format (I, S, B)
                if opcode = "0010011" or opcode = "0000011" then
                    -- I-type (imm[11:0] = IR[31:20]) sign-extend
                    Imm <= (others => IR(31));
                    Imm(11 downto 0) <= IR(31 downto 20);
                elsif opcode = "0100011" then
                    -- S-type: imm[11:5]=IR[31:25], imm[4:0]=IR[11:7]
                    Imm <= (others => IR(31));
                    Imm(11 downto 5) <= IR(31 downto 25);
                    Imm(4 downto 0) <= IR(11 downto 7);
                elsif opcode = "1100011" then
                    -- B-type:
                    bimm12(12) := IR(31);
                    bimm12(11) := IR(7);
                    bimm12(10 downto 5) := IR(30 downto 25);
                    bimm12(4 downto 1) := IR(11 downto 8);
                    bimm12(0) := '0';
                    if bimm12(12) = '1' then
                        Imm <= (others => '1');
                    else
                        Imm <= (others => '0');
                    end if;
                    Imm(12 downto 0) <= bimm12;
                else
                    Imm <= (others => '0');
                end if;

                -- latch MainControl outputs to control registers (for EX/MEM/WB)
                RegWrite_ctrl_reg <= RegWrite_ctrl_comb;
                ALUSrc_ctrl_reg   <= ALUSrc_ctrl_comb;
                ALUE_ctrl_reg     <= ALUE_ctrl_comb;
                MemWrite_ctrl_reg <= MemWrite_ctrl_comb;
                ResSrc_ctrl_reg   <= ResSrc_ctrl_comb;
                Branch_ctrl_reg   <= Branch_ctrl_comb;
                Branchop_ctrl_reg <= Branchop_ctrl_comb;

            elsif state = sEX then
                -- latch ALU result
                ALUOut <= ALUResult;
					 
					 if MemWrite_ctrl_reg = '1' then
						  -- store: set up memory interface for the following rising edge
						  -- We register address/data now so they'll be stable for next cycle's DataMemory write
						  -- (ALUOut holds the computed address; B_reg holds the store data)
						  MemAddr_reg        <= ALUOut;
						  MemWriteData_reg   <= B_reg;
						  MemWriteEnable_reg <= '1';
						  MemReadEnable_reg  <= '0';
					 elsif (ResSrc_ctrl_reg = '1') and (/* instruction is load */ opcode = "0000011") then
						  -- load: register address and assert a read (if you require we=0, rd_en=1 etc.)
						  MemAddr_reg        <= ALUOut;
						  MemWriteData_reg   <= (others => '0');
						  MemWriteEnable_reg <= '0';
						  MemReadEnable_reg  <= '1';
					 else
						  -- default: no mem access
						  MemWriteEnable_reg <= '0';
						  MemReadEnable_reg  <= '0';
					 end if;

                -- branch handling (use latched Branch_ctrl_reg and Branchop_ctrl_reg)
                if Branch_ctrl_reg = '1' then
                    if Branchop_ctrl_reg = "01" and Zero_sig = '1' then  -- BEQ
                        PC <= ALUResult;
                    elsif Branchop_ctrl_reg = "10" and Zero_sig = '0' then -- BNE
                        PC <= ALUResult;
                    end if;
                end if;

            elsif state = sMEM then
                -- For loads, MDR is driven combinationally by DataMemory; it is available now
                -- For stores, DataMemory write happened synchronously at this rising edge when MemWriteEnable was '1'
					 MemWriteEnable_reg <= '0';
					 MemReadEnable_reg  <= '0';
                null;

            elsif state = sWB then
                -- nothing to latch here (Regfile write is performed by Regfile at rising edge when RegWrite_drive='1')
                null;
            end if;

            -- --- state transitions ---
            case state is
                when sIF =>
                    state <= sID;
                when sID =>
                    state <= sEX;
                when sEX =>
                    if MemReadEnable_reg = '1' or MemWriteEnable_reg = '1' then
                        state <= sMEM;
                    elsif RegWrite_ctrl_reg = '1' then
                        state <= sWB;
                    else
                        state <= sIF;
                    end if;
                when sMEM =>
                    if ResSrc_ctrl_reg = '1' then
                        state <= sWB; -- load needs write-back
                    else
                        state <= sIF; -- store done
                    end if;
                when sWB =>
                    state <= sIF;
                when others =>
                    state <= sIF;
            end case;
        end if;
    end process;

    PC_out <= PC;
    Instr_out <= IR;
    WriteBack <= WB_data;
	 
	 -- sIF  => "000", sID => "001", sEX => "010", sMEM => "011", sWB => "100"
    state_out <= "000" when state = sIF  else
                 "001" when state = sID  else
                 "010" when state = sEX  else
                 "011" when state = sMEM else
                 "100";

end architecture;
