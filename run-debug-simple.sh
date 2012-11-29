#!/bin/sh
export PLTCOMPILEDROOTS='compiled/debug:'
racket -t rwind.rkt -- --debug --config user-script-examples/simple.rkt
