vlib work
vlib riviera

vlib riviera/xil_defaultlib
vlib riviera/xpm

vmap xil_defaultlib riviera/xil_defaultlib
vmap xpm riviera/xpm

vlog -work xil_defaultlib  -sv2k12 "+incdir+../../../../Pong.srcs/sources_1/ip/clk_pixel" "+incdir+../../../../Pong.srcs/sources_1/ip/clk_pixel" \
"C:/Xilinx/Vivado/2018.2/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \

vcom -work xpm -93 \
"C:/Xilinx/Vivado/2018.2/data/ip/xpm/xpm_VCOMP.vhd" \

vcom -work xil_defaultlib -93 \
"../../../../Pong.srcs/sources_1/ip/clk_pixel/clk_pixel_sim_netlist.vhdl" \


vlog -work xil_defaultlib \
"glbl.v"

