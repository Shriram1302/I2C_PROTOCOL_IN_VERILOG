###############################################################################
# Master I2C Constraints - Real Digital Boolean FPGA
###############################################################################

############################################
# Clock Routing Override for I2C Clock (SCK)
############################################
# Allows SCK to use general routing to reach logic resources without placement errors
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -of_objects [get_ports sck]]

############################################
# 100 MHz System Clock
############################################
set_property PACKAGE_PIN F14 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk [get_ports clk]

############################################
# Reset Button (BTN2)
############################################
set_property PACKAGE_PIN H2 [get_ports btn_rst]
set_property IOSTANDARD LVCMOS33 [get_ports btn_rst]

#START
set_property PACKAGE_PIN J1 [get_ports start]
set_property IOSTANDARD LVCMOS33 [get_ports start]
############################################
# I2C Interface (PMOD A Header)
############################################

# SDA (PMOD A Pin 2)
set_property PACKAGE_PIN B13 [get_ports sda]
set_property IOSTANDARD LVCMOS33 [get_ports sda]
set_property PULLUP true [get_ports sda]

# SCK / SCL (PMOD A Pin 1)
set_property PACKAGE_PIN A13 [get_ports sck]
set_property IOSTANDARD LVCMOS33 [get_ports sck]
set_property PULLUP true [get_ports sck]

############################################
# Status LEDs
############################################

# LD0 -> Master Done Status
set_property PACKAGE_PIN G1 [get_ports done]
set_property IOSTANDARD LVCMOS33 [get_ports done]

# LD1 -> Master ACK Error Flag
set_property PACKAGE_PIN G2 [get_ports ack_error]
set_property IOSTANDARD LVCMOS33 [get_ports ack_error]

############################################
# RX Data LEDs (Displays Read Byte from Slave 1 on LD15:LD8)
############################################

# rx_data[7] -> LD15
set_property PACKAGE_PIN A4 [get_ports {rx_data[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rx_data[7]}]

# rx_data[6] -> LD14
set_property PACKAGE_PIN B4 [get_ports {rx_data[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rx_data[6]}]

# rx_data[5] -> LD13
set_property PACKAGE_PIN A3 [get_ports {rx_data[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rx_data[5]}]

# rx_data[4] -> LD12
set_property PACKAGE_PIN B3 [get_ports {rx_data[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rx_data[4]}]

# rx_data[3] -> LD11
set_property PACKAGE_PIN A2 [get_ports {rx_data[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rx_data[3]}]

# rx_data[2] -> LD10
set_property PACKAGE_PIN B2 [get_ports {rx_data[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rx_data[2]}]

# rx_data[1] -> LD9
set_property PACKAGE_PIN C3 [get_ports {rx_data[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rx_data[1]}]

# rx_data[0] -> LD8
set_property PACKAGE_PIN E6 [get_ports {rx_data[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rx_data[0]}]

############################################
# Configuration Bitstream Options
############################################
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]