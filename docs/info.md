<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

The peripheral index is the number TinyQV will use to select your peripheral.  You will pick a free
slot when raising the pull request against the main TinyQV repository, and can fill this in then.  You
also need to set this value as the PERIPHERAL_NUM in your test script.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->


# Digital Integrator Peripheral

Author: Kushal

Peripheral index: 24

## What it does

This project implements a digital integrator peripheral for TinyQV.  
It accumulates signed 8-bit input samples, supports leaky integration, saturation, and threshold detection.  
The accumulator is 16 bits wide, and the peripheral exposes control, status, and configuration registers for flexible operation.

## Register map

| Address | Name        | Access | Description                                                      |
|---------|-------------|--------|------------------------------------------------------------------|
| 0x00    | CTRL        | R/W    | Control: bit0=enable, bit1=sample strobe, bit3=saturation enable |
| 0x01    | STATUS      | R      | Status: bit0=overflow, bit1=threshold                            |
| 0x02    | INPUT       | W      | Input sample (signed 8-bit)                                      |
| 0x03    | ACC_LOW     | R      | Accumulator low byte                                             |
| 0x04    | ACC_HIGH    | R      | Accumulator high byte                                            |
| 0x05    | THRESH      | R/W    | Threshold value for status flag                                  |
| 0x06    | DECAY_SHIFT | R/W    | Leaky integrator decay shift (0=pure, k>0=leaky)                 |

## How to test

1. Run the cocotb testbench in `test/test.py`:
	```sh
	cd test
	make MODULE=test TOPLEVEL=tt_wrapper
    or just 
    make -B
	```
2. The testbench will:
	- Reset the peripheral
	- Enable integration and add samples
	- Check accumulator and status flags
	- Test threshold and overflow behavior

See `test/test.py` for detailed test scenarios.

## External hardware

No external hardware required.  
Inputs/outputs are mapped to PMOD pins for integration and demonstration.
