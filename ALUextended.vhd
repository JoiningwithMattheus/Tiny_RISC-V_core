library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ALUextended is
    port (
        A      : in  std_logic_vector(31 downto 0);
        B      : in  std_logic_vector(31 downto 0);
        ALUOp  : in  std_logic_vector(3 downto 0);
        Result : out std_logic_vector(31 downto 0);
        Zero   : out std_logic
    );
end entity ALUextended;

architecture Behavioral of ALUextended is
    signal A_s : signed(31 downto 0);
    signal B_s : signed(31 downto 0);
    signal A_u : unsigned(31 downto 0);
    signal B_u : unsigned(31 downto 0);
begin

    A_s <= signed(A);
    B_s <= signed(B);
    A_u <= unsigned(A);
    B_u <= unsigned(B);

    process(all)
        variable tmp      : std_logic_vector(31 downto 0);
        variable shamt    : integer range 0 to 31;
        variable arith_r  : signed(31 downto 0);
    begin
        tmp := (others => '0');
        shamt := to_integer(B_u(4 downto 0));

        case ALUOp is
            when "0000" =>  -- ADD (signed)
                arith_r := A_s + B_s;
                tmp := std_logic_vector(arith_r);

            when "0001" =>  -- SUB (signed)
                arith_r := A_s - B_s;
                tmp := std_logic_vector(arith_r);

            when "0010" =>  -- AND
                tmp := A and B;

            when "0011" =>  -- OR
                tmp := A or B;

            when "0100" =>  -- SLL (logical left)
                tmp := std_logic_vector( shift_left(A_u, shamt) );

            when "0101" =>  -- SRL (logical right)
                tmp := std_logic_vector( shift_right(A_u, shamt) );

            when "0110" =>  -- SRA (arithmetic right on signed)
                tmp := std_logic_vector( shift_right(A_s, shamt) );

            when "0111" =>  -- SLT (signed)
                if A_s < B_s then
                    tmp := (others => '0');
                    tmp(0) := '1';
                else
                    tmp := (others => '0');
                end if;
					 
			   when "1000" =>
					 tmp := A xor B;
				
            when others =>
                tmp := (others => '0');
        end case;
        Result <= tmp;
        if tmp = x"00000000" then        
            Zero <= '1';
        else
            Zero <= '0';
        end if;
    end process;

end architecture Behavioral;
