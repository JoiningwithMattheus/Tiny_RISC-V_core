library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ALUControl is
    port(
        funct7 : in  STD_LOGIC_VECTOR(6 downto 0);
        funct3 : in  STD_LOGIC_VECTOR(2 downto 0);
        ALUE   : in  STD_LOGIC;                      -- I-type vs R-type selector
        ALUOp  : out STD_LOGIC_VECTOR(3 downto 0);   -- 4-bit internal ALU opcode (matches ALUextended)
        isBranch: in STD_LOGIC                       
    );
end entity;

architecture behave of ALUControl is
begin
    process(funct7, funct3, ALUE, isBranch)
    begin
        -- default = ADD
        ALUOp <= "0000";

        -- use SUB
        if isBranch = '1' then
            ALUOp <= "0001"; -- SUB
        else
            -- ALUE = '0' indicates I-type (addi/ori etc.) -> choose based on funct3
            -- ALUE = '1' indicates R-type -> use funct7/funct3 mapping
            if ALUE = '0' then
                -- I-type arithmetic immediates (support ADDI and ORI from your original list)
                case funct3 is
                    when "000" => ALUOp <= "0000"; -- ADDI => ADD
                    when "110" => ALUOp <= "0011"; -- ORI  => OR
                    when others => ALUOp <= "0000";
                end case;
            else
                -- R-type: map funct3/funct7 to ALU operations
                case funct3 is
                    when "000" =>
                        if funct7 = "0100000" then
                            ALUOp <= "0001"; -- SUB
                        else
                            ALUOp <= "0000"; -- ADD
                        end if;
                    when "100" => ALUOp <= "1000"; -- XOR
                    when "111" => ALUOp <= "0010"; -- AND
                    when "110" => ALUOp <= "0011"; -- OR
                    when "001" => ALUOp <= "0100"; -- SLL
                    when "101" =>
                        if funct7 = "0100000" then
                            ALUOp <= "0110"; -- SRA (arith right)
                        else
                            ALUOp <= "0101"; -- SRL (logical right)
                        end if;
                    when "010" => ALUOp <= "0111"; -- SLT
                    when others => ALUOp <= "0000"; -- default ADD
                end case;
            end if;
        end if;
    end process;
end architecture;
