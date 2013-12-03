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

## Installation & quick Start

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

### 3a) Start RWind

In a virtual terminal (`Ctrl-Alt-F1`), type the following:
```shell
xinit .xinitrc-rwind -- :1 &
```

You may need to modify the display ":1" to ":2" for example if ":1" is not
available.

Now RWind should be running.

### 3b) Installation for use in lightdm/gdm

Alternatively, you can install RWind in the session manager, so that you can choose RWind in the
options of the login screen.

To do so, type:
```shell
sudo racket -l rwind/install-session
```
This will create (or overwrite if you say so) the following files:
* `/usr/share/applications/rwind.desktop`
* `/usr/share/xsessions/rwind.desktop`
* `/usr/local/bin/rwind.start`

Note that this method is likely to give better results than the bare `.xinitrc-rwind` approach
as more (X, non-RWind) modules are loaded automatically.

Now go back to the login screen. You should see RWind in the login options.

The `.xinitrc-rwind` file is not used for this configuration.
If you wish to add startup applications and start some daemons, you can edit the `rwind.start` file.

<!--
### 3c) Replace your current window manager

It is also possible to load a normal session with your usual window manager,
then kill it and replace it with RWind.
For example, supposing you are using Metacity:
```shell
killall metacity && racket -l rwind
```

Strange results are likely to show up though.
-->

## Default configuration and customization

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
With the tiling policy, several layouts are possible (mainly `uniform` and `dwindle`).
To choose a layout, specify so in the file:
```racket
(current-policy (new policy-tiling% [layout 'dwindle]))
```

If you edit the configuration file, you will need to restart RWind to be effective,
probably by pressing the keybinding as defined in this very file.
You don't need to recompile RWind, just restart it.

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
> (search-identifiers "window")
```

You can get the list of existing layouts for the tyling policy:
```racket
> (policy. get-layouts)
```
The layout can be changed immediately:
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

