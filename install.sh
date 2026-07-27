#!/bin/sh
set -eu

package_name="raw-gadget"
package_version="1.0.0"
module_name="raw_gadget"
device_group="raw-gadget"
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
target_user=${SUDO_USER:-}

usage() {
  echo "Usage: sudo ./install.sh [--user USER]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --user)
      [ "$#" -ge 2 ] || {
        usage >&2
        exit 2
      }
      target_user=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    if [ -n "$target_user" ]; then
      exec sudo -- "$0" --user "$target_user"
    fi
    exec sudo -- "$0"
  fi
  echo "Run this installer as root." >&2
  exit 1
fi

kernel_release=$(uname -r)
kernel_major=${kernel_release%%.*}
kernel_rest=${kernel_release#*.}
kernel_minor=${kernel_rest%%.*}
kernel_minor=${kernel_minor%%-*}
kernel_minor=${kernel_minor%%+*}

case "$kernel_major:$kernel_minor" in
  *[!0-9:]*|:*)
    echo "Cannot parse kernel release: $kernel_release" >&2
    exit 1
    ;;
esac

if [ "$kernel_major" -lt 5 ] ||
   { [ "$kernel_major" -eq 5 ] && [ "$kernel_minor" -lt 10 ]; } ||
   [ "$kernel_major" -gt 7 ] ||
   { [ "$kernel_major" -eq 7 ] && [ "$kernel_minor" -gt 1 ]; }; then
  echo "Unsupported kernel $kernel_release; supported range is 5.10 through 7.1." >&2
  exit 1
fi

install_debian_dependencies() {
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    dkms \
    "linux-headers-$kernel_release"
}

if ! command -v dkms >/dev/null 2>&1 ||
   [ ! -f "/lib/modules/$kernel_release/build/Makefile" ]; then
  if command -v apt-get >/dev/null 2>&1; then
    install_debian_dependencies
  else
    echo "Install DKMS and the headers for kernel $kernel_release, then rerun." >&2
    exit 1
  fi
fi

other_versions=$(
  dkms status -m "$package_name" 2>/dev/null |
    grep "^$package_name/" |
    grep -v "^$package_name/$package_version," || true
)
if [ -n "$other_versions" ]; then
  echo "Another raw-gadget DKMS package is already installed:" >&2
  echo "$other_versions" >&2
  echo "Remove that package explicitly before installing this one." >&2
  exit 1
fi

if ! getent group "$device_group" >/dev/null 2>&1; then
  groupadd --system "$device_group"
fi

if [ -n "$target_user" ] && [ "$target_user" != root ]; then
  if ! id "$target_user" >/dev/null 2>&1; then
    echo "Requested user does not exist: $target_user" >&2
    exit 1
  fi
  usermod -a -G "$device_group" "$target_user"
fi

source_dir="/usr/src/$package_name-$package_version"
case "$source_dir" in
  /usr/src/raw-gadget-1.0.0) ;;
  *)
    echo "Refusing unsafe source path: $source_dir" >&2
    exit 1
    ;;
  esac

if dkms status -m "$package_name" -v "$package_version" 2>/dev/null |
   grep -q "$package_name/$package_version"; then
  dkms remove -m "$package_name" -v "$package_version" --all
fi

rm -rf "$source_dir"
install -d -o root -g root -m 0755 "$source_dir"
install -o root -g root -m 0644 "$script_dir/raw_gadget.c" "$source_dir/raw_gadget.c"
install -o root -g root -m 0644 "$script_dir/Makefile" "$source_dir/Makefile"
install -o root -g root -m 0644 "$script_dir/dkms.conf" "$source_dir/dkms.conf"

dkms add -m "$package_name" -v "$package_version"
dkms build -m "$package_name" -v "$package_version" -k "$kernel_release"
dkms install -m "$package_name" -v "$package_version" -k "$kernel_release"

install -o root -g root -m 0644 \
  "$script_dir/config/raw-gadget.conf" \
  /etc/modules-load.d/raw-gadget.conf
install -o root -g root -m 0644 \
  "$script_dir/config/60-raw-gadget.rules" \
  /etc/udev/rules.d/60-raw-gadget.rules

udevadm control --reload-rules

if modprobe "$module_name"; then
  udevadm trigger --subsystem-match=misc --sysname-match=raw-gadget
  echo "Installed $package_name/$package_version for $kernel_release."
  if [ -n "$target_user" ] && [ "$target_user" != root ]; then
    echo "Log out and back in before using /dev/raw-gadget as $target_user."
  fi
else
  echo "The module was built and installed but could not be loaded." >&2
  if command -v mokutil >/dev/null 2>&1 &&
     mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
    echo "Secure Boot is enabled. Enroll the DKMS key, reboot, then run:" >&2
    echo "  sudo modprobe $module_name" >&2
  fi
  exit 1
fi
