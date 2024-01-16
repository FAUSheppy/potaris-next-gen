---
title: Linux Error Output colored Red
date: 2017-03-10
description: Color the stderr of Linux red for better visibility
---

![Colored std-err ouput](/color_red/color_red.png)

One of the few things, which always felt inconvenient to me when working in Linux terminals, was the fact that I couldn’t easily differentiate between error output and normal output. Even the windows Powershell has this feature by default. Fortunately I was shown an approach using `LD_PRELOAD`, to preload a custom, self-compiled library, overwriting the output function of *stderr* with functions adding a color-coding. This approach was thought up by [another student at FAU](https://ruderich.org/simon/coloredstderr/) based on some existing work. I use this with *z-shell*, but there is no reason, why it wouldn't work with bash or any other shell-types.

## Compiling
Clone the [repository](https://github.com/FAUSheppy/colorredstderr-mirror). The project is quite old, so any modern system with gcc should be able to compile and run it. It doesn’t have any additional dependencies. Built it with:

    autoreconf -fsi
    ./configure
    make

The relevant resulting file should be available in `./src/libs/`.

## Setup
Now we need to tell our shell how to use this library. As stated in the beginning, I’m using z-shell, so I’m editing `~/.zshrc`. We first need to set the `LD_PRELOAD` variable to the absolute path of our library, then tell the library which file-descriptor(s) to color, via a variable called `COLORRED_STDERR_FDS` (this expects a list, so mind the comma at the end of the line, if you are only using one value) and finally export both of those variables.

    LD_PRELOAD="/absolute/path/to/libcoloredstderr.so"
    COLORED_STDERR_FDS=2,
    export LD_PRELOAD COLORED_STDERR_FDS

This already works, however, as you might soon notice, it only works for stuff started in the ZSH, and not for the ZSH itself, meaning for example: `zsh: command not found:` is not colored. This is because the library has to be preloaded before the ZSH starts. Now there are many ways to fix this, depending on how you start your terminals, but a universal way, which will always work, is to just preload the library and then let your zshrc exec z-shell again. I’ve been doing it like this since forever and it’s barely noticeable.

    if [[ $FIRST_RUN == "FALSE" ]]; then
        ;
    else
        FIRST_RUN="FALSE"
        export FIRST_RUN
        exec zsh
    fi

## Problems
Using this approach rarely causes issues, but I found a few notable programs which do not start with the library preloaded. Those are the signal-client (based on electron) and chromium. Also starting other shells from the colored z-shell may cause issues with the coloring in the sub-shells (e.g. starting ZSH from ZSH is not a problem but starting bash from ZSH is). You may define aliases to `unset LD_PRELOAD`, before starting these applications and keep this in mind, if anything similar (for example another electron application) doesn’t work.


<sup style="font-style: italic;">by Yannik Schmidt</sup><br>
<sup>**Tags:** _Linux, zsh, bash_</sup>
