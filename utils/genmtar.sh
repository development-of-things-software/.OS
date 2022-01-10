#!/bin/bash
# generate an MTAR archive of .OS suitable for loading from CraftOS

set -e
rm -rf /tmp/dotos && mkdir -p /tmp/dotos

for f in $(find rom -type f); do
  mkdir -p /tmp/dotos/$(dirname $f)
  echo $f
  cp $f /tmp/dotos/$f
done

cp unbios.lua /tmp/dotos
cp bios.lua /tmp/dotos

find /tmp/dotos -type f | lua utils/mtar.lua | cat utils/mtarldr_head.lua - utils/mtarldr_foot.lua > dotos.mtar.lua
