#!/bin/sh
export PLTCOMPILEDROOTS='compiled/debug:'
# -j to disable jit, -w debug to see all debug info
#racket -j -W debug -t rwind.rkt -- --debug
racket --no-jit -l errortrace -t rwind.rkt -- --debug

