# RWind - The Racket Window Manager

An extensible window manager aiming to be similar to [Sawfish](http://sawfish.wikia.com), but written in the [Racket programming language](http://www.racket-lang.org).

There is an [RWind mailing list](https://groups.google.com/forum/?fromgroups#!forum/rwind).


First some **warnings**:

* This package is under current development and is in no way stable, and
  is intended for testing purposes only.
* No backward compatibility will be ensured in the 0.x branch.
* Due to a security issue, the current version should not be used on multiple
  user computers. Use at your own risk.


## Current features

* Stacking _and_ [tiling](http://en.wikipedia.org/wiki/Tiling_window_manager) support
* Client command line (repl)
* Customization of key bindings and mouse bindings
* Workspaces with two modes:
    - single mode: one workspace over all monitors
    - multi mode: one workspace per monitor
* Xinerama and RandR support
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

## Start RWind

In a _login_ shell (try `Ctrl-Alt-F1`), type the following:
```shell
xinit .xinitrc-rwind -- :1 &
```

You may need to modify the display ":1" to ":2" for example if ":1" is not
available.

Now RWind should be running.

## Default configuration and Customization

Upon installation, you were asked to create the files `.xinitrc-rwind` and `config.rkt`.

The default `.xinitrc-rwind` is a simple example file that you may want to edit to fit your needs.
By default, you need to close the xterms to exit the session.

Apart from this file, all the customization is done in the configuration file `config.rkt`,
that you can open within RWind with pressing `Alt-F10` by default (this can also be changed in the configuration file).
Take a look at this file to know what keybindings are defined.
You can also of course add you own keybindings.

<!--
This file defines a number of keyboard and mouse bindings that you can easily redefine:
 - Alt-left-button to move a window around
 - Alt-right-button to resize the window
 - Alt-(Shift-)Tab to navigate between windows
 - Ctrl-Alt-t to open xterm
 - Alt-F4 to close a window
 - Alt-F12 opens the client (see below)
 - Super-F{1-4} switches between workspaces
 - Shift-Super-F{1-4} moves the current window to another workspace
 - Alt-Super-F5 switches to `single` workspace mode
 - Alt-Super-F6 switches to `multi` workspace mode
 - Super-Page{Up,Down} moves the window up/down in tiling mode
 - ...
-->

The default window policy is stacking (as for most traditional window managers),
but you can easily change it to [tiling](http://en.wikipedia.org/wiki/Tiling_window_manager) in the configuration file.
With the tiling policy, several layouts are possible: `uniform`, `dwindle` and `dwindle2/5` (and probably more to come).
To choose a layout, specify so in the file:
```racket
(current-policy (new policy-tiling% [layout 'dwindle]))
```

If you edit the configuration file, you will need to restart RWind to be effective,
probably by pressing the keybinding as defined in this very file.
You don't need to recompile RWind, just restart it.

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

The client is a console where you can evaluate Racket expressions and communicate with the window manager.
It can be opened in a terminal with:
```shell
racket -l rwind/client
```

For example, place the mouse pointer on a window and type in the console:
```racket
> (window-name (pointer-window))
```
Or:
```racket
> (move-window (pointer-window) 10 40)
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

You can search among the list of identifiers with:
```racket
> (search-identifiers "window-")
```

If the window policy is tiling, the layout can even be changed from the client:
```racket
> (policy. set-layout 'dwindle)
```

## Updating RWind

RWind has some dependencies, in particular the [X11 FFI bindings](https://github.com/kazzmir/x11-racket),
that will probably need to be updated with RWind.
To do this automatically, specify the `--auto` option to `raco update`:
```shell
raco update --auto rwind
```

**Your RWind configurations file will not be modified by the update.**
This also means that any new feature that may appear in the new versions of these files
will not be added to your files.

If you want to always use the default files and keep up with new features,
you can either:
* remove these files before updating, and you will be asked if you want to add them again,
* replace them by symbolic links to their source file in RWind's package installation directory,
* edit the `config.rkt` file, remove all configuration there and just add `(require rwind/user-files/config-simple)`.

The last option allows you to extend the default configuration with your own commands.

