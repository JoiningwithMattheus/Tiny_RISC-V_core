---- Copyright (C) 2020  Intel Corporation. All rights reserved.
---- Your use of Intel Corporation's design tools, logic functions 
---- and other software and tools, and any partner logic 
---- functions, and any output files from any of the foregoing 
---- (including device programming or simulation files), and any 
---- associated documentation or information are expressly subject 
---- to the terms and conditions of the Intel Program License 
---- Subscription Agreement, the Intel Quartus Prime License Agreement,
---- the Intel FPGA IP License Agreement, or other applicable license
---- agreement, including, without limitation, that your use is for
---- the sole purpose of programming logic devices manufactured by
---- Intel and sold by Intel or its authorized distributors.  Please
---- refer to the applicable agreement for further details, at
---- https://fpgasoftware.intel.com/eula.
--
---- ***************************************************************************
---- This file contains a Vhdl test bench template that is freely editable to   
---- suit user's needs .Comments are provided in each section to help the user  
---- fill out necessary details.                                                
---- ***************************************************************************
---- Generated on "01/20/2026 01:17:03"
--                                                            
---- Vhdl Test Bench template for design  :  Decompressor
---- 
---- Simulation tool : ModelSim-Altera (VHDL)
---- 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity Decompressor_vhd_tst is
end entity;

architecture sim of Decompressor_vhd_tst is

    -- The signals in vhd file
    signal instr16    : std_logic_vector(15 downto 0) := (others => '0');
    signal instr32    : std_logic_vector(31 downto 0);
    signal is_comp    : std_logic;
    signal valid_o    : std_logic;
    signal illegal_o  : std_logic;

    constant TV_COUNT : integer := 8;
    type tv16_t is array(0 to TV_COUNT-1) of std_logic_vector(15 downto 0);

    -- Example test vectors — replace / extend as needed
    constant TEST_IN : tv16_t := (
        x"1021",
        x"154A", 
        x"0000", -- illegal/reserved 
        x"4001",
        x"A443",
        x"9002",
        x"0001",
        x"FFFF"
    );

    -- Helper: hex conversion 
    constant HEX_CHARS : string(1 to 16) := "0123456789ABCDEF";

    function hex16(slv : std_logic_vector(15 downto 0)) return string is
        variable res : string(1 to 4);
        variable nib : integer;
    begin
        for i in 0 to 3 loop
            nib := to_integer(unsigned(slv(15 - 4*i downto 12 - 4*i)));
            res(i+1) := HEX_CHARS(nib + 1);
        end loop;
        return res;
    end function;

    function hex32(slv : std_logic_vector(31 downto 0)) return string is
        variable res : string(1 to 8);
        variable nib : integer;
    begin
        for i in 0 to 7 loop
            nib := to_integer(unsigned(slv(31 - 4*i downto 28 - 4*i)));
            res(i+1) := HEX_CHARS(nib + 1);
        end loop;
        return res;
    end function;

begin
    -- Instantiate DUT (make sure Decompressor is compiled into 'work')
    DUT : entity work.Decompressor
        port map (
            instr16_in => instr16,
            instr32_out => instr32,
            is_compressed_out => is_comp,
            valid_out => valid_o,
            illegal => illegal_o
        );

    -- Stimulus & logging process
    stimulus_proc : process
        variable L : line;
        variable i : integer := 0;
    begin
        -- delay
        wait for 10 ns;

        for i in 0 to TV_COUNT-1 loop
            -- Drive input
            instr16 <= TEST_IN(i);
            wait for 5 ns;  -- allow combinational propagation

            -- Build log line
            write(L, string'("TV="));
            write(L, i);
            write(L, string'("  in16=0x"));
            write(L, hex16(instr16));
            write(L, string'("  is_comp="));
            write(L, is_comp);
            write(L, string'("  valid="));
            write(L, valid_o);
            write(L, string'("  illegal="));
            write(L, illegal_o);
            write(L, string'("  out32=0x"));
            write(L, hex32(instr32));
            writeline(output, L);
            wait for 5 ns;
        end loop;

        report "All done!!!" severity note;
        wait;
    end process stimulus_proc;

end architecture sim;
