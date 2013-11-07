# RWind - The Racket Window Manager

An extensible window manager aiming to be similar to [Sawfish](http://sawfish.wikia.com), but written in the [Racket programming language](http://www.racket-lang.org).

There is an [RWind mailing list](https://groups.google.com/forum/?fromgroups#!forum/rwind).


## Warnings

* This package is under current development and is in no way stable, and
  is intended for testing purposes only.
* No backward compatibility will be ensured in the 0.x branch
* Due to a security issue, the current version should not be used on multiple
  user computers. Use at your own risk!


## Current features

* Simple tiling support
* Client command line (repl)
* Customization of key bindings and mouse bindings
* Workspaces with several modes:
    - single mode: one workspace over all monitors
    - multi mode: one workspace per monitor
* xinerama support
* Currently very little ICCCM/EWMH compliance

All these features are in development stage.

## Installation

### 1) Install Racket 
<!-- [Racket](http://www.racket-lang.org) -->

Currently, you will need the [latest version of Racket](http://plt.eecs.northwestern.edu/snapshots/).

### 2) Install RWind:
```shell
raco pkg install rwind
```
(`raco` is provided with Racket, so it should be in your path)

It will ask you if you want to install `x11`. You should say yes as RWind cannot work without this library.

It will also ask you if you want to install the default configuration files.
You should accept unless you know what you are doing.

### 3) In a _login_ shell (try `Ctrl-Alt-F1`), type the following:
```shell
xinit .xinitrc-rwind -- :1 &
```

You may need to modify the display ":1" to ":2" for example if ":1" is not
available.

Now RWind should be running.

## Default configuration 

The default configuration file that you installed provide you with a number of keybinding and mouse bindings 
that you can redefine by editing the file:
 - Alt-left-button to move a window around
 - Alt-right-button to resize the window
 - Alt-tab to navigate between windows
 - Ctrl-Alt-t to open xterm
 - Alt-F4 to close a window
 - Alt-F12 opens the client
 - Super-F{1-4} switches between workspaces
 - Shift-Super-F{1-4} moves the current window to another workspace
 - Alt-Super-F5 switches to `single` workspace mode
 - Alt-Super-F6 switches to `multi` workspace mode
 - ...

You can also modify the default `.xinitrc-rwind` to fit your needs.
By default, you need to close the xterms to exit the session.


<!--
### Installation for use in lightdm/gdm

Do steps 1-4) of the installation above.

1) In RWind's directory, compile and install the executable with:
```shell
raco exe main.rkt && sudo cp rwind /usr/bin
```

2) Copy the provided file rwind.desktop to /usr/share/xsessions/rwind.desktop

3) Close your session, choose RWind in the session menu and open your session.
-->

## The client

The client is a console where you can evaluate expressions.
It can be opened in a terminal with:
```shell
racket -l rwind/client
```

For example, place the mouse pointer on a window and type in the console:
```racket
> (window-name (pointer-window))
```

The list of available symbols provided by RWind is given by:
```racket
> (known-identifiers)
```

All bindings of `#lang racket` are available too.

You can get help on a known identifier with:
```racket
> (describe 'focus-window)
```
