#!/bin/sh
set -eu

# Prepare
if [ ! -d bin ]; then
    mkdir -p bin
fi

# Build
(
  cd ./bin || exit
  spice test ../test/wrapper.spice
)