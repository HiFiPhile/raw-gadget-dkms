#!/bin/sh
set -eu

package_name="raw-gadget"
package_version="1.0.0"
source_dir="/usr/src/$package_name-$package_version"

if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    exec sudo -- "$0"
  fi
  echo "Run this uninstaller as root." >&2
  exit 1
fi

if [ -e /dev/raw-gadget ] && fuser /dev/raw-gadget >/dev/null 2>&1; then
  echo "/dev/raw-gadget is in use; stop its process before uninstalling." >&2
  exit 1
fi

modprobe -r raw_gadget 2>/dev/null || true

if dkms status -m "$package_name" -v "$package_version" 2>/dev/null |
   grep -q "$package_name/$package_version"; then
  dkms remove -m "$package_name" -v "$package_version" --all
fi

case "$source_dir" in
  /usr/src/raw-gadget-1.0.0)
    rm -rf "$source_dir"
    ;;
  *)
    echo "Refusing unsafe source path: $source_dir" >&2
    exit 1
    ;;
esac

rm -f /etc/modules-load.d/raw-gadget.conf
rm -f /etc/udev/rules.d/60-raw-gadget.rules
udevadm control --reload-rules

echo "Uninstalled $package_name/$package_version."
