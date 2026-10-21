#!/bin/bash
# usage: ATTACH_DIR=<dir with generated jpgs> LIB5_DIR=<lib5 data dir> save.sh <hash> <dest-name> [<hash> <dest-name> ...]
# copies a generated image into $LIB5_DIR/src/<dest-name>.jpg and logs it in src/MANIFEST.txt
A=${ATTACH_DIR:?set ATTACH_DIR to the folder holding <hash>.jpg}
L=${LIB5_DIR:-.}
while [ $# -ge 2 ]; do cp "$A/$1.jpg" "$L/src/$2.jpg" && echo "$2 <- $1" >> "$L/src/MANIFEST.txt"; shift 2; done
