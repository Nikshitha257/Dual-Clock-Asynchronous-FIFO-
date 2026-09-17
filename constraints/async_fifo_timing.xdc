# -------------------------------------------------------------------------
# 1. Define the physical speed of your clocks
# -------------------------------------------------------------------------
# Set 'wclk' to 100 MHz (10.0 ns period)
create_clock -name write_clk_domain -period 10.000 [get_ports wclk]

# Set 'rclk' to 40 MHz (25.0 ns period)
create_clock -name read_clk_domain -period 25.000 [get_ports rclk]

# -------------------------------------------------------------------------
# 2. The Asynchronous Waiver (CDC Exception)
# -------------------------------------------------------------------------
# Tell Vivado's STA engine to ignore setup/hold times between these specific domains
set_clock_groups -asynchronous -group [get_clocks write_clk_domain] -group [get_clocks read_clk_domain]