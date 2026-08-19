#!/bin/sh
set -e

number_file=/run/koompi-snapper-hooks/pre-number

command -v snapper >/dev/null 2>&1 || exit 0
findmnt -no FSTYPE / 2>/dev/null | grep -q btrfs || exit 0
[ -s "$number_file" ] || exit 0

pre_number=$(cat "$number_file")
rm -f "$number_file"

cmdline=$(ps -o args= -p "$PPID" 2>/dev/null | head -n1)
snapper -c root create --type post --pre-number "$pre_number" \
    --description "apt: ${cmdline:-apt}"
