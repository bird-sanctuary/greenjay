# Greenjay

This is an Adaptation of BLHeli for Brushed motors running on brushless hardware.

Only two of the three outputs are used.

Hex files are available in the [Release Section](https://github.com/bird-sanctuary/greenjay/releases), they are all packaged up in one Zip.

**DISCLAIMER:**

This is merely a proof of concept and not under active development.

## Building

The build env is analog to [Bluejay](https://github.com/bird-sanctuary/bluejay/wiki/Development).

If you want your outputs not to be on "phases" A & B, you will need to build your own version. This might be the case when you upcycle your old hardware and the Fets on either of those channels are broken. You will need to adjust the `USE_PHASE_*` variables accordingly in the `Makefile`.

