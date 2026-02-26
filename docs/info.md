<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

Contains 8b10 encoder and decoder, 9-bit symbols can be pushed in and results pop out a bunch of clocks later

## How to test

To be added

## External hardware

Set up the board to use a manual clock. The manual clock is divided by 10 to generate the internal clocks

- input data is 9 bit {uio\_in[0], ui\_in}  enable strobe is uio\_in[4]., it is clocked by the clock that is driven onto uioi\_out[6]

- output data is 9 bit {uio\_out[1], uo\_out}  enable strobe is uio\_in[3]., it is clocked by the clock that is driven onto uioi\_out[5]

- during reset uio\_in[0] is samp0led and if high the scrambler is enabled (on both units)

To test:

- only bits 0 and 4 on the bidirectional pins are used as inputs, set the reset of the pins to outputs

- assert reset and set uio\_in[0] to 1 and uio\_in[4] to 0, generate 5 clocks

- deassert reset

- generate 20-30 clocks - note that uio\_out[5] and uio\_out[6] should generate square waves 5 clocks up and 5 clocks down (not necessarily in sync with each other)

- uio\_out[7] should be 0 (not synced)

So send {b[8], b[7:0]}
- send clocks until uio\_out[6] is low

- set uio\_in[4] to 1, set uio\_in[0] to b[8] and set ui\_in to b[7:0]

- send clocks until uio\_out[6] is high

- set uio\_in[4] to 0

----------------------------------

- to start up the link send a COM character {1'b1, 8'hbc}

- run clocks until uio\_out[7] is asserted (indicating thge link is locked) as that happens the output clock may misbehave as it syncs up

- run another 10 clocks

- now send some characters with b[8] set to 0

- after each character wait until uio\_in[3] is asserted and check that the outputs are the same as what you sent in

- repeat the last 2 steps
