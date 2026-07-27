# Upstream provenance

`raw_gadget.c` is based on:

- Linux tag: `v7.1`
- Tag object: `b3f94b2b3f3e51ab880a51fc6510e1dafba654ed`
- Peeled commit: `8cd9520d35a6c38db6567e97dd93b1f11f185dc6`
- Upstream file:
  `drivers/usb/gadget/legacy/raw_gadget.c`
- Upstream SHA-256:
  `724c629b713aa99ee7faab162582e18b9666c601c5a7f0c8d3026888cd0503b4`

The DKMS copy adds only kernel-version compatibility branches and includes
`linux/version.h`. Functional behavior follows the matching upstream version:

- gadget-driver registration compatibility before Linux 5.19;
- lifecycle-event compatibility before Linux 6.7;
- allocation and maximum-I/O compatibility before Linux 7.0.

The complete adapted source remains GPL-2.0-only.
