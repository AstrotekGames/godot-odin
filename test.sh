#!/bin/bash
set -e

cd "$(dirname "$0")/.."
ROOT_DIR="$PWD"

export LD_LIBRARY_PATH="$ROOT_DIR/godot/bin:$LD_LIBRARY_PATH"

mkdir -p out/test

# Symlink GodotSharp to out/test where the binary runs
if [ ! -e "out/test/GodotSharp" ] && [ -d "godot/bin/GodotSharp" ]; then
    ln -sf "$ROOT_DIR/godot/bin/GodotSharp" out/test/GodotSharp
fi

# Use single thread because Godot only supports one instance per process
odin test godot-odin -out:out/test/godot-odin -define:ODIN_TEST_THREADS=1 -extra-linker-flags:"-L$ROOT_DIR/godot/bin -Wl,-rpath,$ROOT_DIR/godot/bin"