#!/bin/sh
export PLTCOMPILEDROOTS='compiled/debug:'
# WARNING: Docs say we should throw away .zo files!
#racket --no-jit -l errortrace -t rwind.rkt -- --debug --config user-script-examples/simple.rkt
racket --no-jit -l errortrace -t main.rkt -- --debug --config user-script-examples/simple.rkt
