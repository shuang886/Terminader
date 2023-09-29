# <img alt="App icon" src="https://github.com/shuang886/Terminader/assets/140762048/7a836c30-16ee-4daf-89b4-f476a7c0234e" width="64" align="center"> Terminader

## Why are Finder and Terminal separate apps?

This is an experiment that challenges the status quo set literally decades
ago. Finder and Terminal are separate interfaces to the file system and
applications, but should they be?

Termina-der, half Terminal and half Finder, is my attempt at answering that
question.

<img width="779" alt="main UI window with a grid of icons representing the current directory" src="https://github.com/shuang886/Terminader/assets/140762048/0842a118-2e47-4e96-862a-861209f65eb7">

### Before we proceed

> **This is a toy, which means I didn't implement most of the destructive
actions like deleting files. However, the command line shell is *live* and can
do whatever you type in it. Terminader is *not* sandboxed and it's *not* a
simulation.**

For the rest of this article, I'll refer to Terminader's command-line
interface as the CLI and its graphical interface as the GUI, so that the words
"Terminal" and "Finder" can refer to the built-in macOS apps.

### The current working directory

The first important realization is that both Finder and Terminal have a strong
sense of the current working directory, so in Terminader the two interfaces
share it. Simply use the GUI/CLI button
<img width="74" alt="screenshot of button to toggle between GUI and CLI modes" src="https://github.com/shuang886/Terminader/assets/140762048/23c09b4f-d245-44ba-8cc1-7cd2b9253a59" align="center">
to flip between the two interfaces to the same current working directory.

But Finder provides a few other ways to move around:

- The sidebar takes you to a configurable set of favorites and other
locations, and clicking on them simply changes the current working directory.

- Folders you navigate into are added to a web browser-style history, where
you can easily go back and forward with a single click.

- A picker (a ⌘-click in Finder) lets you navigate up to any of the current
working directory's parent directories.

All of these are replicated in Terminader and also change the current working
directory on the CLI side. In addition, you can issue the enhanced `pwd back`
or `pwd forward` CLI commands to move about the history.

### Selection

Both Finder and Terminal support powerful ways to select files to act on.
Terminal is especially powerful if a wildcard (e.g., `A*.txt` to select text
files that start with "A") suits your needs, and Finder is powerful if your
choices are somewhat arbitrary.

<img width="219" alt="screenshot of paste button with a badge indicating three items had been selected" src="https://github.com/shuang886/Terminader/assets/140762048/2d544933-b09d-4893-a0d9-19b75e441144">

Terminader has the best of both by also unifying selections. When you select
files on the GUI side and then flip to the CLI side, the paste button
indicates how many files have been selected, and would paste the list to your
command line with one click. This is analogous to dragging selected files from
a Finder window into a Terminal.

But that's not the end of it. Terminader introduces two new commands, `select`
and `deselect`, that can modify the selection using wildcards. So you might
`select *.txt` on the CLI side, and then flip to the GUI side and deselect the
two or three that you didn't actually want.

## What about the Shell?

The astute reader will have pointed out by now that some of what I've been
calling features of "Terminal" are actually implemented in the Shell, yet
another piece of software. That is entirely correct, for our concepts to work
we need to break that wall too.

Modern terminal emulators are aware of certain contexts within the shells they
spawn, such as the current working directory. But possibly to respect a user's
choice of shells, or perhaps in adherenence to the Unix philosophy of just
doing your own thing well, the integrations I'm aware of are relatively
minimal and rely on gross escape sequences. As a result, we use little more of
the computer's capabilities than a VT100 terminal that shipped in 1978 did.
Let's take this opportunity to rethink a few things, beyond just GUI-CLI
integration.

### Why is stderr mixed in together with stdout?

If you've ever used a command-line program that actually emits output to
`stderr`, it probably just clobbers the regular output to `stdout`, because
terminal emulators just put them all on screen.

Terminader puts `stderr` output in its own pane called "Error", and if a
program only output to `stderr`, it would be mirrored in the regular "Console"
pane to serve as user feedback.

### Why are unrelated commands all just dumped into a massive undifferentiated log?

We actually know what output correlates with which user command. This allows
us to render them in a way that is distinct from the output of other commands.

Terminader encloses the output from each user command in a rectangle. A green
rectangle indicates that the command executed successfully (termination status
0), while a red rectange indicates an error was encountered, and a cyan
rectangle indicates the command is still running.

<img width="779" alt="screenshot of CLI with output of a command enclosed in a green rectangle" src="https://github.com/shuang886/Terminader/assets/140762048/fb5868bc-5762-4174-9dd0-c7678c926361">

### So what?

It means you can filter the log and exclude the outputs of entire commands. It
means we can automatically attach a timestamp to a command.

It means you can pop the output block out to its own window, to easily "pin"
it without creating a new terminal pane.

I didn't continue to flesh out this concept, but you should be able to save
the output to a file or send it to a printer after the fact, instead of either
attempting a large click-and-drag selection, or re-running the program to
redirect its output.

### Why are we stuck with plain text?

Sure, `man` uses boldface and underline, and `ls` uses colors, but we're still
leaving a lot of untapped potential. Modern terminal emulators have
[invented](https://en.wikipedia.org/wiki/Sixel)
[several](https://sw.kovidgoyal.net/kitty/graphics-protocol/)
[ways](https://iterm2.com/documentation-images.html) to output graphics, but
they all rely on clunky escape sequences, and don't really solve more general
problems. It takes a [valiant
effort](https://wezfurlong.org/wezterm/hyperlinks.html) to even allow a
hyperlink to be clickable.

Terminader allows an application to output
[MIME](https://en.wikipedia.org/wiki/MIME). Output that begin with:

```
    MIME-Version: 1.0
```

are treated as MIME output, and the following MIME headers are honored:

#### Content-Type: image/*

The image itself must be Base64-encoded because I couldn't figure out how to
get the pipe to stop converting LF (line feed) characters into CR (carriage
return) LF pairs and corrupting the image data. But otherwise if `NSImage` can
decode the format, it should display on screen.

A new `cat` command uses this ability to display an image in the CLI.

<img width="779" alt="screenshot of cat command outputting an image" src="https://github.com/shuang886/Terminader/assets/140762048/b7cbadef-ca14-4c40-a386-fdd82753e31e">

#### Content-Type: text/markdown

Markdown provides not only formatted text output, but also hyperlinks.
Terminader includes a rudimentary new `ls` command that outputs hyperlinks
that are used to invoke contextual actions.

The new `cat` command treats files with an `.md` extension as Markdown
documents.

#### Content-Type: text/plain

This isn't really necessary because you could just not output the
`MIME-Version` header, but it's there.

#### Content-Transfer-Encoding:

Only `base64` is supported at this point.

### What Next?

MIME enables rich CLI output, and there are some interesting avenues to
explore:

- Piping MIME output among command-line utilities, such as ImageMagick.

- Avoiding [mojibake](https://en.wikipedia.org/wiki/Mojibake) by using
`charset` to render text correctly.

But if you mean whether Terminader is likely to become a real tool, it
probably won't. SwiftUI is great at rapid prototyping (all this took me a bit
over a week) but the real work of integrating the full features of Finder,
Terminal, various shells, and many Unix tools is massive. Such a venture would
also likely need private Apple APIs, and likely will break constantly with new
macOS versions.

## System Requirements

Intel or Apple Silicon Mac running macOS 14 (Sonoma). If you cannot use
Sonoma, defining the `SUPPORT_IME` flag and making your own build should still
mostly work.

## Known Issues and Excuses

- Interactive programs are not going to work. That includes `vi`, but also
programs like `top` that fairly randomly addresses the terminal screen.

- Internal commands don't handle quotes and backslash-escapes.

- Contextual actions in the CLI are invoked by clicking on the link. I can't
figure out how to make `AttributedText` links require a ⌘-click.

- Contextual action pop-ups in the CLI aren't anchored to the link you clicked
on.

- The "Get Info" contextual action opens a window and does nothing.

- If you "Show Tab Bar", the tabs will have blank titles. SwiftUI doesn't seem
to allow me to hide the window title but populate the tab title.

- There's a long delay in the GUI when you select the first file. I can't
quite get all the gestures to work simultaneously.

- ⌘A to select all the files would be nice, but I can't get SwiftUI keyboard
handling to work quite right.

- The CLI prompt can lose keyboard focus and stop accepting input but still
happily blink as if it had focus. You can click on the cursor area to give it
back the focus.

## Hack

The `scripts` directory holds scripts that are searched first, so they can be
used to override real commands. For example, the `man` script overrides the
pager to return its entire output, but without losing the nice formatting.

## Acknowledgements

- [apple /
swift-argument-parser](https://github.com/apple/swift-argument-parser) for
command-line parsing.

- [eonil / FSEvents](https://github.com/eonil/FSEvents) to monitor changes in
the current directory.

- [gonzalezreal /
swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui) for
Markdown rendering.

- [ksemianov / WrappingHStack](https://github.com/ksemianov/WrappingHStack)
for the GUI grid.

- Last but not least, friends I will not name for reasons have contributed
important ideas, pointers, and encouragement.
