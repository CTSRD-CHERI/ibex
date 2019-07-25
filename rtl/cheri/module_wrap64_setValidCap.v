//
// Generated by Bluespec Compiler, version 2017.07.A (build 1da80f1, 2017-07-21)
//
// On Thu Jul 18 14:51:20 BST 2019
//
//
// Ports:
// Name                         I/O  size props
// wrap64_setValidCap             O    93
// wrap64_setValidCap_cap         I    93
// wrap64_setValidCap_valid       I     1
//
// Combinational paths from inputs to outputs:
//   (wrap64_setValidCap_cap, wrap64_setValidCap_valid) -> wrap64_setValidCap
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

module module_wrap64_setValidCap(wrap64_setValidCap_cap,
				 wrap64_setValidCap_valid,
				 wrap64_setValidCap);
  // value method wrap64_setValidCap
  input  [92 : 0] wrap64_setValidCap_cap;
  input  wrap64_setValidCap_valid;
  output [92 : 0] wrap64_setValidCap;

  // signals for module outputs
  wire [92 : 0] wrap64_setValidCap;

  // value method wrap64_setValidCap
  assign wrap64_setValidCap =
	     { wrap64_setValidCap_valid, wrap64_setValidCap_cap[91:0] } ;
endmodule  // module_wrap64_setValidCap

