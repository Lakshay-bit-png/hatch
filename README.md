# Stash

A macOS menu-bar app that drops down from the top of your screen.

**[Download the latest .dmg →](https://lakshay-bit-png.github.io/stash/Stash.dmg)**
· [Website](https://lakshay-bit-png.github.io/stash/)

Press <kbd>⌘⌥V</kbd> anywhere and a dark panel unfurls from the top edge holding
nine tools:

| Tab | What it does |
|---|---|
| Clipboard | Searchable history of text, links, images and files; pin what matters |
| Focus | A pomodoro with a rocket orbiting Earth, plus a countdown under the notch |
| To-do | Type, Return, done |
| Notes | A scratchpad that titles and saves itself |
| Shelf | Park files you're moving between apps, drag them back out |
| Games | 2048, Minesweeper, Snake, Memory |
| Ask Claude | Bring your own Anthropic API key and chat without leaving the panel |
| System | CPU, memory, battery and disks, read from the kernel |
| Settings | Rebind the shortcut, switch theme, cap the history |

Everything lives in `~/Library/Application Support/Stash`. Nothing is uploaded and
there is no account. The only network request is to Anthropic, and only once you've
added your own API key.

## Build it yourself

```bash
./build.sh        # compiles and assembles Stash.app
./make-dmg.sh     # packages it as a disk image
```

Requires macOS 14+ and a Swift 6 toolchain (Xcode 16 or newer).

## First launch

The app isn't signed with an Apple Developer certificate, so right-click it and
choose **Open** the first time, or run:

```bash
xattr -dr com.apple.quarantine /Applications/Stash.app
```
