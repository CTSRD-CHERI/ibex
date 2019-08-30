// Copyright lowRISC contributors.
// Copyright 2018 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Igor Loi - igor.loi@unibo.it                               //
//                                                                            //
// Additional contributions by:                                               //
//                 Andreas Traber - atraber@iis.ee.ethz.ch                    //
//                 Markus Wegmann - markus.wegmann@technokrat.ch              //
//                 Davide Schiavone - pschiavo@iis.ee.ethz.ch                 //
//                                                                            //
// Design Name:    Load Store Unit                                            //
// Project Name:   ibex                                                       //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Load Store Unit, used to eliminate multiple access during  //
//                 processor stalls, and to align bytes and halfwords         //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

`define CAP_SIZE 93

/*
    CHERI implementation details:
      I need to implement something that checks whether the write is a valid one. The
      memchecker module should do this. I need to instantiate this somewhere, pass the
      actual address that I want to access and separately the capability that is providing
      the authority for that memory access.

      In the LSU, I'll calculate the actual physical address and pass it out. the memchecker
      will live in the ibex_core module and will listen to the memory accesses. It will
      assert an error if it sees something wrong. the error will go to the LSU and will
      set the lsu load_err or store_err wires to high as appropriate.

      When doing a legacy load in integer encoding mode, the source register is part of the
*/

/**
 * Load Store Unit
 *
 * Load Store Unit, used to eliminate multiple access during processor stalls,
 * and to align bytes and halfwords.
 */
module ibex_load_store_unit (
    input  logic         clk_i,
    input  logic         rst_ni,

    // data interface
    output logic         data_req_o,
    input  logic         data_gnt_i,
    input  logic         data_rvalid_i,
    input  logic         data_err_i,

    // TODO address is redundant if we use the capability for the address
    // however, if we're using ddc as our capability the address might not be redundant
    // address to output to memory
    output logic [31:0]  data_addr_o,
    output logic         data_we_o,
    output logic [7:0]   data_be_o,
    output logic [`CAP_SIZE-1:0]  data_wdata_o,
    input  logic [`CAP_SIZE-1:0]  data_rdata_i,

    // signals to/from ID/EX stage
    input  logic         data_we_ex_i,         // write enable                     -> from ID/EX
    input  logic [1:0]   data_type_ex_i,       // data type: word, half word, byte -> from ID/EX
    input  logic [`CAP_SIZE-1:0]  data_wdata_ex_i,      // data to write to memory          -> from ID/EX
    input  logic [1:0]   data_reg_offset_ex_i, // register byte offset for stores  -> from ID/EX
    input  logic         data_sign_ext_ex_i,   // sign extension                   -> from ID/EX

    output logic [`CAP_SIZE-1:0]  data_rdata_ex_o,      // requested data                   -> to ID/EX
    input  logic         data_req_ex_i,        // data request                     -> from ID/EX

    input  logic [31:0]  adder_result_ex_i,    // address computed in ALU          -> from ID/EX


    output logic         addr_incr_req_o,      // request address increment for
                                               // misaligned accesses              -> to ID/EX
    output logic [31:0]  addr_last_o,          // address of last transaction      -> to controller
                                               // -> mtval
                                               // -> AGU for misaligned accesses
    output logic         data_valid_o,         // LSU has completed transaction    -> to 

    input logic [`CAP_SIZE-1:0] data_cap_i,
    input logic use_cap_base_i,
    input logic [`EXCEPTION_SIZE-1:0] cheri_mem_exc_i,
    // TODO remove debug signal
    output logic [2:0]   wdata_offset_o,   // mux control for data to be written to memory
    output logic [31:0] data_addr_real_o,

    // exception signals
    output logic         load_err_o,
    output logic         store_err_o,

    output logic         busy_o
);

  logic [31:0]  data_addr;
  //logic [31:0]  data_addr_w_aligned;
  logic [31:0]  data_addr_d_aligned;
  logic [31:0]  addr_last_q, addr_last_d;

  logic [`CAP_SIZE-1:0]  rdata_q, rdata_d;
  logic [2:0]   rdata_offset_q, rdata_offset_d;
  logic [1:0]   data_type_q, data_type_d;
  logic         data_sign_ext_q, data_sign_ext_d;
  logic         data_we_q, data_we_d;

  logic [2:0]   wdata_offset;   // mux control for data to be written to memory

  logic [7:0]   data_be;
  logic [64:0]  data_wdata;

  logic [`CAP_SIZE-1:0]  data_rdata_ext;

  logic [64:0]  rdata_w_ext; // word realignment for misaligned loads
  logic [64:0]  rdata_h_ext; // sign extension for half words
  logic [64:0]  rdata_b_ext; // sign extension for bytes

  logic         split_misaligned_access;
  logic         handle_misaligned_q, handle_misaligned_d; // high after receiving grant for first
                                                          // part of a misaligned access

  typedef enum logic [2:0]  {
    IDLE, WAIT_GNT_MIS, WAIT_RVALID_MIS, WAIT_GNT, WAIT_RVALID
  } ls_fsm_e;

  ls_fsm_e ls_fsm_cs, ls_fsm_ns;

  assign data_addr = (use_cap_base_i ? data_cap_i_getBase_o : data_cap_i_getAddr_o) + adder_result_ex_i;
  assign data_addr_real_o = data_addr;

  ///////////////////
  // BE generation //
  ///////////////////

  always_comb begin
    unique case (data_type_ex_i) // Data type 00 Word, 01 Half word, 11,10 byte
      2'b00: begin // Writing a word
        if (!handle_misaligned_q) begin // first part of potentially misaligned transaction
          unique case (data_addr[2:0])
            3'b000:   data_be = 8'b0000_1111;
            3'b001:   data_be = 8'b0001_1110;
            3'b010:   data_be = 8'b0011_1100;
            3'b011:   data_be = 8'b0111_1000;
            3'b100:   data_be = 8'b1111_0000;
            3'b101:   data_be = 8'b1110_0000;
            3'b110:   data_be = 8'b1100_0000;
            3'b111:   data_be = 8'b1000_0000;
            default: data_be = 'X;
          endcase // case (data_addr[1:0])
        end else begin // second part of misaligned transaction
          unique case (data_addr[2:0])
            3'b000:   data_be = 8'b0000_0000; // the next 5 cases are not used, but included for completeness
            3'b001:   data_be = 8'b0000_0000;
            3'b010:   data_be = 8'b0000_0000;
            3'b011:   data_be = 8'b0000_0000;
            3'b100:   data_be = 8'b0000_0000;
            3'b101:   data_be = 8'b0000_0001;
            3'b110:   data_be = 8'b0000_0011;
            3'b111:   data_be = 8'b0000_0111;
            default: data_be = 'X;
          endcase // case (data_addr[1:0])
        end
      end

      2'b01: begin // Writing a half word
        if (!handle_misaligned_q) begin // first part of potentially misaligned transaction
          unique case (data_addr[2:0])
            3'b000:   data_be = 8'b0000_0011;
            3'b001:   data_be = 8'b0000_0110;
            3'b010:   data_be = 8'b0000_1100;
            3'b011:   data_be = 8'b0001_1000;
            3'b100:   data_be = 8'b0011_0000;
            3'b101:   data_be = 8'b0110_0000;
            3'b110:   data_be = 8'b1100_0000;
            3'b111:   data_be = 8'b1000_0000;
            default: data_be = 'X;
          endcase // case (data_addr[1:0])
        end else begin // second part of misaligned transaction
          data_be = 8'b0001;
        end
      end

      2'b10: begin // Writing a byte
        unique case (data_addr[2:0])
          3'b000:   data_be = 8'b0000_0001;
          3'b001:   data_be = 8'b0000_0010;
          3'b010:   data_be = 8'b0000_0100;
          3'b011:   data_be = 8'b0000_1000;
          3'b100:   data_be = 8'b0001_0000;
          3'b101:   data_be = 8'b0010_0000;
          3'b110:   data_be = 8'b0100_0000;
          3'b111:   data_be = 8'b1000_0000;
          default: data_be = 'X;
        endcase // case (data_addr[1:0])
      end

      
      2'b11: begin // Writing a double
        if (!handle_misaligned_q) begin // first part of misaligned txion
          unique case (data_addr[2:0])
            3'b000:  data_be = 8'b1111_1111;
            3'b001:  data_be = 8'b1111_1110;
            3'b010:  data_be = 8'b1111_1100;
            3'b011:  data_be = 8'b1111_1000;
            3'b100:  data_be = 8'b1111_0000;
            3'b101:  data_be = 8'b1110_0000;
            3'b110:  data_be = 8'b1100_0000;
            3'b111:  data_be = 8'b1000_0000;
          endcase
        end else begin
          unique case (data_addr[2:0])
            3'b000:  data_be = 8'b0000_0000;
            3'b001:  data_be = 8'b0000_0001;
            3'b010:  data_be = 8'b0000_0011;
            3'b011:  data_be = 8'b0000_0111;
            3'b100:  data_be = 8'b0000_1111;
            3'b101:  data_be = 8'b0001_1111;
            3'b110:  data_be = 8'b0011_1111;
            3'b111:  data_be = 8'b0111_1111;
          endcase
        end
      end
      

      default:     data_be = 'X;
    endcase // case (data_type_ex_i)
  end

  /////////////////////
  // WData alignment //
  /////////////////////

  // prepare data to be written to the memory
  // we handle misaligned accesses, half word and byte accesses and
  // register offsets here
  assign wdata_offset_o = data_addr[2:0];
  assign wdata_offset = data_addr[2:0] - data_reg_offset_ex_i[1:0];
  always_comb begin
    unique case (wdata_offset)
      3'b000:   data_wdata = {1'b0, data_wdata_ex_i[63:0]};
      3'b001:   data_wdata = {1'b0, data_wdata_ex_i[55:0], data_wdata_ex_i[63:56]};
      3'b010:   data_wdata = {1'b0, data_wdata_ex_i[47:0], data_wdata_ex_i[63:48]};
      3'b011:   data_wdata = {1'b0, data_wdata_ex_i[39:0], data_wdata_ex_i[63:40]};
      3'b100:   data_wdata = {1'b0, data_wdata_ex_i[31:0], data_wdata_ex_i[63:32]};
      3'b101:   data_wdata = {1'b0, data_wdata_ex_i[23:0], data_wdata_ex_i[63:24]};
      3'b110:   data_wdata = {1'b0, data_wdata_ex_i[15:0], data_wdata_ex_i[63:16]};
      3'b111:   data_wdata = {1'b0, data_wdata_ex_i[ 7:0], data_wdata_ex_i[63: 8]};
      default: data_wdata = 'X;
    endcase // case (wdata_offset)
  end

  /////////////////////
  // RData alignment //
  /////////////////////

  // rdata_q holds data returned from memory for first part of misaligned loads
  always_comb begin
    rdata_d = rdata_q;
    if (data_rvalid_i & ~data_we_q & handle_misaligned_q) begin
      rdata_d = data_rdata_i;
    end
  end

  // update control signals for next read data upon receiving grant
  assign rdata_offset_d  = data_gnt_i ? data_addr[2:0]     : rdata_offset_q;
  assign data_type_d     = data_gnt_i ? data_type_ex_i     : data_type_q;
  assign data_sign_ext_d = data_gnt_i ? data_sign_ext_ex_i : data_sign_ext_q;
  assign data_we_d       = data_gnt_i ? data_we_ex_i       : data_we_q;

  // registers for rdata alignment and sign-extension
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rdata_q         <=   '0;
      rdata_offset_q  <= 3'h0;
      data_type_q     <= 2'h0;
      data_sign_ext_q <= 1'b0;
      data_we_q       <= 1'b0;
    end else begin
      rdata_q         <= rdata_d;
      rdata_offset_q  <= rdata_offset_d;
      data_type_q     <= data_type_d;
      data_sign_ext_q <= data_sign_ext_d;
      data_we_q       <= data_we_d;
    end
  end

  // take care of misaligned words
  always_comb begin
    unique case (rdata_offset_q)
      3'b000:   rdata_w_ext = {1'b0, data_rdata_i[63:0]};
      3'b001:   rdata_w_ext = {1'b0, data_rdata_i[ 7:0], data_rdata_i[63: 8]};
      3'b010:   rdata_w_ext = {1'b0, data_rdata_i[15:0], data_rdata_i[63:16]};
      3'b011:   rdata_w_ext = {1'b0, data_rdata_i[23:0], data_rdata_i[63:24]};
      3'b100:   rdata_w_ext = {1'b0, data_rdata_i[31:0], data_rdata_i[63:32]};
      3'b101:   rdata_w_ext = {1'b0, data_rdata_i[39:0], rdata_q[63:40]};
      3'b110:   rdata_w_ext = {1'b0, data_rdata_i[47:0], rdata_q[63:48]};
      3'b111:   rdata_w_ext = {1'b0, data_rdata_i[55:0], rdata_q[63:56]};
      default: rdata_w_ext = 'X;
    endcase
  end

  ////////////////////
  // Sign extension //
  ////////////////////

  // TODO ask:
  //    how far do i sign-extend?
  // sign extension for half words
  always_comb begin
    unique case (rdata_offset_q)
      3'b000: begin
        if (!data_sign_ext_q) begin
          rdata_h_ext = {48'h0000, data_rdata_i[15:0]};
        end else begin
          rdata_h_ext = {{48{data_rdata_i[15]}}, data_rdata_i[15:0]};
        end
      end

      3'b001: begin
        if (!data_sign_ext_q) begin
          rdata_h_ext = {48'h0000, data_rdata_i[23:8]};
        end else begin
          rdata_h_ext = {{48{data_rdata_i[23]}}, data_rdata_i[23:8]};
        end
      end

      3'b010: begin
        if (!data_sign_ext_q) begin
          rdata_h_ext = {48'h0000, data_rdata_i[31:16]};
        end else begin
          rdata_h_ext = {{48{data_rdata_i[31]}}, data_rdata_i[31:16]};
        end
      end

      3'b011: begin
        if (!data_sign_ext_q) begin
          rdata_h_ext = {48'h0000, data_rdata_i[39:24]};
        end else begin
          rdata_h_ext = {{48{data_rdata_i[39]}}, data_rdata_i[39:24]};
        end
      end

      3'b100: begin
        if (!data_sign_ext_q) begin
          rdata_h_ext = {48'h0000, data_rdata_i[47:32]};
        end else begin
          rdata_h_ext = {{48{data_rdata_i[47]}}, data_rdata_i[47:32]};
        end
      end

      3'b101: begin
        if (!data_sign_ext_q) begin
          rdata_h_ext = {48'h0000, data_rdata_i[55:40]};
        end else begin
          rdata_h_ext = {{48{data_rdata_i[55]}}, data_rdata_i[55:40]};
        end
      end

      3'b110: begin
        if (!data_sign_ext_q) begin
          rdata_h_ext = {48'h0000, data_rdata_i[63:48]};
        end else begin
          rdata_h_ext = {{48{data_rdata_i[63]}}, data_rdata_i[63:48]};
        end
      end

      3'b111: begin
        if (!data_sign_ext_q) begin
          rdata_h_ext = {48'h0000, data_rdata_i[7:0], rdata_q[63:56]};
        end else begin
          rdata_h_ext = {{48{data_rdata_i[7]}}, data_rdata_i[7:0], rdata_q[63:56]};
        end
      end

      default: rdata_h_ext = 'X;
    endcase // case (rdata_offset_q)
  end

  // sign extension for bytes
  always_comb begin
    unique case (rdata_offset_q)
      3'b000: begin
        if (!data_sign_ext_q) begin
          rdata_b_ext = {56'h00_0000, data_rdata_i[7:0]};
        end else begin
          rdata_b_ext = {{56{data_rdata_i[7]}}, data_rdata_i[7:0]};
        end
      end

      3'b001: begin
        if (!data_sign_ext_q) begin
          rdata_b_ext = {56'h00_0000, data_rdata_i[15:8]};
        end else begin
          rdata_b_ext = {{56{data_rdata_i[15]}}, data_rdata_i[15:8]};
        end
      end

      3'b010: begin
        if (!data_sign_ext_q) begin
          rdata_b_ext = {56'h00_0000, data_rdata_i[23:16]};
        end else begin
          rdata_b_ext = {{56{data_rdata_i[23]}}, data_rdata_i[23:16]};
        end
      end

      3'b011: begin
        if (!data_sign_ext_q) begin
          rdata_b_ext = {56'h00_0000, data_rdata_i[31:24]};
        end else begin
          rdata_b_ext = {{56{data_rdata_i[31]}}, data_rdata_i[31:24]};
        end
      end

      3'b100: begin
        if (!data_sign_ext_q) begin
          rdata_b_ext = {56'h00_0000, data_rdata_i[39:32]};
        end else begin
          rdata_b_ext = {{56{data_rdata_i[39]}}, data_rdata_i[39:32]};
        end
      end

      3'b101: begin
        if (!data_sign_ext_q) begin
          rdata_b_ext = {56'h00_0000, data_rdata_i[47:40]};
        end else begin
          rdata_b_ext = {{56{data_rdata_i[47]}}, data_rdata_i[47:40]};
        end
      end

      3'b110: begin
        if (!data_sign_ext_q) begin
          rdata_b_ext = {56'h00_0000, data_rdata_i[55:48]};
        end else begin
          rdata_b_ext = {{56{data_rdata_i[55]}}, data_rdata_i[55:48]};
        end
      end

      3'b111: begin
        if (!data_sign_ext_q) begin
          rdata_b_ext = {56'h00_0000, data_rdata_i[63:56]};
        end else begin
          rdata_b_ext = {{56{data_rdata_i[63]}}, data_rdata_i[63:56]};
        end
      end

      default: rdata_b_ext = 'X;
    endcase // case (rdata_offset_q)
  end

  // select word, half word or byte sign extended version
  always_comb begin
    unique case (data_type_q)
      2'b00:       data_rdata_ext = rdata_w_ext;
      2'b01:       data_rdata_ext = rdata_h_ext;
      2'b10:       data_rdata_ext = rdata_b_ext;
      2'b11:       data_rdata_ext = data_rdata_i;
    endcase //~case(rdata_type_q)
  end

  /////////////
  // LSU FSM //
  /////////////

  // check for misaligned accesses that need to be split into two word-aligned accesses
  assign split_misaligned_access =
      ((data_type_ex_i == 2'b00) && (data_addr[2:0] > 3'b100)) || // misaligned word access
      ((data_type_ex_i == 2'b01) && (data_addr[2:0] == 3'b111)) || // misaligned half-word access
      1'b0; // TODO implement misaligned double accesses here

  // FSM
  always_comb begin
    ls_fsm_ns       = ls_fsm_cs;

    data_req_o          = 1'b0;
    data_valid_o        = 1'b0;
    addr_incr_req_o     = 1'b0;
    handle_misaligned_d = handle_misaligned_q;

    unique case (ls_fsm_cs)

      IDLE: begin
        if (data_req_ex_i) begin
          // TODO move exception checking elsewhere
          data_req_o = 1'b1 && !(|cheri_mem_exc_i);
          if (data_gnt_i) begin
            handle_misaligned_d = split_misaligned_access;
            ls_fsm_ns           = split_misaligned_access ? WAIT_RVALID_MIS : WAIT_RVALID;
          end else if (|cheri_mem_exc_i) begin
            data_valid_o = 1'b1;
            ls_fsm_ns = IDLE;
          end else begin
            ls_fsm_ns           = split_misaligned_access ? WAIT_GNT_MIS    : WAIT_GNT;
          end
        end
      end

      WAIT_GNT_MIS: begin
        // TODO move exception checking elsewhere
        data_req_o = 1'b1 && !(|cheri_mem_exc_i);
        if (data_gnt_i) begin
          handle_misaligned_d = 1'b1;
          ls_fsm_ns           = WAIT_RVALID_MIS;
        end
      end

      WAIT_RVALID_MIS: begin
        // tell ID/EX stage to update the address
        addr_incr_req_o = 1'b1;
        if (data_rvalid_i) begin
          // first part rvalid is received
          if (data_err_i) begin
            // first part created an error, abort transaction
            data_valid_o        = 1'b1;
            handle_misaligned_d = 1'b0;
            ls_fsm_ns           = IDLE;
          end else begin
            // push out second request
            // TODO move exception checking elsewhere
            data_req_o = 1'b1 && !(|cheri_mem_exc_i);
            if (data_gnt_i) begin
              // second grant is received
              ls_fsm_ns = WAIT_RVALID;
            end else begin
              // second grant is NOT received, but first rvalid
              ls_fsm_ns = WAIT_GNT;
            end
          end
        end else begin
          // first part rvalid is NOT received
          ls_fsm_ns = WAIT_RVALID_MIS;
        end
      end

      WAIT_GNT: begin
        // tell ID/EX stage to update the address
        addr_incr_req_o = handle_misaligned_q;
        // TODO move exception checking elsewhere
        data_req_o      = 1'b1 && !(|cheri_mem_exc_i);
        if (data_gnt_i) begin
          ls_fsm_ns = WAIT_RVALID;
        end
      end

      WAIT_RVALID: begin
        data_req_o = 1'b0;
        if (data_rvalid_i) begin
          data_valid_o        = 1'b1;
          handle_misaligned_d = 1'b0;
          ls_fsm_ns           = IDLE;
        end else begin
          ls_fsm_ns           = WAIT_RVALID;
        end
      end

      default: begin
        ls_fsm_ns = ls_fsm_e'(1'bX);
      end
    endcase
  end

  // store last address for mtval + AGU for misaligned transactions:
  // - misaligned address needed for correct generation of data_be and data_rdata_ext
  // - do not update in case of errors, mtval needs the failing address
  always_comb begin
    addr_last_d = addr_last_q;
    if (data_req_o & data_gnt_i & ~(load_err_o | store_err_o)) begin
      //addr_last_d = data_addr;
      // this can't simply be the last address, because the address calculated there already includes the
      // capability base. if we were to use that one, then when performing multicycle loads/stores,
      // we would add the capability offset twice which is incorrect
      addr_last_d = adder_result_ex_i;
    end
  end

  // registers for FSM
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ls_fsm_cs           <= IDLE;
      addr_last_q         <= '0;
      handle_misaligned_q <= '0;
    end else begin
      ls_fsm_cs           <= ls_fsm_ns;
      addr_last_q         <= addr_last_d;
      handle_misaligned_q <= handle_misaligned_d;
    end
  end

  /////////////
  // Outputs //
  /////////////

  // output to register file
  assign data_rdata_ex_o = data_rdata_ext;

  // output data address must be word aligned
  //assign data_addr_w_aligned = {data_addr[31:2], 2'b00};
  assign data_addr_d_aligned = {data_addr[31:3], 3'b000};

  // output to data interface
  //assign data_addr_o   = data_addr_w_aligned;
  assign data_addr_o   = data_addr_d_aligned;
  // THIS SCREWS UP UNALIGNED ADDRESSES
  // original:
  //assign data_wdata_o  = data_wdata;
  // TODO need to align double-size accesses as well
  assign data_wdata_o  = (data_type_ex_i == 2'b11) ? data_wdata_ex_i : data_wdata;
  assign data_we_o     = data_we_ex_i;
  assign data_be_o     = data_be;

  // output to ID stage: mtval + AGU for misaligned transactions
  assign addr_last_o   = addr_last_q;

  // to know what kind of error to signal, we need to know the type of the transaction to which
  // the outsanding rvalid belongs.
  assign load_err_o    = ((data_err_i & data_rvalid_i) || (|cheri_mem_exc_i & data_req_ex_i)) & ~data_we_q;
  assign store_err_o   = ((data_err_i & data_rvalid_i) || (|cheri_mem_exc_i & data_req_ex_i)) &  data_we_q;

  assign busy_o = (ls_fsm_cs == WAIT_RVALID) | (data_req_o == 1'b1);


logic [`CAP_SIZE-1:0] data_cap_i_getOffset_o;
module_wrap64_getOffset module_getOffset_data_cap (
  .wrap64_getOffset_cap(data_cap_i),
    .wrap64_getOffset(data_cap_i_getOffset_o));

logic [`CAP_SIZE-1:0] data_cap_i_getAddr_o;
module_wrap64_getAddr module_getAddr_data_cap (
    .wrap64_getAddr_cap(data_cap_i),
    .wrap64_getAddr(data_cap_i_getAddr_o));

logic [`CAP_SIZE-1:0] data_cap_i_getBase_o;
module_wrap64_getBase module_getBase_data_cap (
    .wrap64_getBase_cap(data_cap_i),
    .wrap64_getBase(data_cap_i_getBase_o));



  ////////////////
  // Assertions //
  ////////////////

`ifndef VERILATOR
  // make sure there is no new request when the old one is not yet completely done
  // i.e. it should not be possible to get a grant without an rvalid for the
  // last request
  assert property (
    @(posedge clk_i)
      ((ls_fsm_cs == WAIT_RVALID) && (data_gnt_i == 1'b1)) |-> (data_rvalid_i == 1'b1) ) else
        $display("Data grant set while LSU keeps waiting for rvalid");

  // there should be no rvalid when we are in IDLE
  assert property (
    @(posedge clk_i) (ls_fsm_cs == IDLE) |-> (data_rvalid_i == 1'b0) ) else
      $display("Data rvalid set while LSU idle");

  // assert that errors are only sent at the same time as rvalid
  assert property (
    @(posedge clk_i) (data_err_i) |-> (data_rvalid_i) ) else
      $display("Data error not sent with rvalid");

  // assert that the address does not contain X when request is sent
  assert property (
    @(posedge clk_i) (data_req_o) |-> (!$isunknown(data_addr_o)) ) else
      $display("Data address not valid");

  // assert that the address is word aligned when request is sent
  assert property (
    @(posedge clk_i) (data_req_o) |-> (data_addr_o[1:0] == 2'b00) ) else
      $display("Data address not word aligned");
`endif
endmodule
