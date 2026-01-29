-- Copyright (C) 2020  Intel Corporation. All rights reserved.
-- Your use of Intel Corporation's design tools, logic functions 
-- and other software and tools, and any partner logic 
-- functions, and any output files from any of the foregoing 
-- (including device programming or simulation files), and any 
-- associated documentation or information are expressly subject 
-- to the terms and conditions of the Intel Program License 
-- Subscription Agreement, the Intel Quartus Prime License Agreement,
-- the Intel FPGA IP License Agreement, or other applicable license
-- agreement, including, without limitation, that your use is for
-- the sole purpose of programming logic devices manufactured by
-- Intel and sold by Intel or its authorized distributors.  Please
-- refer to the applicable agreement for further details, at
-- https://fpgasoftware.intel.com/eula.

-- ***************************************************************************
-- This file contains a Vhdl test bench template that is freely editable to   
-- suit user's needs .Comments are provided in each section to help the user  
-- fill out necessary details.                                                
-- ***************************************************************************
-- Generated on "01/20/2026 20:09:35"
                                                            
-- Vhdl Test Bench template for design  :  MultiCycleCPU
-- 
-- Simulation tool : ModelSim-Altera (VHDL)
-- 

-- tb_MultiCycleCPU.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;

entity MultiCycleCPU_vhd_tst is
end entity;

architecture sim of MultiCycleCPU_vhd_tst is

    -- DUT signals
    signal clk_tb      : std_logic := '0';
    signal Zero_tb     : std_logic;
    signal Result_tb   : std_logic_vector(31 downto 0);
    signal PC_tb       : std_logic_vector(31 downto 0);
    signal WriteBack_tb: std_logic_vector(31 downto 0);
    signal Instr_dbg   : std_logic_vector(31 downto 0);
	 signal state_tb    : std_logic_vector(2 downto 0);

    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz clock (20 ns period)

    -- simulation control
    constant MAX_CYCLES : integer := 30; -- tune as needed
	 
	 function state_name(sv: std_logic_vector(2 downto 0)) return string is
    begin
        if sv = "000" then
            return "IF ";
        elsif sv = "001" then
            return "ID ";
        elsif sv = "010" then
            return "EX ";
        elsif sv = "011" then
            return "MEM";
        elsif sv = "100" then
            return "WB ";
        else
            return "UNK";
        end if;
    end function;

begin

    -- Mapping
    DUT: entity work.MultiCycleCPU
        port map(
            clk        => clk_tb,
            Zero       => Zero_tb,
            Result_out => Result_tb,
            PC_out     => PC_tb,
            WriteBack  => WriteBack_tb,
            Instr_out  => Instr_dbg,
				state_out => state_tb
        );

    -- Clock generator
    clk_proc : process
    begin
        while now < 10 ms loop
            clk_tb <= '0';
            wait for CLK_PERIOD/2;
            clk_tb <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process clk_proc;


    monitor_proc : process
        variable cycle : integer := 0;
        variable instr_low16_int : integer;
        variable result_int : integer;
        variable wb_int : integer;
    begin
        wait for 30 ns; -- delay
        while cycle < MAX_CYCLES loop
            wait until rising_edge(clk_tb);
            cycle := cycle + 1;

            -- convert some signals to integers for printing
            instr_low16_int := to_integer(unsigned(Instr_dbg(15 downto 0)));
            result_int := to_integer(signed(Result_tb));
            wb_int := to_integer(signed(WriteBack_tb));

            report "Cycle " & integer'image(cycle)
					& "  state=" & state_name(state_tb)
                & "  PC=" & integer'image(to_integer(unsigned(PC_tb)))
                & "  Instr(low16)=" & integer'image(instr_low16_int)
                & "  RESULT=" & integer'image(result_int)
                & "  WB=" & integer'image(wb_int);
        end loop;

        report "Testbench finished after " & integer'image(cycle) & " cycles." severity NOTE;
        wait for 100 ns;
        std.env.stop(0); --quit
        wait;
    end process monitor_proc;

end architecture sim;
