#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 /path/to/kernel/build" >&2
  exit 2
fi

kernel_dir=$1
repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
build_dir=$(mktemp -d)

cleanup() {
  rm -rf "$build_dir"
}
trap cleanup EXIT HUP INT TERM

install -m 0644 "$repo_dir/raw_gadget.c" "$build_dir/raw_gadget.c"
install -m 0644 "$repo_dir/Makefile" "$build_dir/Makefile"

make -C "$kernel_dir" M="$build_dir" clean
make -C "$kernel_dir" M="$build_dir" modules W=1
modinfo "$build_dir/raw_gadget.ko" | grep -E '^(filename|vermagic):'
