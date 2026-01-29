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
---- Generated on "01/19/2026 15:12:18"
--                                                            
---- Vhdl Test Bench template for design  :  SingleCycleCPU
---- 
---- Simulation tool : ModelSim-Altera (VHDL)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SingleCycleCPU_vhd_tst is
end entity;

architecture sim of SingleCycleCPU_vhd_tst is

    -- DUT signals
    signal clk       : std_logic := '0';
    signal leds      : std_logic_vector(7 downto 0);
    signal buttons   : std_logic_vector(7 downto 0) := (others => '0');
    signal PC_out    : std_logic_vector(31 downto 0);
    signal Instr_out : std_logic_vector(31 downto 0);
    signal Result_out: std_logic_vector(31 downto 0);

    constant CLK_PERIOD : time := 10 ns;
    constant SIM_CYCLES  : integer := 40; -- number of clock cycles to simulate

begin

    -- Instantiate DUT
    DUT : entity work.SingleCycleCPU
        port map(
            clk => clk,
            leds => leds,
            buttons => buttons,
            PC_out => PC_out,
            Instr_out => Instr_out,
            Result_out => Result_out
        );

    -- Main simulation process
    stimulus_and_monitor : process
        variable cycle : integer := 0;
        variable pc_int : integer;
        variable instr_low16 : integer;
        variable alu_int : integer;
        variable leds_int : integer;
    begin
        -- initial small delay
        wait for 20 ns;

        for i in 0 to SIM_CYCLES - 1 loop
            -- falling edge
            clk <= '0';
            wait for CLK_PERIOD / 2;

            -- rising edge
            clk <= '1';
            wait for CLK_PERIOD / 2;

            pc_int := to_integer(unsigned(PC_out));
            instr_low16 := to_integer(unsigned(Instr_out(15 downto 0))); -- show low 16 bits for readability
            alu_int := to_integer(unsigned(Result_out));
            leds_int := to_integer(unsigned(leds));

            report "Cycle " & integer'image(i)
                   & "  PC=" & integer'image(pc_int)
                   & "  INSTR(low16)=" & integer'image(instr_low16)
                   & "  RESULT=" & integer'image(alu_int)
                   & "  LEDS=" & integer'image(leds_int)
                   severity note;
        end loop;

        report "Simulation finished after " & integer'image(SIM_CYCLES) & " cycles." severity note;
        wait;
    end process;

end architecture;
