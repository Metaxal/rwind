#!/bin/sh
#raco setup -c x11 rwind
export PLTCOMPILEDROOTS='compiled/debug:'
X11_RACKET_DEBUG=1 raco setup x11 rwind
