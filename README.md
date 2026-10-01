# Dotfiles

Personal AwesomeWM and Alacritty configuration, deployed with GNU Stow.
The live configuration files are symlinks into this repository: editing either
location updates the same files. Never run Stow or Git with sudo for this repo.

## Layout

```text
awesome/.config/awesome/          -> ~/.config/awesome/
alacritty/.config/alacritty/      -> ~/.config/alacritty/
scripts/scripts/                 -> ~/scripts/ (optional)
archive/                         legacy configs; never stow this directory
```

Awesome uses a minimal Dracula-colored wibar, matching window borders, and a
solid black wallpaper. Alacritty imports the bundled Dracula TOML theme.
Only the three named packages above are Stow packages; do not use `stow *`.

## Install on another PC

On Debian/Ubuntu, install the core applications and the font used by the bar:

```sh
sudo apt install git stow awesome alacritty fonts-lato rofi
git clone https://github.com/vVasile29/dotfiles.git "$HOME/.dotfiles"
stow --dir="$HOME/.dotfiles" --target="$HOME" --no-folding --simulate --verbose awesome alacritty
stow --dir="$HOME/.dotfiles" --target="$HOME" --no-folding --verbose awesome alacritty
awesome -k -c "$HOME/.config/awesome/rc.lua"
```

A recursive clone is not needed: required third-party files are included
directly, rather than fetched through submodules.

Alacritty must be version 0.14 or newer for this configuration as written; check
`alacritty --version` because older distribution releases may ship older packages.
`awesome -k` checks Lua syntax, not runtime dependencies or hardware compatibility.
Review the autostart commands before selecting Awesome at login or pressing
Super+Ctrl+R to reload an existing session.

Stow will report conflicts rather than overwrite existing configurations.
Back up or merge conflicting files, then retry. Do not use `--adopt` blindly:
it moves existing target files into the repository and can replace its contents.
`--no-folding` keeps application directories real and links their individual
files, allowing other unmanaged files to coexist in those directories.

## Machine-specific settings

Review `awesome/.config/awesome/rc.lua` before using it on another machine:

| Setting | Current value / requirement |
| --- | --- |
| Battery and charger | `BAT0` and `ADP1`; inspect `/sys/class/power_supply/` on the new PC |
| Desktop without a battery | Disable the battery widget or adapt it to hide when absent |
| Terminal | `alacritty` |
| Font | Lato |
| Menus | The config imports `debian.menu`; adapt this on non-Debian-based systems |
| Launchers | Super+P: `rofi -show drun`; Super+W: `rofi -show window`; Super+R: Awesome's prompt |
| Volume shortcuts | `pactl`, typically supplied by `pulseaudio-utils` |
| Brightness shortcuts | `brightnessctl` |
| Lock shortcut and autostart | `xscreensaver` / `xscreensaver-command` |
| Sync autostart | `/usr/bin/syncthing` |

Alacritty uses TOML with a `[general]` import section, introduced in 0.14.
Version 0.13 needs a top-level `import`; pre-0.13 releases need YAML or an upgrade.
The previous YAML versions are retained in `archive/`.

## Optional hardware scripts

The `scripts` package is not deployed by default. Awesome's autostart calls are
already unconditional: supplying scripts at these paths makes them run on startup
and reload. Review or comment out unwanted autostart lines before deploying:

```sh
stow --dir="$HOME/.dotfiles" --target="$HOME" --no-folding --simulate --verbose scripts
stow --dir="$HOME/.dotfiles" --target="$HOME" --no-folding --verbose scripts
```

Review the scripts first. `monitor_hotplug.sh` assumes `DISPLAY=:0` and outputs
`DP1`/`eDP1` and changes monitor layout using `xrandr` (`x11-xserver-utils` on
Debian/Ubuntu). It requires X11 and also calls `feh` with a machine-specific
wallpaper path, which can override Awesome's black wallpaper.
`connect_keyboard.sh` requires `bluetoothctl` (`bluez`) and a systemd-managed
Bluetooth service. It trusts and disconnects/reconnects a specific Bluetooth
MAC address; check that address before using it. Its sudo call can fail without
a terminal/password prompt during graphical autostart. These scripts are
preserved unchanged, not generalized or deployed automatically.

The optional autostart commands in `rc.lua` can also be disabled if their
programs or scripts are not wanted on a machine.

## Daily use

Edit the live config or its repository source, then review the changes with
`git status` and `git diff`. For newly added package files, run Stow again:

```sh
stow --dir="$HOME/.dotfiles" --target="$HOME" --no-folding --restow awesome alacritty
```

After pulling changes on another PC, restow the packages and reload Awesome.
Use Git commits and pushes deliberately; Stow never commits anything for you.

To remove this repository's links without deleting its source files:

```sh
stow --dir="$HOME/.dotfiles" --target="$HOME" --no-folding --delete awesome alacritty
```

Add other applications as separate packages using their home-relative paths.
For example, `vim/.vimrc` would be linked to `~/.vimrc` by stowing `vim`.
Keep credentials, private keys, application caches, and machine-generated
databases out of the repository. Check changes before committing even though
common secret/cache filenames are ignored.

## Third-party files

The battery widget is vendored from
[deficient/battery-widget](https://github.com/deficient/battery-widget), revision
`0130aa8e66172991c4974bc66a6e18177f396b35`, with its UNLICENSE. Its `init.lua`
is a relative symlink to `battery-widget.lua`; preserve that link when copying.

The active Alacritty Dracula theme comes from
[alacritty/alacritty-theme](https://github.com/alacritty/alacritty-theme), revision
`f82c742634b5e840731dd7c609e95231917681a5`, with its Apache 2.0 license.
The previously present checkout contents are preserved under `archive/alacritty/`.
Required files have no nested Git metadata and can be tracked by this repository
as normal files.

## Migration backup

Before the Stow migration, the complete repository (including uncommitted files
and nested Git metadata) and the two original configuration symlinks were saved
to:

```text
~/.local/state/dotfiles-backup.3kTETUGD/dotfiles.tar.gz
```

The same backup directory also holds the original nested Git directories and
configuration symlinks. This backup is local to the original PC, not part of Git.
Legacy YAML configs, backups, and old theme assets remain under `archive/`.

Existing Alacritty processes may retain the old resolved config path. On the
original PC, `alacritty/alacritty.toml` is a temporary forwarding symlink to the
new source file, excluded from both Git and Stow. After all pre-migration
Alacritty sessions have been closed, it can be removed with:

```sh
unlink "$HOME/.dotfiles/alacritty/alacritty.toml"
```

If a terminal still displays the previous missing-file notice, Ctrl+L clears
Alacritty's stored log notice without closing the session.

To recover the original setup, unstow the active packages first, then extract
the backup into a separate directory for review. Move the current repo aside
and restore the saved `.dotfiles` directory and configuration symlinks only
after checking for newer changes. Do not extract the backup over a live,
modified repository.
