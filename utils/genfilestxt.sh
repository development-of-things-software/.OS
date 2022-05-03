#!/bin/bash
find . -type f | grep -v LICENSE | grep -v README | grep -v unbios | grep -v install | grep -v .git | grep -v files.txt | grep -v utils | grep -v dotos.mtar.lua > files.txt
