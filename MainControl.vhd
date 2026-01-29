library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity MainControl is
    port(
        opcode   : in  STD_LOGIC_VECTOR(6 downto 0);
        RegWrite : out STD_LOGIC;
        ALUSrc   : out STD_LOGIC;
        ALUE     : out STD_LOGIC;
		  Branch   : out STD_LOGIC;
		  Branchop   : out STD_LOGIC_VECTOR(1 downto 0);
		  -- BranchOp: "00" = no branch, "01" = BEQ, "10" = BNE
		  MemWrite : out STD_LOGIC;
		  ResSrc : out STD_LOGIC;
		  funct3 : in STD_LOGIC_VECTOR(2 downto 0)
    );
end entity;

architecture behave of MainControl is
begin
    process(opcode)
    begin
	 
			MemWrite <= '0';
			ResSrc <= '0';
			Branchop <= "00";
        case opcode is

            -- R-type 
            when "0110011" =>
                RegWrite <= '1';
                ALUSrc   <= '0';  
                ALUE     <= '1'; 
					Branch   <= '0'; 

            -- I-type (only addi!)
            when "0010011" =>
                RegWrite <= '1';
                ALUSrc   <= '1';   
                ALUE     <= '0'; 
					 Branch   <= '0';
				-- B-type
			   when "1100011" =>
                RegWrite <= '0';
                ALUSrc   <= '0';   
                ALUE     <= '1'; 
					 Branch <= '1';
					 if funct3 = "000" then
							Branchop <= "01"; -- BEQ
						elsif funct3 = "001" then
							Branchop <= "10"; --BNE
						else Branchop <= "00";
					 end if;
				when "0000011" => -- lw (load)
					 RegWrite <= '1';
                ALUSrc   <= '1';  -- addrs = rs1 + imm 
                ALUE     <= '0'; 
					 Branch <= '0'; 
					 MemWrite <= '0';
					 ResSrc <= '1'; -- write back from memory
				when "0100011" =>-- sw (store)
					 RegWrite <= '0';
                ALUSrc   <= '1';   
                ALUE     <= '0'; 
					 Branch <= '0'; 
					 MemWrite <= '1';
					 ResSrc <= '0'; 
            when others =>
                RegWrite <= '0';
                ALUSrc   <= '0';
                ALUE     <= '0';
					 Branch   <= '0';
        end case;
    end process;
end architecture;
