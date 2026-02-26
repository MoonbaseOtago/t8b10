# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    await ClockCycles(dut.rcv_clk, 10)
    for i in range(2000):
        await ClockCycles(dut.rcv_clk, 1)
        if int(dut.done) == 1:
                break


    assert int(dut.fail) == 0

