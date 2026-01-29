library IEEE;
use IEEE.STD_LOGIC_1164.All;
use IEEE.NUMERIC_STD.All;

entity DataMemory is
    port(
        clk : in std_logic;
        addr : in std_logic_vector(31 downto 0);
        wd : in std_logic_vector(31 downto 0);
        we : in std_logic;
        rd : out std_logic_vector(31 downto 0);

        leds_out : out STD_LOGIC_VECTOR(7 downto 0);
        buttons_in : in STD_LOGIC_VECTOR(7 downto 0)
    );
end entity;

architecture behave of DataMemory is
    type mem_type is array (0 to 255) of std_logic_vector(31 downto 0);
    signal DMEM : mem_type := (others => (others => '0'));
    signal index : integer range 0 to 255;

    -- MMIO select (combinational)
    signal mmio_select : std_logic;
    signal mmio_addr_is_led  : std_logic;
    signal mmio_addr_is_btn  : std_logic;

    -- GPIO handshake signals
    signal gpio_wr_en : std_logic;
    signal gpio_rd_en : std_logic;

    signal mmio_rd_data : STD_LOGIC_VECTOR(31 downto 0);

begin

    index <= to_integer(unsigned(addr(9 downto 2)));

    -- MMIO address match (combinational)
    mmio_addr_is_led <= '1' when addr = x"00000008" else '0';
    mmio_addr_is_btn <= '1' when addr = x"0000000C" else '0';
    mmio_select <= mmio_addr_is_led or mmio_addr_is_btn;

    -- Provide write & read enables
    gpio_wr_en <= we and mmio_select;
    gpio_rd_en <= mmio_select; -- combinational

    -- GPIO
    GPIO_inst: entity work.GPIO
        port map(
            clk => clk,
            wr_en => gpio_wr_en,
            wr_addr => addr,
            wr_data => wd,
            rd_en => gpio_rd_en,
            rd_addr => addr,
            rd_data => mmio_rd_data,
            leds => leds_out,
            buttons => buttons_in
        );

    -- Synchronous memory writes (only for non-MMIO addresses)
    process(clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                if mmio_select = '1' then
                    -- MMIO write — handled by GPIO write on same rising edge via gpio_wr_en (combinational)
                    null; -- do not write DMEM
                else
                    DMEM(index) <= wd;
                end if;
            end if;
        end if;
    end process;

    process(addr, DMEM, mmio_rd_data)
    begin
        if mmio_select = '1' then
            rd <= mmio_rd_data;
        else
            rd <= DMEM(index);
        end if;
    end process;

end architecture;
