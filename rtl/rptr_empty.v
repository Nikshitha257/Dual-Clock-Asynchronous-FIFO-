// -----------------------------------------------------------------------------
// Module: rptr_empty
// Description: Manages the read pointer (binary and Gray) and calculates the 
//              'rempty' flag entirely within the read clock domain.
// -----------------------------------------------------------------------------
module rptr_empty #(parameter ASIZE = 4) (
    output reg               rempty,   // FIFO empty flag
    output     [ASIZE-1:0]   raddr,    // Binary read address for memory (N-1 bits)
    output reg [ASIZE:0]     rptr,     // Gray read pointer sent to wclk domain (N bits)
    input      [ASIZE:0]     rq2_wptr, // Synchronized Gray write pointer
    input                    rinc,     // Read request from external logic
    input                    rclk,     // Read clock
    input                    rrst_n    // Read clock reset
);

    reg  [ASIZE:0] rbin; // Internal binary pointer (includes extra MSB)
    wire [ASIZE:0] rgray_next, rbin_next;
    wire           rempty_val;

    // ---------------------------------------------------------
    // Pointer Generation
    // ---------------------------------------------------------
    // Look-ahead binary counter: Increment only if requested AND not empty
    assign rbin_next  = rbin + (rinc & ~rempty);
    
    // Look-ahead Gray counter: Shift right by 1 and XOR (Binary -> Gray)
    assign rgray_next = (rbin_next >> 1) ^ rbin_next;

    // Physical memory address strips off the extra MSB wrap-around bit
    assign raddr = rbin[ASIZE-1:0];

    // Register the pointers on the read clock
    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin <= 0;
            rptr <= 0;
        end else begin
            rbin <= rbin_next;
            rptr <= rgray_next; // Send safe Gray pointer out to synchronizer
        end
    end

    // ---------------------------------------------------------
    // Empty Flag Generation
    // ---------------------------------------------------------
    // FIFO is empty when the *next* read pointer equals the synchronized write pointer.
    // Using look-ahead pointers prevents a 1-cycle delay in flag assertion.
    assign rempty_val = (rgray_next == rq2_wptr);

    // Register the empty flag to ensure it is glitch-free
    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n)
            rempty <= 1'b1; // At reset, pointers are 0==0, so FIFO is instantly empty
        else
            rempty <= rempty_val;
    end
endmodule