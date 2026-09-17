// -----------------------------------------------------------------------------
// Module: wptr_full
// Description: Manages the write pointer (binary and Gray) and calculates the 
//              'wfull' flag entirely within the write clock domain.
// -----------------------------------------------------------------------------
module wptr_full #(parameter ASIZE = 4) (
    output reg               wfull,    // FIFO full flag
    output     [ASIZE-1:0]   waddr,    // Binary write address for memory (N-1 bits)
    output reg [ASIZE:0]     wptr,     // Gray write pointer sent to rclk domain (N bits)
    input      [ASIZE:0]     wq2_rptr, // Synchronized Gray read pointer
    input                    winc,     // Write request from external logic
    input                    wclk,     // Write clock
    input                    wrst_n    // Write clock reset
);

    reg  [ASIZE:0] wbin; // Internal binary pointer (includes extra MSB)
    wire [ASIZE:0] wgray_next, wbin_next;
    wire           wfull_val;

    // ---------------------------------------------------------
    // Pointer Generation
    // ---------------------------------------------------------
    // Look-ahead binary counter: Increment only if requested AND not full
    assign wbin_next  = wbin + (winc & ~wfull);
    
    // Look-ahead Gray counter: Shift right by 1 and XOR (Binary -> Gray)
    assign wgray_next = (wbin_next >> 1) ^ wbin_next;

    // Physical memory address strips off the extra MSB wrap-around bit
    assign waddr = wbin[ASIZE-1:0];

    // Register the pointers on the write clock
    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin <= 0;
            wptr <= 0;
        end else begin
            wbin <= wbin_next;
            wptr <= wgray_next; // Send safe Gray pointer out to synchronizer
        end
    end

    // ---------------------------------------------------------
    // Full Flag Generation (The Cliff Cummings Method)
    // ---------------------------------------------------------
    // FIFO is full when the write pointer has wrapped around exactly one time 
    // more than the read pointer. In Gray code, this means:
    // 1. The MSB is inverted.
    // 2. The second MSB is inverted.
    // 3. All remaining LSBs match exactly.
    assign wfull_val = (wgray_next == {~wq2_rptr[ASIZE:ASIZE-1], wq2_rptr[ASIZE-2:0]});

    // Register the full flag to ensure it is glitch-free
    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n)
            wfull <= 1'b0; // At reset, FIFO is completely empty, not full
        else
            wfull <= wfull_val;
    end
endmodule