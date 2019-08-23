set_property SRC_FILE_INFO {cfile:c:/Users/gblan/OneDrive/Documenten/Vivado_projects/Pong/Pong.srcs/sources_1/ip/clk_pixel/clk_pixel.xdc rfile:../../../Pong.srcs/sources_1/ip/clk_pixel/clk_pixel.xdc id:1 order:EARLY scoped_inst:inst} [current_design]
set_property src_info {type:SCOPED_XDC file:1 line:57 export:INPUT save:INPUT read:READ} [current_design]
set_input_jitter [get_clocks -of_objects [get_ports clk_in]] 0.1
