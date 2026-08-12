# AMBA AHB-Lite Master-Slave Subsystem with FIFO Integration

## Overview

This project implements an **AMBA AHB-Lite based Master-Slave subsystem** in Verilog HDL. The design supports synchronous read/write transactions using pipelined address/control and data phases. It also incorporates FIFO-based buffering and incrementing burst transfers for efficient data movement between the master and slave.

## Features

* AHB-Lite Master-Slave architecture with pipelined address/control and data phases.
* Configurable read/write transactions with address decoding, transfer-size control, and separate read/write data paths.
* AHB transaction handshaking using `HREADY` and `HRESP`.
* FIFO-based data buffering with full/empty status and controlled read/write pointers.
* Incrementing burst transfers with sequential address progression.
* Verilog testbench for functional verification and waveform-based simulation.

## Project Files

| File              | Description                                                                                         |
| ----------------- | --------------------------------------------------------------------------------------------------- |
| `ahb_system.v`    | Top-level AHB system integrating the master and slave components.                                   |
| `master_ahb_v2.v` | AHB-Lite master responsible for generating addresses, control signals, and read/write transactions. |
| `slave_ahbyt.v`   | AHB-Lite slave responsible for responding to master transactions and handling data transfers.       |
| `tb_ahb.v`        | Testbench used to simulate and verify the AHB system.                                               |

## AHB Features

The subsystem follows the basic AHB-Lite transfer structure with separate **address/control and data phases**. Pipelining allows the address and control information of the next transfer to be presented while the current transfer is completing.

The design supports read and write operations, transaction handshaking, address progression, and sequential/incrementing transfers.

## Verification

The design was verified using **Verilog simulation in Xilinx Vivado**. The testbench applies different read/write transactions and monitors the resulting address, control, data, and handshake signals through simulation waveforms.

## Tools & Technologies

* Verilog HDL
* Xilinx Vivado
* Behavioral Simulation
* AMBA AHB-Lite Protocol

## Future Improvements
Support for multiple AHB-Lite slave devices using address-based slave selection.
Addition of configurable burst types and transfer sizes.
Improved error and response handling using AHB-Lite response signals.
Extended FIFO functionality with configurable depth and data width.
More comprehensive verification using SystemVerilog assertions and functional coverage.
FPGA hardware implementation and testing on a development board.
Performance testing for different transfer patterns and burst lengths.
