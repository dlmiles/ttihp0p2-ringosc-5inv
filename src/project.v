/*
 * Copyright (c) 2024 Darryl L. Miles
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// we'll go 100ps here so VCD is saner with ring oscillator
`timescale 1ns / 100ps

module tt_um_dlmiles_ringosc_5inv (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  localparam RING_LENGTH = 5; // odd number only ?
  //assert(RING_LENGTH % 1 == 1);
  localparam DIVIDER_LENGTH = 16;

  wire   master_ena;
  assign master_ena = ena & ui_in[0];

  wire   [RING_LENGTH-1+1 : 0] ring;  // +1
  wire   ring_valve;
  assign ring_valve = (master_ena) ? ring[RING_LENGTH] : 1'b0;
  assign ring[0] = ring_valve;

  generate
    genvar n;
    for(n = 0; n < RING_LENGTH; n = n + 1) begin : ro
`ifdef COCOTB_SIM
      assign #1 ring[n+1] = ~ring[n];
`else
      (* keep, syn_keep *) sg13g2_inv_1 inv_notouch_ (
        .Y    (ring[n+1]),
        .A    (ring[n])
      );
`endif
    end
  endgenerate

  wire [DIVIDER_LENGTH-1+1 : 0] dff_q_clk; // .CLK = .Q (+1 in size)
  wire [DIVIDER_LENGTH-1   : 0] dff_qn_d;  // .D = .Q_N

`ifdef COCOTB_SIM
  reg  [DIVIDER_LENGTH-1 : 0] q;
  wire [DIVIDER_LENGTH-1 : 0] qn;
  initial begin
    q  [DIVIDER_LENGTH-1 : 0] = {DIVIDER_LENGTH{1'b0}};
  end
`endif

  assign dff_q_clk[0] = ring_valve;

  generate
    genvar d;
    for(d = 0; d < DIVIDER_LENGTH; d = d + 1) begin : div
`ifdef COCOTB_SIM
      always @(posedge dff_q_clk[d] or negedge rst_n) begin
        if (!rst_n) begin
            q[d] <= 1'b0;
        end else begin
            q[d] <= dff_qn_d[d];
        end
      end
      assign qn[d]            = ~q[d];
      assign dff_qn_d [d]     = qn[d];
      assign dff_q_clk[d + 1] = q[d];
`else
      (* keep, syn_keep *) sg13g2_dfrbp_1 div_notouch_ (
        .RESET_B  (rst_n),
        .CLK      (dff_q_clk[d]),
        .D        (dff_qn_d [d]),
        .Q        (dff_q_clk[d+1]),
        .Q_N      (dff_qn_d [d])
      );
`endif
    end
  endgenerate

  // All output pins must be assigned. If not used, assign to 0.
  assign uo_out  = {dff_q_clk[               7 : 0]};
  assign uio_out = {dff_q_clk[DIVIDER_LENGTH-1 : 8]};
  assign uio_oe  = 8'hff;

  // List all unused inputs to prevent warnings
  wire _unused = &{clk, 1'b0};

endmodule
