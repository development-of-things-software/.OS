#!/bin/bash
find . -type f | grep -v LICENSE | grep -v README | grep -v unbios | grep -v install | grep -v .git | grep -v files.txt | grep -v genfilestxt > files.txt
