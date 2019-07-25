//
// Generated by Bluespec Compiler, version 2017.07.A (build 1da80f1, 2017-07-21)
//
// On Thu Jul 18 14:51:21 BST 2019
//
//
// Ports:
// Name                         I/O  size props
// wrap64_fromMem                 O    93
// wrap64_fromMem_mem_cap         I    65
//
// Combinational paths from inputs to outputs:
//   wrap64_fromMem_mem_cap -> wrap64_fromMem
//
//

`ifdef BSV_ASSIGNMENT_DELAY
`else
  `define BSV_ASSIGNMENT_DELAY
`endif

`ifdef BSV_POSITIVE_RESET
  `define BSV_RESET_VALUE 1'b1
  `define BSV_RESET_EDGE posedge
`else
  `define BSV_RESET_VALUE 1'b0
  `define BSV_RESET_EDGE negedge
`endif

module module_wrap64_fromMem(wrap64_fromMem_mem_cap,
			     wrap64_fromMem);
  // value method wrap64_fromMem
  input  [64 : 0] wrap64_fromMem_mem_cap;
  output [92 : 0] wrap64_fromMem;

  // signals for module outputs
  wire [92 : 0] wrap64_fromMem;

  // remaining internal signals
  wire [33 : 0] fat_address__h72;
  wire [31 : 0] x__h348;
  wire [21 : 0] IF_INV_wrap64_fromMem_mem_cap_BITS_50_TO_46_BI_ETC___d41;
  wire [7 : 0] b_base__h573, fat_addrBits__h73, x__h546, x__h566;
  wire [5 : 0] b_top__h572, topBits__h475, x__h386;
  wire [4 : 0] IF_INV_wrap64_fromMem_mem_cap_BITS_50_TO_46_BI_ETC___d61,
	       INV_wrap64_fromMem_mem_cap_BITS_50_TO_46__q1;
  wire [2 : 0] repBound__h627,
	       tb__h624,
	       tmp_expBotHalf__h341,
	       tmp_expTopHalf__h339;
  wire [1 : 0] carry_out__h477,
	       impliedTopBits__h479,
	       len_correction__h478,
	       x__h563;
  wire IF_INV_wrap64_fromMem_mem_cap_BITS_50_TO_46_BI_ETC___d48,
       IF_INV_wrap64_fromMem_mem_cap_BITS_50_TO_46_BI_ETC___d49,
       IF_INV_wrap64_fromMem_mem_cap_BITS_50_TO_46_BI_ETC___d51;

  // value method wrap64_fromMem
  assign wrap64_fromMem =
	     { wrap64_fromMem_mem_cap[64],
	       fat_address__h72,
	       fat_addrBits__h73,
	       wrap64_fromMem_mem_cap[63:51],
	       ~wrap64_fromMem_mem_cap[50:46],
	       IF_INV_wrap64_fromMem_mem_cap_BITS_50_TO_46_BI_ETC___d41,
	       repBound__h627,
	       IF_INV_wrap64_fromMem_mem_cap_BITS_50_TO_46_BI_ETC___d48,
	       IF_INV_wrap64_fromMem_mem_cap_BITS_50_TO_46_BI_ETC___d49,
	       IF_INV_wrap64_fromMem_mem_cap_BITS_50_TO_46_BI_ETC___d61 } ;

  // remaining internal signals
  assign IF_INV_wrap64_fromMem_mem_cap_BITS_50_TO_46_BI_ETC___d41 =
	     { INV_wrap64_fromMem_mem_cap_BITS_50_TO_46__q1[0] ?
		 x__h386 :
		 6'd0,
	       x__h546,
	       x__h566 } ;
  assign IF_INV_wrap64_fromMem_mem_cap_BITS_50_TO_46_BI_ETC___d48 =
	     tb__h624 < repBound__h627 ;
  assign IF_INV_wrap64_fromMem_mem_cap_BITS_50_TO_46_BI_ETC___d49 =
	     x__h566[7:5] < repBound__h627 ;
  assign IF_INV_wrap64_fromMem_mem_cap_BITS_50_TO_46_BI_ETC___d51 =
	     fat_addrBits__h73[7:5] < repBound__h627 ;
  assign IF_INV_wrap64_fromMem_mem_cap_BITS_50_TO_46_BI_ETC___d61 =
	     { IF_INV_wrap64_fromMem_mem_cap_BITS_50_TO_46_BI_ETC___d51,
	       (IF_INV_wrap64_fromMem_mem_cap_BITS_50_TO_46_BI_ETC___d48 ==
		IF_INV_wrap64_fromMem_mem_cap_BITS_50_TO_46_BI_ETC___d51) ?
		 2'd0 :
		 ((IF_INV_wrap64_fromMem_mem_cap_BITS_50_TO_46_BI_ETC___d48 &&
		   !IF_INV_wrap64_fromMem_mem_cap_BITS_50_TO_46_BI_ETC___d51) ?
		    2'd1 :
		    2'd3),
	       (IF_INV_wrap64_fromMem_mem_cap_BITS_50_TO_46_BI_ETC___d49 ==
		IF_INV_wrap64_fromMem_mem_cap_BITS_50_TO_46_BI_ETC___d51) ?
		 2'd0 :
		 ((IF_INV_wrap64_fromMem_mem_cap_BITS_50_TO_46_BI_ETC___d49 &&
		   !IF_INV_wrap64_fromMem_mem_cap_BITS_50_TO_46_BI_ETC___d51) ?
		    2'd1 :
		    2'd3) } ;
  assign INV_wrap64_fromMem_mem_cap_BITS_50_TO_46__q1 =
	     ~wrap64_fromMem_mem_cap[50:46] ;
  assign b_base__h573 =
	     { wrap64_fromMem_mem_cap[39:34],
	       ~wrap64_fromMem_mem_cap[33],
	       wrap64_fromMem_mem_cap[32] } ;
  assign b_top__h572 =
	     { wrap64_fromMem_mem_cap[45:42],
	       ~wrap64_fromMem_mem_cap[41:40] } ;
  assign carry_out__h477 = (topBits__h475 < x__h566[5:0]) ? 2'b01 : 2'b0 ;
  assign fat_addrBits__h73 =
	     INV_wrap64_fromMem_mem_cap_BITS_50_TO_46__q1[0] ?
	       x__h348[7:0] :
	       wrap64_fromMem_mem_cap[7:0] ;
  assign fat_address__h72 = { 2'd0, wrap64_fromMem_mem_cap[31:0] } ;
  assign impliedTopBits__h479 = x__h563 + len_correction__h478 ;
  assign len_correction__h478 =
	     INV_wrap64_fromMem_mem_cap_BITS_50_TO_46__q1[0] ? 2'b01 : 2'b0 ;
  assign repBound__h627 = x__h566[7:5] - 3'b001 ;
  assign tb__h624 = { impliedTopBits__h479, topBits__h475[5] } ;
  assign tmp_expBotHalf__h341 =
	     { wrap64_fromMem_mem_cap[34],
	       ~wrap64_fromMem_mem_cap[33],
	       wrap64_fromMem_mem_cap[32] } ;
  assign tmp_expTopHalf__h339 =
	     { wrap64_fromMem_mem_cap[42], ~wrap64_fromMem_mem_cap[41:40] } ;
  assign topBits__h475 =
	     INV_wrap64_fromMem_mem_cap_BITS_50_TO_46__q1[0] ?
	       { wrap64_fromMem_mem_cap[45:43], 3'd0 } :
	       b_top__h572 ;
  assign x__h348 = wrap64_fromMem_mem_cap[31:0] >> x__h386 ;
  assign x__h386 = { tmp_expTopHalf__h339, tmp_expBotHalf__h341 } ;
  assign x__h546 = { impliedTopBits__h479, topBits__h475 } ;
  assign x__h563 = x__h566[7:6] + carry_out__h477 ;
  assign x__h566 =
	     INV_wrap64_fromMem_mem_cap_BITS_50_TO_46__q1[0] ?
	       { wrap64_fromMem_mem_cap[39:35], 3'd0 } :
	       b_base__h573 ;
endmodule  // module_wrap64_fromMem

