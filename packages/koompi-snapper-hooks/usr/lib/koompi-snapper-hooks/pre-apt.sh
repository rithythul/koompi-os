#!/bin/sh
set -e

state_dir=/run/koompi-snapper-hooks
number_file="$state_dir/pre-number"

command -v snapper >/dev/null 2>&1 || exit 0
findmnt -no FSTYPE / 2>/dev/null | grep -q btrfs || exit 0
snapper -c root list >/dev/null 2>&1 || exit 0

mkdir -p "$state_dir"
cmdline=$(ps -o args= -p "$PPID" 2>/dev/null | head -n1)
snapper -c root create --type pre --print-number \
    --description "apt: ${cmdline:-apt}" > "$number_file"
