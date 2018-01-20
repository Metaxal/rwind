#lang info

(define deps '("x11" "base" "rackunit-lib" "slideshow-lib" "readline-lib" "gui-lib"))

(define test-omit-paths
  '("client.rkt"
    "user-files"
    "launcher.rkt"))