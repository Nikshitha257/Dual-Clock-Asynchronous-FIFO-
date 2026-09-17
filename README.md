# Dual-Clock Asynchronous FIFO (Verilog/SystemVerilog)

## Overview
Designed, verified, and implemented an asynchronous FIFO to safely transfer data between two independent, unrelated clock domains (100 MHz write / 40 MHz read). The design uses Gray-coded pointers with 2-stage flip-flop synchronizers to safely cross the clock domain boundary, along with per-domain reset synchronization to prevent reset-recovery timing violations.

Validated through behavioral simulation, post-implementation timing simulation, and Vivado's CDC/Clock Interaction analysis.

## Key Engineering Features

**Clock Domain Crossing (CDC):** Implemented 2-stage synchronizers (`sync_w2r`, `sync_r2w`) with binary-to-Gray pointer conversion to safely pass read/write pointers across asynchronous clock boundaries without multi-bit corruption. Synchronizer stages are tagged with the `ASYNC_REG` synthesis attribute, confirmed via Vivado's CDC report.

**Reset Domain Crossing:** Added a dedicated `reset_sync` module per clock domain so that reset assertion remains immediate while reset release is synchronized to each domain's local clock — preventing recovery/removal timing violations and cross-domain pointer desync immediately after reset.

**Automated Verification Environment:** Self-checking SystemVerilog testbench using a golden reference queue, concurrent randomized read/write cross-traffic, boundary condition tests (fill-to-full, drain-to-empty), and mid-flight hardware reset recovery.

**Physical Implementation:** Targeted a Xilinx Spartan-7 device (`xc7s50csga324-1`). Wrote XDC timing constraints defining both clocks and used `set_clock_groups -asynchronous` to correctly exempt the two domains from cross-clock setup/hold analysis.

**Timing Closure:** Post-implementation Static Timing Analysis: Worst Negative Slack (WNS) = +7.228 ns (setup), Worst Hold Slack (WHS) = +0.104 ns — zero failing endpoints, all constraints met.

**CDC-Verified:** Vivado's CDC analysis report classifies both clock pairs as "No Common Primary Clock" with all synchronizer endpoints marked Safe.

**Resource Utilization (post-implementation):** 28 Slice LUTs, 52 Slice Registers, 0 Block RAM — FIFO memory implemented as distributed LUT-RAM rather than dedicated BRAM, the more efficient choice at this depth.

## Tools & Hardware
- **Hardware Description Language:** Verilog (RTL) + SystemVerilog (testbench)
- **EDA Toolchain:** Xilinx Vivado
- **Synthesis/Implementation Target:** Xilinx Spartan-7 (`xc7s50csga324-1`)

## Repository Structure

| Folder | Contents |
|---|---|
| `/rtl` | Core Verilog design modules (async_fifo.v, fifo_mem.v, sync_r2w.v, sync_w2r.v, wptr_full.v, rptr_empty.v, reset_sync.v) |
| `/tb` | Self-checking SystemVerilog verification environment (async_fifo_tb.sv) |
| `/constraints` | XDC timing constraints and clock definitions |
| `/reports` | Vivado synthesis/implementation utilization reports, post-route timing summary, and CDC analysis report |
