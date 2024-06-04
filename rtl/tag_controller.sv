// Copyright (c) 2024 Peter Rugg University of Cambridge.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Simple tag controller with in-built registers for tag storage. It is the
// core's responsibility to ensure that tags are only set for aligned
// capability-width accesses and are consistent across the two writes, though
// this module will end up persisting the second tag.
// It is also assumed that no transactions will happen in the middle of a
// capability write, otherwise non-atomic tagged results could be observed.
// The OBI already requires addresses to be aligned to the access width, so
// this is also assumed.

module tag_controller #(
  parameter int unsigned TagRegionOffsetW = 32,
  parameter int unsigned TagRegionStart = 0,
  parameter int unsigned Depth = 8
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  input  logic        core_req_i,
  output logic        core_gnt_o,
  output logic        core_rvalid_o,
  input  logic        core_we_i,
  input  logic [3:0]  core_be_i,
  input  logic [31:0] core_addr_i,
  input  logic [32:0] core_wdata_i,
  input  logic [6:0]  core_wdata_intg_i,
  output logic [32:0] core_rdata_o,
  output logic [6:0]  core_rdata_intg_o,
  output logic        core_err_o,

  output logic        mem_req_o,
  input  logic        mem_gnt_i,
  input  logic        mem_rvalid_i,
  output logic        mem_we_o,
  output logic [3:0]  mem_be_o,
  output logic [31:0] mem_addr_o,
  output logic [31:0] mem_wdata_o,
  output logic [6:0]  mem_wdata_intg_o,
  input  logic [31:0] mem_rdata_i,
  input  logic [6:0]  mem_rdata_intg_i,
  input  logic        mem_err_i
);

  logic [4095:0] tags[(1 << (TagRegionOffsetW - 12 - 3))-1:0];

  /* FIFO to track the tags that should be attached to outstanding reads */
  logic fifo_clr;
  logic fifo_wvalid;
  logic fifo_wready;
  logic fifo_wdata;
  logic fifo_rvalid;
  logic fifo_rready;
  logic fifo_rdata;
  //logic fifo_err;

  logic [(32-TagRegionOffsetW):0] addr_region;
  logic [TagRegionOffsetW-1-3:0] addr_offset;
  logic addr_tagged;
  logic [11:0] addr_lo;
  logic [(31-12-3):0] addr_hi;

  always_comb begin
    // Calculate the "region": the upper bits determining whether the address is tagged
    // Extend addr with 0 bit to avoid 0-length signal when TagRegionOffsetW = 32
    addr_region = {{1'b0, core_addr_i}[32:TagRegionOffsetW]};
    // Calculate the offset within the tagged window
    addr_offset = {core_addr_i[TagRegionOffsetW-1:3]};
    // The address is tagged iff the window matches the tagged window
    addr_tagged = {addr_region, {TagRegionOffsetW{1'b0}}} == {1'b0, TagRegionStart};
    // Split the address to perform tag lookup
    addr_lo = addr_offset[11:0];
    addr_hi = addr_offset[31-3:12];
  end

  always_comb begin
    fifo_clr = 1'b0;
    fifo_wvalid = core_gnt_o;
    fifo_wdata = (addr_tagged & ~core_we_i) ? tags[addr_hi][addr_lo] : 1'b0;
    fifo_rready = core_rvalid_o;
  end

  prim_fifo_sync #(
    .Width(1),
    .Pass(1'b1),
    .Depth(Depth),
    .OutputZeroIfEmpty(1'b1)/*, // Fail safe
    .Secure(0)*/ // We check for full ourselves before enq
  ) u_outstanding_reads (
    .clk_i,
    .rst_ni,
    .clr_i(fifo_clr),
    .wvalid_i(fifo_wvalid),
    .wready_o(fifo_wready),
    .wdata_i(fifo_wdata),
    .rvalid_o(fifo_rvalid),
    .rready_i(fifo_rready),
    .rdata_o(fifo_rdata),
    .full_o(/* NC */),
    .depth_o(/* NC */)/*,
    .err_o(fifo_err)*/
  );

  always_comb begin
    mem_req_o = core_req_i & fifo_wready;
    mem_we_o = core_we_i;
    mem_be_o = core_be_i;
    mem_addr_o = core_addr_i;
    mem_wdata_o = core_wdata_i[31:0];
    mem_wdata_intg_o = core_wdata_intg_i;

    core_gnt_o = mem_gnt_i;
    core_rvalid_o = mem_rvalid_i;
    core_rdata_o[31:0] = mem_rdata_i;
    core_rdata_o[32] = fifo_rdata;
    core_rdata_intg_o = mem_rdata_intg_i;
    core_err_o = mem_err_i /*| fifo_err*/;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (integer i = 0; i < (1 << (TagRegionOffsetW - 12 - 3)); i = i + 1) begin
        /* verilator lint_off BLKSEQ */
        tags[i] = 0;
        /* verilator lint_on BLKSEQ */
      end
    end else begin
      if (core_gnt_o & core_we_i & addr_tagged) begin
        tags[addr_hi][addr_lo] <= core_wdata_i[32];
      end
      if (core_rvalid_o & ~fifo_rvalid) begin
        // This should never happen, but could for a FIFO with different timing characteristics.
        $display("Error: tag response fifo was not ready when data arrived!");
        $exit();
      end
    end
  end

endmodule
