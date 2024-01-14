#!/bin/sh
set -eu

# Prepare
if [ ! -d bin ]; then
    mkdir -p bin
fi

# Build
(
  cd ./bin || exit
  spice build -m release -o ./spice-shaker ../src/main.spice
)