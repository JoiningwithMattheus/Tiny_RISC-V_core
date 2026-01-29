library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Decompressor is
    port(
        instr16_in         : in  std_logic_vector(15 downto 0);
        instr32_out        : out std_logic_vector(31 downto 0);
        is_compressed_out  : out std_logic;
        valid_out          : out std_logic; 
        illegal            : out std_logic   
    );
end entity;

architecture rtl of Decompressor is

    -- zero-extend
    function zext(v : std_logic_vector) return std_logic_vector is
        variable outv : std_logic_vector(11 downto 0) := (others => '0');
        constant sz   : integer := v'length;
    begin
        for i in 0 to sz-1 loop
            outv(i) := v(i);
        end loop;
        return outv;
    end function;

    -- sign-extend
    function sext(v : std_logic_vector) return std_logic_vector is
        variable outv : std_logic_vector(11 downto 0) := (others => '0');
        constant sz   : integer := v'length;
        constant sbit : std_logic := v(sz-1);
    begin
        for i in 11 downto sz loop
            outv(i) := sbit;
        end loop;
        for i in 0 to sz-1 loop
            outv(i) := v(i);
        end loop;
        return outv;
    end function;

    function reg_from_3bit(b : std_logic_vector(2 downto 0)) return std_logic_vector is
    begin
        -- map 0...7 -> 8..15
        return "01" & b;
    end function;

    -- R-type: funct7(7) rs2(5) rs1(5) funct3(3) rd(5) opcode(7)
    function make_rtype(f7 : std_logic_vector(6 downto 0);
                        rs2 : std_logic_vector(4 downto 0);
                        rs1 : std_logic_vector(4 downto 0);
                        f3  : std_logic_vector(2 downto 0);
                        rd  : std_logic_vector(4 downto 0);
                        opc : std_logic_vector(6 downto 0)) return std_logic_vector is
    begin
        return f7 & rs2 & rs1 & f3 & rd & opc;
    end function;

    -- I-type: imm12 rs1 funct3 rd opcode
    function make_itype(imm12 : std_logic_vector(11 downto 0);
                        rs1   : std_logic_vector(4 downto 0);
                        f3    : std_logic_vector(2 downto 0);
                        rd    : std_logic_vector(4 downto 0);
                        opc   : std_logic_vector(6 downto 0)) return std_logic_vector is
    begin
        return imm12 & rs1 & f3 & rd & opc;
    end function;

    -- S-type: imm[11:5] rs2 rs1 funct3 imm[4:0] opcode
    function make_stype(imm12 : std_logic_vector(11 downto 0);
                        rs2   : std_logic_vector(4 downto 0);
                        rs1   : std_logic_vector(4 downto 0);
                        f3    : std_logic_vector(2 downto 0);
                        opc   : std_logic_vector(6 downto 0)) return std_logic_vector is
    begin
        return imm12(11 downto 5) & rs2 & rs1 & f3 & imm12(4 downto 0) & opc;
    end function;

    --constants for opcodes & funct3
    constant OPC_ADDI : std_logic_vector(6 downto 0) := "0010011";
    constant OPC_LW   : std_logic_vector(6 downto 0) := "0000011";
    constant OPC_SW   : std_logic_vector(6 downto 0) := "0100011";
    constant OPC_JAL  : std_logic_vector(6 downto 0) := "1101111";
    constant OPC_BRANCH : std_logic_vector(6 downto 0) := "1100011";
    constant FUNCT3_LW : std_logic_vector(2 downto 0) := "010";
    constant FUNCT3_SW : std_logic_vector(2 downto 0) := "010";

begin
    process(instr16_in)
        -- declarative variables
        variable inst     : std_logic_vector(15 downto 0);
        variable op_low2  : std_logic_vector(1 downto 0);
        variable funct3   : std_logic_vector(2 downto 0);
        variable rd5      : std_logic_vector(4 downto 0);
        variable rdprime  : std_logic_vector(4 downto 0);
        variable rs1prime : std_logic_vector(4 downto 0);
        variable rs2prime : std_logic_vector(4 downto 0);
        variable out32    : std_logic_vector(31 downto 0);
        variable is_comp  : std_logic;
        variable ok       : std_logic;
        variable bad      : std_logic;

        -- immediates (various widths used by different compressed forms)
        variable imm6     : std_logic_vector(5 downto 0);
        variable imm5     : std_logic_vector(4 downto 0);
        variable imm7     : std_logic_vector(6 downto 0);
        variable uimm12   : std_logic_vector(11 downto 0);
        variable s12      : std_logic_vector(11 downto 0);
        variable tmp20    : std_logic_vector(19 downto 0);
        variable j_imm12  : std_logic_vector(11 downto 0);
        variable b_imm9   : std_logic_vector(8 downto 0);
        variable uimm     : std_logic_vector(11 downto 0);
		  
		  variable imm10    : std_logic_vector(9 downto 0);  -- used for C.ADDI16SP construction
		  variable imm_top6 : std_logic_vector(5 downto 0);  -- imm10(9 downto 4) helper

    begin
        -- defaults
        inst := instr16_in;
        op_low2 := inst(1 downto 0);
        funct3 := inst(15 downto 13);
        rd5 := inst(11 downto 7);
        rdprime := reg_from_3bit(inst(4 downto 2));   -- rd'
        rs1prime := reg_from_3bit(inst(9 downto 7));  -- rs1'
        rs2prime := reg_from_3bit(inst(4 downto 2));  -- rs2'
        out32 := (others => '0');
        is_comp := '0';
        ok := '0';
        bad := '0';
        uimm12 := (others => '0');
        s12 := (others => '0');
        tmp20 := (others => '0');
        j_imm12 := (others => '0');
        b_imm9 := (others => '0');
        uimm := (others => '0');

        -- Determine compressed or not
        if op_low2 /= "11" then
            is_comp := '1';

            -- Quadrant selection
            case op_low2 is
					 -- Quadrant 0
                when "00" =>
                    case funct3 is
                        -- c.addi4spn— funct3 = 000
                     when "000" =>
							
							imm6 := inst(12) & inst(6 downto 2);
							
							if imm6 = "000000"then
								bad := '1';
							
							else
								  uimm12 := (others => '0');
								  uimm12(7 downto 2) := imm6;  -- imm6 << 2
								  -- addi rd', x2, uimm
								  out32 := make_itype(uimm12, "00010", "000", rdprime, OPC_ADDI);
								  ok := '1';
							end if;

                     -- c.lw (CL) funct3 = 010
							when "010" =>
								uimm := (others => '0');
								uimm(5) := inst(5);
								uimm(4 downto 2) := inst(12 downto 10);
								uimm(1 downto 0) := "00";
								out32 := make_itype(uimm, rs1prime, FUNCT3_LW, rdprime, OPC_LW);
								ok := '1';

							-- c.sw funct 3 = 110
							when "110" =>
								uimm := (others => '0');
								uimm(5) := inst(5);
								uimm(4 downto 2) := inst(12 downto 10);
								uimm(1 downto 0) := "00";
								out32 := make_stype(uimm, rs2prime, rs1prime, FUNCT3_SW, OPC_SW);
								ok := '1';
                    
						  when others =>
								bad := '1';
						  end case;
                -- Quadrant 1
                -- CI, CJ, CB forms: c.addi, c.li, c.lui,  (rd=x2), c.jal, c.j, c.beqz/bnez
                when "01" =>
                    case funct3 is
                        -- c.addi / c.nop   (funct3 = 000)
                        when "000" =>
                            -- CI form: imm[5] = inst[12], imm[4:0] = inst[6:2]
                            imm6 := inst(12) & inst(6 downto 2);
									 if (rd5 = "00000") and (imm6 /= "000000") then
											bad := '1';
									 else
                            s12 := sext(imm6); -- sign-extend to 12 bits
                            out32 := s12 & rd5 & "000" & rd5 & "0010011"; -- addi rd, rd, imm
                            ok := '1';
									 end if;

                        -- c.jal (funct3 = 001)-> JAL rd=x1
                        when "001" =>
                            -- CJ immediate mapping per spec -> build J-type immediate (20-bit) from 11-bit parcel (we sign-extend)
                            j_imm12(11) := inst(12);
                            j_imm12(10) := inst(8);
                            j_imm12(9)  := inst(10);
                            j_imm12(8)  := inst(9);
                            j_imm12(7)  := inst(6);
                            j_imm12(6)  := inst(7);
                            j_imm12(5)  := inst(2);
                            j_imm12(4)  := inst(11);
                            j_imm12(3)  := inst(5);
                            j_imm12(2)  := inst(4);
                            j_imm12(1)  := inst(3);
                            j_imm12(0)  := '0';
                         -- sign-extend j_imm12 to 20-bit immediate (J-type)
								   	tmp20(19 downto 12) := (others => j_imm12(11));
										tmp20(11 downto 0)  := j_imm12;
                            -- J-type layout: imm[20|10:1|11|19:12] in bits 31:12
                            out32 := tmp20(19) & tmp20(9 downto 0) & tmp20(10) & tmp20(18 downto 11) & "00001" & "1101111"; -- rd=x1
                            ok := '1';

                        -- c.li (funct3 = 010)
                        when "010" =>
								if (rd5 = "00000") and (imm6 /= "000000") then
									bad := '1';
								else
                            imm6 := inst(12) & inst(6 downto 2);
                            s12 := sext(imm6);
                            out32 := s12 & "00000" & "000" & rd5 & "0010011"; -- addi rd, x0, imm
                            ok := '1';
							   end if;

                        -- c.lui / c.addi16sp (funct3 = 011)
                        when "011" =>
                        if rd5 = "00010" then
                            -- C.ADDI16SP: expand to addi x2, x2, imm
                            imm10 := (others => '0');
                            imm10(9) := inst(12);
                            imm10(8 downto 7) := inst(4 downto 3);
                            imm10(6) := inst(5);
                            imm10(5) := inst(2);
                            imm10(4) := inst(6);
									 
                            -- Extract imm_top6 = imm10[9:4]
                            imm_top6 := imm10(9 downto 4);
                            s12 := sext(imm_top6 & "0000");

                            -- addi x2, x2, s12
                            out32 := s12 & "00010" & "000" & "00010" & "0010011";
                            ok := '1';
                        else
                            bad := '1';
                        end if;


                        -- funct3=100: SLLI
                        when "100" =>
								 if inst(12) = '0' then
									  -- shift/logic immediate group
									  if inst(6 downto 2) /= "00000" then
											imm5 := inst(6 downto 2);
											-- SLLI rd, rd, shamt
											out32 := make_itype("0000000" & imm5, rd5, "001", rd5, OPC_ADDI);
											ok := '1';
									  else
											bad := '1';
									  end if;
								 else
									  -- register group or alias (c.ebreak, c.jr, c.mv, c.add...)
									  if inst(6 downto 2) = "00000" then
											-- special case: ebreak (when rd == 0) or jr (jalr x0, 0(rd))
											if rd5 = "00000" then
												 out32 := x"00100073"; -- EBREAK
												 ok := '1';
											else
												 -- c.jr : jalr x0, 0(rs1=rd)
												 out32 := "000000000000" & rd5 & "000" & "00000" & "1100111";
												 ok := '1';
											end if;
									  else
											-- c.mv rd, rs2  -> add rd, x0, rs2   
											if rd5 = "00000" then
												 bad := '1'; -- (require rd != x0)!!!
											else
												 out32 := make_rtype("0000000", inst(6 downto 2), "00000", "000", inst(11 downto 7), "0110011");
												 ok := '1';
											end if;
									  end if;
								 end if;

                        -- c.j (funct3 = 101)
                        when "101" =>
                            -- same immediate fields as c.jal but rd=x0
                            j_imm12(11) := inst(12);
                            j_imm12(10) := inst(8);
                            j_imm12(9)  := inst(10);
                            j_imm12(8)  := inst(9);
                            j_imm12(7)  := inst(6);
                            j_imm12(6)  := inst(7);
                            j_imm12(5)  := inst(2);
                            j_imm12(4)  := inst(11);
                            j_imm12(3)  := inst(5);
                            j_imm12(2)  := inst(4);
                            j_imm12(1)  := inst(3);
                            j_imm12(0)  := '0';
                            -- sign extend, the same as jal!
									 tmp20(19 downto 12) := (others => j_imm12(11));
									 tmp20(11 downto 0)  := j_imm12;
                            out32 := tmp20(19) & tmp20(9 downto 0) & tmp20(10) & tmp20(18 downto 11) & "00000" & "1101111";
                            ok := '1';

                        -- CB branches (funct3 110 = beqz, 111 = bnez)
                        when "110" | "111" =>
                            -- build branch immediate (9-bit in compressed)
                            b_imm9(8) := inst(12);
                            b_imm9(7 downto 6) := inst(6 downto 5);
                            b_imm9(5) := inst(2);
                            b_imm9(4 downto 3) := inst(11 downto 10);
                            b_imm9(2 downto 1) := inst(4 downto 3);
                            b_imm9(0) := '0';
									 
									 -- Size extionsion
                            s12 := sext(b_imm9); 
                            -- Expand to B-type: imm[11:5] rs2 rs1 funct3 imm[4:0] opcode
                            -- Compare with zero: use rs2 = x0, rs1 = rs1'
                            if funct3 = "110" then
                                -- BEQZ -> use funct3 = 000
                                out32 := s12(11 downto 5) & "00000" & rs1prime & "000" & s12(4 downto 0) & "1100011";
                            else
                                -- BNEZ -> funct3 = 001
                                out32 := s12(11 downto 5) & "00000" & rs1prime & "001" & s12(4 downto 0) & "1100011";
                            end if;
                            ok := '1';

                        when others =>
                            bad := '1';
                    end case;

                -- Quadrant 2 (op_low2 = "10") - SLLI, LWSP, SWSP
                when "10" =>
                    case funct3 is
                        -- c.slli (funct3 = 000)
                        when "000" =>
                            if rd5 = "00000" then
                                bad := '1';
                            else
                                imm5 := inst(6 downto 2);
                                out32 := "0000000" & imm5 & rd5 & "001" & rd5 & "0010011"; -- SLLI
                                ok := '1';
                            end if;

                        -- c.lwsp (funct3 = 010)
                        when "010" =>
                            -- load from sp (x2)
                            if rd5 = "00000" then
                                bad := '1';
                            else
                                uimm(5) := inst(12);
                                uimm(4 downto 2) := inst(6 downto 4);
                                uimm(1 downto 0) := "00";
                                out32 := uimm & "00010" & "010" & rd5 & "0000011"; -- lw rd, uimm(sp)
                                ok := '1';
                            end if;

                        -- c.swsp (funct3 = 110)
							when "110" =>
								 rs2prime := reg_from_3bit(inst(4 downto 2));
								 uimm := (others => '0');
								 uimm(5 downto 2) := inst(8 downto 5);
								 uimm(1 downto 0) := "00";
								 -- store rs2prime, uimm(sp)
								 out32 := make_stype(uimm, rs2prime, "00010", FUNCT3_SW, OPC_SW);
								 ok := '1';

								-- funct3 = 100
								when "100" =>
									 if inst(12) = '0' then
										  -- CR: c.mv rd, rs2  (decode only when rs2 != x0 per spec)
										  if inst(6 downto 2) = "00000" then
												bad := '1';
										  else
												if rd5 = "00000" then
													 bad := '1'; -- rd must not be x0 for mv
												else
													 -- add rd, x0, rs2  (mv)
													 out32 := make_rtype("0000000", inst(6 downto 2), "00000", "000", inst(11 downto 7), "0110011");
													 ok := '1';
													end if;
											  end if;
										 else
										  -- c.add rd, rd, rs2  (rd != x0)
										  if rd5 = "00000" then
												bad := '1';
										  else
											out32 := make_rtype("0000000", inst(6 downto 2), inst(11 downto 7), "000", inst(11 downto 7), "0110011"); -- ADD
											ok := '1';
									  end if;
								 end if;

                        when others =>
                            bad := '1';
                    end case;

                when others =>
                    bad := '1';
            end case;
        else
            -- Not compressed — assemble and use a full 32-bit word
            is_comp := '0';
				
            ok := '0';
            bad := '0';
            out32 := (others => '0');
        end if;

        -- Final outputs
        instr32_out <= out32;
        is_compressed_out <= is_comp;
        valid_out <= ok;
        illegal <= bad;
    end process;

end architecture rtl;
