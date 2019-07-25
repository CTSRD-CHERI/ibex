//
// Generated by Bluespec Compiler, version 2017.07.A (build 1da80f1, 2017-07-21)
//
// On Thu Jul 18 14:51:20 BST 2019
//
//
// Ports:
// Name                         I/O  size props
// wrap64_setSoftPerms            O    93
// wrap64_setSoftPerms_cap        I    93
// wrap64_setSoftPerms_softperms  I    16 unused
//
// Combinational paths from inputs to outputs:
//   wrap64_setSoftPerms_cap -> wrap64_setSoftPerms
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

module module_wrap64_setSoftPerms(wrap64_setSoftPerms_cap,
				  wrap64_setSoftPerms_softperms,
				  wrap64_setSoftPerms);
  // value method wrap64_setSoftPerms
  input  [92 : 0] wrap64_setSoftPerms_cap;
  input  [15 : 0] wrap64_setSoftPerms_softperms;
  output [92 : 0] wrap64_setSoftPerms;

  // signals for module outputs
  wire [92 : 0] wrap64_setSoftPerms;

  // value method wrap64_setSoftPerms
  assign wrap64_setSoftPerms = wrap64_setSoftPerms_cap ;
endmodule  // module_wrap64_setSoftPerms

