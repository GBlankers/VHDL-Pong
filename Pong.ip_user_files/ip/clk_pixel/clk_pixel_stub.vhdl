-- Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2018.2 (win64) Build 2258646 Thu Jun 14 20:03:12 MDT 2018
-- Date        : Mon May  6 17:32:34 2019
-- Host        : DESKTOP-8E654SF running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub
--               C:/Users/gblan/OneDrive/Documenten/Vivado_projects/Pong/Pong.srcs/sources_1/ip/clk_pixel/clk_pixel_stub.vhdl
-- Design      : clk_pixel
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7a100tcsg324-1
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity clk_pixel is
  Port ( 
    clk_out : out STD_LOGIC;
    clk_out2 : out STD_LOGIC;
    reset : in STD_LOGIC;
    clk_in : in STD_LOGIC
  );

end clk_pixel;

architecture stub of clk_pixel is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clk_out,clk_out2,reset,clk_in";
begin
end;
