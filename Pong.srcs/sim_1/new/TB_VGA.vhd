----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06.05.2019 16:36:41
-- Design Name: 
-- Module Name: TB_VGA - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity TB_VGA is
--  Port ( );
end TB_VGA;

architecture Behavioral of TB_VGA is

signal CLK: std_logic := '0';
signal Reset: std_logic := '0';
signal LMO: std_logic := '0';
signal RMO: std_logic := '0';
signal V_R: std_logic_vector (3 downto 0);
signal V_G: std_logic_vector (3 downto 0);
signal V_B: std_logic_vector (3 downto 0);
signal VGAH: std_logic;
signal VGAV: std_logic;
signal clk_period : time := 10 ns;

component Pong_top
    port(
         CLK100MHZ: in std_logic;
           RES: in std_logic;
           R_MOVE: in std_logic;
           L_MOVE: in std_logic;
           VGA_R: out std_logic_vector (3 downto 0);
           VGA_G: out std_logic_vector (3 downto 0);
           VGA_B: out std_logic_vector (3 downto 0);
           VGA_HS: out std_logic;
           VGA_VS: out std_logic);
    end component;

begin

Pong_top1: Pong_top
port map(
    CLK100MHZ => clk,
    RES => reset,
    R_MOVE => RMO,
    L_MOVE => LMO,
    VGA_R => V_R,
    VGA_B => V_B, 
    VGA_G => V_G,
    VGA_HS => VGAH,
    VGA_VS => VGAV
);

clk_process :process
begin
    clk <= '0';
    wait for clk_period/2;  --for 0.5 ns signal is '0'.
    clk <= '1';
    wait for clk_period/2; --for next 0.5 ns signal is '1'.
end process;


end Behavioral;
