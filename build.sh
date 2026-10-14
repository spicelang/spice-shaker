#!/bin/sh
set -eu

# Prepare
if [ ! -d build ]; then
    mkdir -p build
fi

# Build
(
  cd ./build || exit
  spice build -m release -o ./spice-shaker ../src/main.spice
)