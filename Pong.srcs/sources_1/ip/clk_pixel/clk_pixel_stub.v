// Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2018.2 (win64) Build 2258646 Thu Jun 14 20:03:12 MDT 2018
// Date        : Mon May  6 17:32:34 2019
// Host        : DESKTOP-8E654SF running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               C:/Users/gblan/OneDrive/Documenten/Vivado_projects/Pong/Pong.srcs/sources_1/ip/clk_pixel/clk_pixel_stub.v
// Design      : clk_pixel
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a100tcsg324-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
module clk_pixel(clk_out, clk_out2, reset, clk_in)
/* synthesis syn_black_box black_box_pad_pin="clk_out,clk_out2,reset,clk_in" */;
  output clk_out;
  output clk_out2;
  input reset;
  input clk_in;
endmodule
