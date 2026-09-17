`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.06.2026 13:39:40
// Design Name: 
// Module Name: async_fifo
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
// -----------------------------------------------------------------------------
// Module: async_fifo (Top Level)
// Description: Structural wrapper instantiating and wiring all 5 sub-modules.
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// Module: async_fifo (top level) - relevant excerpt showing reset synchronization
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// Module: async_fifo (Top Level)
// Description: Structural wrapper instantiating and wiring all sub-modules.
//              Includes per-domain reset synchronizers so wptr_full and
//              rptr_empty release from reset cleanly aligned to their own
//              local clock, preventing cross-domain pointer desync on reset.
// -----------------------------------------------------------------------------
module async_fifo #(
    parameter DSIZE = 8, // Data word size in bits
    parameter ASIZE = 4  // Address width (Memory depth = 2^ASIZE)
) (
    input  [DSIZE-1:0] wdata,  // Data to be written
    input              winc,   // Write enable
    input              wclk,   // Write clock domain
    input              wrst_n, // Write asynchronous reset (active low)
    input              rinc,   // Read enable
    input              rclk,   // Read clock domain
    input              rrst_n, // Read asynchronous reset (active low)
    output [DSIZE-1:0] rdata,  // Data read out
    output             wfull,  // FIFO is full (do not write)
    output             rempty  // FIFO is empty (do not read)
);
    // Internal interconnect wires
    wire [ASIZE-1:0] waddr, raddr;
    wire [ASIZE:0]   wptr, rptr, wq2_rptr, rq2_wptr;

    // Synchronized, per-domain reset release
    wire wrst_n_sync, rrst_n_sync;

    reset_sync wrst_sync_inst (
        .clk(wclk), .async_rst_n(wrst_n), .sync_rst_n(wrst_n_sync)
    );

    reset_sync rrst_sync_inst (
        .clk(rclk), .async_rst_n(rrst_n), .sync_rst_n(rrst_n_sync)
    );
fifo_mem #(DSIZE, ASIZE) mem_inst (
    .rdata(rdata), .wdata(wdata),
    .waddr(waddr), .raddr(raddr),
    .winc(winc),   .wfull(wfull),
    .wclk(wclk),    .rinc(rinc),
    .rclk(rclk)     
);
    // Read-to-Write Synchronizer (Passes rptr to wclk domain)
    // NOTE: stays on RAW wrst_n - must clear immediately, no domain-aligned
    // release timing needed since it only forwards a value, holds no state
    // that the rest of the design depends on being released in sync.
    sync_r2w #(ASIZE) sync_r2w_inst (
        .wq2_rptr(wq2_rptr), .rptr(rptr),
        .wclk(wclk),         .wrst_n(wrst_n)
    );

    // Write-to-Read Synchronizer (Passes wptr to rclk domain)
    // NOTE: stays on RAW rrst_n - same reasoning as above.
    sync_w2r #(ASIZE) sync_w2r_inst (
        .rq2_wptr(rq2_wptr), .wptr(wptr),
        .rclk(rclk),         .rrst_n(rrst_n)
    );

    // Read Domain Logic - uses SYNCHRONIZED reset
    rptr_empty #(ASIZE) rptr_empty_inst (
        .rempty(rempty), .raddr(raddr),
        .rptr(rptr),     .rq2_wptr(rq2_wptr),
        .rinc(rinc),     .rclk(rclk),
        .rrst_n(rrst_n_sync)   // <-- synchronized reset, not raw rrst_n
    );

    // Write Domain Logic - uses SYNCHRONIZED reset
    wptr_full #(ASIZE) wptr_full_inst (
        .wfull(wfull),   .waddr(waddr),
        .wptr(wptr),     .wq2_rptr(wq2_rptr),
        .winc(winc),     .wclk(wclk),
        .wrst_n(wrst_n_sync)   // <-- synchronized reset, not raw wrst_n
    );

endmodule