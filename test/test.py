# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    await Timer(40, units='us') # show X

    dut.clk.value = 0
    dut.ena.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await Timer(40, units='us') # show quiscent

    dut._log.info("Enable")
    dut.ena.value = 1
    await Timer(40, units='us') # show ringosc disabled

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())
    await ClockCycles(dut.clk, 10) # show clock running

    dut._log.info("Reset")
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)


    dut._log.info("Test project behavior")

    await ClockCycles(dut.clk, 10)

    # Set the input values you want to test
    dut.ui_in.value = 1
    dut.uio_in.value = 0

    await ClockCycles(dut.clk, 1)
    uio_out = dut.uio_out.value
    uo_out  = dut.uo_out.value

    assert uio_out != 0 and uio_out != 0xff
    assert uo_out != 0 and uo_out != 0xff

    # Wait for one clock cycle to see the output values
    MAX_CYCLES = 10000000
    cycles = 0
    while cycles < MAX_CYCLES:
        await Timer(100, units='ps')

        uio_out = dut.uio_out.value
        uo_out  = dut.uo_out.value

        if uio_out == 0x00 and uo_out == 0x00:
            dut._log.info(f"cycles={cycles} on uo_out={uo_out} uio_out={uio_out}")
            break

        if uio_out == 0xff and uo_out == 0xff:
            dut._log.info(f"cycles={cycles} on uo_out={uo_out} uio_out={uio_out}")
            break

        if (cycles % 100000) == 0:
            dut._log.info(f"cycles={cycles}")

        cycles += 1

    # cycles=3176750
    assert cycles < MAX_CYCLES, f"MAX_CYCLES={MAX_CYCLES} exceeded"

    # let it run on
    await Timer(100, units='ns')

    dut.ui_in.value = 0
    dut.uio_in.value = 0
    await Timer(100, units='ns')
