# Raw Gadget DKMS

Out-of-tree DKMS packaging for Linux's upstream Raw Gadget driver, with
compatibility support from Linux 5.10 through Linux 7.1.

The module exposes `/dev/raw-gadget`, the userspace interface used by USB
emulation tools and TinyUSB's Linux Raw Gadget device-controller backend.

## Install

```sh
git clone https://github.com/HiFiPhile/raw-gadget-dkms.git raw-gadget-dkms
cd raw-gadget-dkms
sudo ./install.sh
```

When run through `sudo`, the installer adds the invoking user to the dedicated
`raw-gadget` group. Log out and back in before opening `/dev/raw-gadget`.
Alternatively, select an account explicitly:

```sh
sudo ./install.sh --user myuser
```

On Debian and Ubuntu, missing DKMS and matching kernel headers are installed
automatically. Other distributions must provide `dkms` and the build headers
for the running kernel before invoking the installer.

The installer also:

- enables automatic DKMS rebuilds after kernel updates;
- loads `raw_gadget` at boot;
- installs a `0660 root:raw-gadget` udev policy;
- loads the module immediately when Secure Boot permits it.

## Secure Boot

DKMS signs the module when the distribution supports module signing. A new
DKMS key still needs explicit enrollment in the machine's MOK trust store.
Follow the distribution's DKMS/MOK procedure, reboot into MOK Manager, enroll
the key, and then run:

```sh
sudo modprobe raw_gadget
```

The installer never disables Secure Boot or silently changes the trust store.

## Compatibility

The source is based on upstream Linux 7.1
`drivers/usb/gadget/legacy/raw_gadget.c` and contains these compatibility
boundaries:

| Kernel | Compatibility behavior |
| --- | --- |
| 5.10–5.18 | Uses `usb_gadget_probe_driver()` |
| 5.19+ | Uses `usb_gadget_register_driver()` |
| Before 6.7 | Lifecycle callbacks remain no-ops because the UAPI event values do not exist |
| 6.7+ | Reports suspend, resume, reset, and disconnect events |
| Before 7.0 | Preserves the historical `PAGE_SIZE` Raw Gadget I/O limit and `kzalloc()` |
| 7.0+ | Uses `KMALLOC_MAX_SIZE` and `kzalloc_obj()` as upstream does |

The maintained support range is enforced by DKMS and the installer: Linux
5.10 through 7.1 inclusive.

To test against a prepared kernel header tree:

```sh
./scripts/build-one.sh /path/to/kernel/build
```

## Continuous integration

GitHub Actions builds the module and runs ShellCheck in official Ubuntu 24.04
and Ubuntu 26.04 containers. GitHub-hosted runners do not currently provide an
`ubuntu-26.04` runner label, so both containers run on the supported
`ubuntu-24.04` Linux runner and install their own distribution
`linux-headers-generic` package.

## Uninstall

Stop any process using `/dev/raw-gadget`, then run:

```sh
sudo ./uninstall.sh
```

The dedicated group is intentionally retained because it may still be assigned
to user accounts.

## License

The driver is derived from the Linux kernel and is licensed under
GPL-2.0-only.
