#!/bin/sh
export PLTCOMPILEDROOTS='compiled/debug:'
racket -t rwind.rkt -- --debug
