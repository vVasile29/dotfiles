# Dotfiles

Personal Dracula configuration for laptops and desktops, deployed with GNU Stow.
The live configuration files are symlinks into this repository: editing either
location updates the same files. Never run Stow or Git with sudo for this repo.

## Layout

```text
awesome/.config/awesome/          -> ~/.config/awesome/
alacritty/.config/alacritty/      -> ~/.config/alacritty/
rofi/.config/rofi/                -> ~/.config/rofi/
gtk/.config/gtk-{3,4}.0/          -> ~/.config/gtk-{3,4}.0/
gtk/.gtkrc-2.0                   -> ~/.gtkrc-2.0
gtk/.config/environment.d/       -> ~/.config/environment.d/
xscreensaver/.xscreensaver       -> ~/.xscreensaver
xscreensaver/.Xresources         -> ~/.Xresources
picom/.config/picom/             -> ~/.config/picom/
scripts/scripts/                 -> ~/scripts/ (optional)
desktop-monitors/scripts/        -> ~/scripts/ (this desktop only)
archive/                         legacy configs; never stow this directory
```

Awesome uses a minimal Dracula wibar, matching notifications, menus, hotkey
help, calendar, window borders and a near-black purple background. Rofi uses
the same palette and Lato UI typography. Alacritty is opaque with DejaVu Sans
Mono and the bundled Dracula TOML theme. This desktop uses Picom for subtle
shadows and fades, without blur or general window transparency. The right side
of the wibar has Dracula status cards for CPU, RAM, network and volume, plus
the system tray and a clock with seconds. There is no separate animation service.
Only the named packages above are Stow packages; do not use `stow *`.

## Install on another PC

On Debian/Ubuntu, install the core applications and the font used by the bar:

```sh
sudo apt install --no-install-recommends git stow awesome xserver-xorg alacritty fonts-lato fonts-dejavu-core fonts-font-awesome rofi pulseaudio-utils pavucontrol htop network-manager-gnome xscreensaver picom x11-xserver-utils libglib2.0-bin python3 qt5-gtk-platformtheme qt6-gtk-platformtheme
git clone https://github.com/vVasile29/dotfiles.git "$HOME/.dotfiles"
python3 "$HOME/.dotfiles/tools/install-dracula-gtk.py"
stow --dir="$HOME/.dotfiles" --target="$HOME" --no-folding --simulate --verbose awesome alacritty rofi gtk xscreensaver picom
stow --dir="$HOME/.dotfiles" --target="$HOME" --no-folding --verbose awesome alacritty rofi gtk xscreensaver picom
awesome -k -c "$HOME/.config/awesome/rc.lua"
```

A recursive clone is not needed: the battery widget and terminal theme are
included directly, rather than fetched through submodules. The installer downloads
the GTK theme separately from a pinned upstream revision, with SHA256 verification.

Select a machine profile as described below before starting Awesome. Laptops
also need `brightnessctl` for backlight shortcuts. Syncthing and the legacy
hardware scripts are not autostarted by either profile. GTK/application styling
is shared by both profiles.

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

The theme, status cards, audio controls, window shortcuts and tiling policy are
shared. Hardware-specific behavior lives in tracked profiles:

| Feature | `laptop` | `desktop` |
| --- | --- | --- |
| Battery | Auto-detected system batteries only | Hidden |
| Brightness keys | Only with a real backlight and `brightnessctl` | Disabled |
| Monitor layout | Keep the current session layout | Run `~/scripts/set_monitors.sh` if installed |
| App placement | No output-specific rules | This workstation's Cliq/JetBrains rules |
| Picom autostart | Off | On if installed; never starts a second compositor |

Create **`~/.config/awesome/machine.lua` locally on each computer**. This is a
real file, not a Stow symlink; it stays outside the repository. Its source-tree
equivalent is also git-ignored as a safeguard. Stow and Git pulls do not change
your local selection. Do not copy this file between computers as part of sync.

```lua
-- This desktop:
return { profile = "desktop" }
```

On the laptop, use `return { profile = "laptop" }` instead, then install
`brightnessctl` and reload Awesome with Super+Ctrl+R. Both profiles keep the
same visual style, normal windows tiled, and fullscreen available.

The loader (`machine_profile.lua`) checks `/sys/class/power_supply` and
`/sys/class/backlight`; it does not assume `BAT0`, `ADP1`, or a backlight name.
Peripheral batteries and UPSes are excluded. Battery widgets are shared across
screens. Brightness shortcuts are registered only when the profile requests
them, a usable backlight exists, and `brightnessctl` is on PATH. Hardware is
checked at startup/reload, not continuously.

With no selector, Awesome uses safe desktop defaults: no battery/brightness
controls, monitor script, output-specific app rules, or compositor autostart.
An invalid selector also falls back safely and shows a notification. It never
silently switches a selected laptop to the desktop monitor layout.

Optional local overrides can disable a feature or replace the monitor script
and app-rule list without editing tracked files. For a different desktop:

```lua
return {
    profile = "desktop",
    monitor_script = false, -- or "scripts/my_monitor_layout.sh", or an absolute path
    app_rules = {},        -- replace, rather than merge, the profile's rules
    compositor = false,
}
```

Supported overrides are `battery`, `brightness`, `compositor`, `monitor_script`,
and `app_rules`. Relative monitor-script paths resolve under `$HOME`; `~/` is
also supported. Review the desktop profile before using its workstation-specific
rules elsewhere. A disconnected configured screen falls back to the client's
current screen. Disabling compositor autostart does not stop an existing daemon.

Profile tests can be run from the repository in an existing Awesome session:

```sh
python3 tests/test_awesome_profiles.py
python3 tests/test_awesome_history.py
```

They use temporary sysfs/config fixtures and do not change the live profile,
monitor layout, brightness or audio state.

Other shared requirements:

| Setting | Current value / requirement |
| --- | --- |
| Battery widget | Laptop profile only, when a system battery is detected; no ACPI listener required |
| Terminal | `alacritty` |
| Font | Lato |
| Terminal font | DejaVu Sans Mono 10.5 |
| Menus | The config imports `debian.menu`; adapt this on non-Debian-based systems |
| Launchers | Super+P: `rofi -show drun`; Super+W: `rofi -show window`; Super+R: Awesome's prompt |
| Volume shortcuts | `pactl`, typically supplied by `pulseaudio-utils` |
| Brightness shortcuts | Laptop profile plus detected backlight and `brightnessctl` |
| Lock shortcut and autostart | `xscreensaver` / `xscreensaver-command` |
| Compositor | Desktop profile: `picom` 12.x; XRender backend, VSync, subtle shadows/fades; no blur |
| Sync autostart | Disabled in both profiles |

Alacritty uses TOML with a `[general]` import section, introduced in 0.14.
Version 0.13 needs a top-level `import`; pre-0.13 releases need YAML or an upgrade.
The previous YAML versions are retained in `archive/`.

### GTK and lock styling

The shared `gtk` package selects **Dracula**, Lato, and Adwaita icons/cursors for
GTK2/3/4 applications. This includes Blueman, Pavucontrol, NetworkManager dialogs
and the GTK3 `xscreensaver-demo` preferences window. Install the actual theme once
on each computer; Stow deploys settings, not third-party theme assets:

```sh
python3 ~/.dotfiles/tools/install-dracula-gtk.py
stow --dir="$HOME/.dotfiles" --target="$HOME" --no-folding --verbose gtk awesome
```

The installer uses `dracula/gtk` revision
`71640b9456110f3bac2130d0b387a3154a9fb4d2`, verifies the archive SHA256, safely
extracts it, and installs GTK assets plus their GPL-3.0 license under
`~/.local/share/themes/Dracula` (or `$XDG_DATA_HOME/themes/Dracula`). It runs no
downloaded scripts, needs no sudo, is idempotent for that revision, and refuses
to overwrite an existing unrelated theme. Python needs tarfile's safe `data`
extraction filter. For offline installation, use `--archive /path/to/archive.tar.gz`;
the same checksum is required. Legacy GTK2 apps may also need `gtk2-engines-murrine`.

At Awesome startup, `appearance.lua` applies matching GSettings preferences:
Dracula, dark mode, a purple accent, Lato, and Adwaita icons/cursors. If the theme
is absent, its GSettings selection falls back to `Adwaita-dark`. GTK3/4 share
these settings and disable animations. No global `GTK_THEME` variable or user
CSS override is injected. Libadwaita apps may retain their own widget styling;
they receive the native dark preference and purple accent instead of forced CSS.

Qt Widgets use the distro's **GTK3 platform-theme plugin** and Fusion rendering
to pick up the GTK palette, fonts, and icons. Both `qt5-gtk-platformtheme` and
`qt6-gtk-platformtheme` are needed for their respective apps. Defaults are set in
`~/.config/environment.d/60-dracula.conf` for user services and in Awesome's
environment for newly launched apps; explicit app/session environment choices
still take precedence. Apps with custom rendering, Qt Quick, Java, Electron,
Flatpak or Snap packaging may need app-specific settings or additional theme
access. There is no promise that every application's private UI can be overridden.

Reopen already-running GTK apps after applying the settings. Log out/in to ensure
all launch paths, including old terminals, inherit the Qt defaults. The current
desktop's prior GSettings were saved under
`~/.local/state/dotfiles-appearance-backup.x5fd5pzm/` before application. The
Bluetooth manager/applet and lock daemon were not killed or restarted.

XScreenSaver blanks and locks after ten idle minutes with no grace period.
DPMS standby/suspend are ten minutes and power-off is fifteen minutes. The
companion `.Xresources` styles its password dialog in Dracula. Awesome merges
those resources before starting the daemon. An already running daemon needs
`xscreensaver-command -restart` once after changing resources. Do not replace
an existing `.Xresources` without merging any unrelated settings first.

The same `.Xresources` also sets `Xcursor.theme: Adwaita` and `Xcursor.size: 24`.
This avoids oversized cursors in X11 clients when the rotated monitor increases
the virtual desktop height. Apply changes with `xrdb -merge ~/.Xresources`;
applications that cache cursor settings may need restarting.
XScreenSaver 6.09 applies its DPMS timers on the first blanking cycle, rather
than immediately at daemon startup. No animated screensaver runs in blank mode.

### Shared and laptop controls

| Shortcut / interaction | Action |
| --- | --- |
| Audio/microphone media keys | Volume -/+5% or mute, with OSD |
| Ctrl+media keys | Retained aliases for the previous configuration |
| Brightness media keys / Ctrl+brightness keys | Laptop profile: hardware backlight -/+5%, with OSD |
| Super+F5 / Super+F6 | Laptop profile: brightness fallback |
| Alt+L or Super+Shift+F12 | Lock screen |
| Super+Shift+Escape | Session menu: lock, suspend, log out, reboot, power off |
| Left-click clock | Toggle calendar; scroll to change month; click calendar to close |
| Left-click CPU or RAM | Open `htop` in Alacritty |
| Hover CPU or RAM | Show all recorded usage history for the current boot |
| Left-click network | Open `nm-connection-editor` |
| Scroll volume | Volume -/+5%, with OSD |
| Left/right-click volume | Mute / open `pavucontrol` |
| Click TRAY on any monitor | Open the native tray on that display; click again or × to close |

The status module (`awesome/.config/awesome/status.lua`) shares a single
two-second CPU/RAM/network sampler across all monitors. Memory usage excludes
available/reclaimable memory. Network traffic follows the default route, not
Docker bridges; rates appear above 1 KiB/s, with details on hover. `LINK` means
a default route exists, not that Internet access has been verified. Audio is
event-driven via one `pactl subscribe` process, cleaned up on Awesome exit/reload.
Chips reserve fixed space for their readings, including idle/active network
traffic, so updates do not shift the task list. CPU/RAM meters turn yellow
above 75% and red above 90%. FontAwesome supplies the
icons. The clock uses fixed-width digits and a shorter date on narrow monitors.
CPU/RAM hover cards show the full recorded history for the current boot, with a
fixed 0–100% scale and a timestamp-based horizontal axis, newest on the right.
Live samples arrive every two seconds. History is bounded to 512 points per
metric: older readings are progressively combined using weighted averages,
preserving the complete recorded time span rather than dropping old readings.
The first and latest readings stay exact; older short spikes may be smoothed.

History is checkpointed every 30 seconds and on Awesome exit/reload to
`~/.cache/awesome/usage-history.tsv`. It survives reloads and later logins during
the same boot, and resets when the Linux boot ID changes. Sampling begins when
Awesome starts at desktop login; usage before tracking began, or while Awesome
was not running, cannot be recovered. The graph labels show the actual recording
start, not a claim of measurements from power-on. No extra daemon is installed.
Audio events and redraws do not add samples or change the time scale. Chip widths
and their inline meters remain unchanged.

Every monitor has a matching `TRAY` button. Awesome's native XEmbed tray can only
exist once, so the buttons open one shared tray drawer on the selected monitor
instead of trying to duplicate its icons. The drawer stays open for interacting
with tray applications and menus; close it with × or its active button. Buttons
are dimmed while no tray icons exist. `tray.lua` owns the single tray widget.

The session menu confirms logout/reboot/power-off and requests a lock before
suspending. OSD updates are event-driven; their timer runs only while visible.
On the laptop profile, brightness targets real hardware, not `xrandr`
software dimming, and requires `brightnessctl`. Debian's
`brightness-udev` dependency grants access to the `video` group. If permissions
are not applied immediately after installation, reload udev rules and trigger
the backlight device, or reboot. Confirm `id` includes `video`. No privileged
brightness commands or custom sudo rules are used in the desktop configuration.

## Picom compositor

The `picom` Stow package provides `~/.config/picom/picom.conf`. Its Picom 12
window rules recreate the old desktop's shadow/fade preferences without
restoring deprecated per-window options. The desktop profile starts it at
login/reload if installed, unless Picom or Compton is already running for this user.
Flameshot and XScreenSaver windows are excluded from shadows/fading. Application
opacity is respected; only tooltips are explicitly set to 75% opacity.

```sh
sudo apt install --no-install-recommends picom
stow --dir="$HOME/.dotfiles" --target="$HOME" --no-folding --simulate --verbose picom
stow --dir="$HOME/.dotfiles" --target="$HOME" --no-folding --verbose picom
```

Check rendering, fullscreen behavior, screenshots and lock/unlock after
activation, especially with mixed monitor refresh rates. Do not start a second
compositor alongside an existing one.

## Desktop monitor layout

The separate `desktop-monitors` Stow package provides `~/scripts/set_monitors.sh`.
The desktop profile runs it at login and reload if present; the laptop profile
does not. It recreates this desktop's
reviewed layout, without using GNOME settings:

| Position | Output | Mode | Rotation | Refresh | Offset |
| --- | --- | --- | --- | --- | --- |
| Left | HDMI-A-0 | 2560x1440 | left (portrait) | 59.95 Hz | 0x0 |
| Middle, primary | DisplayPort-2 | 2560x1440 | normal | 74.92 Hz | 1440x473 |
| Right | DisplayPort-1 | 2560x1440 | normal | 74.92 Hz | 4000x473 |

These are the highest reported rates at the maximum advertised resolution on
the currently connected monitors. Recheck with `xrandr --query` if hardware or
connections change. If any expected monitor is disconnected, the script leaves
the layout unchanged and reports an error rather than partially applying it.

```sh
stow --dir="$HOME/.dotfiles" --target="$HOME" --no-folding --simulate --verbose desktop-monitors
stow --dir="$HOME/.dotfiles" --target="$HOME" --no-folding --verbose desktop-monitors
sh "$HOME/scripts/set_monitors.sh" --dryrun
sh "$HOME/scripts/set_monitors.sh"
```

The script inherits session display/authentication variables. It is not a
continuous hotplug watcher; run it again after reconnecting monitors, or reload
Awesome. Do not deploy this machine-specific package unchanged on a laptop.

## Optional hardware scripts

The `scripts` package is not deployed by default. Legacy hardware-script
autostart is disabled in both profiles; deploying the files alone will not run
them. Review scripts before explicitly selecting a monitor script in `machine.lua`
or adding any other autostart commands:

```sh
stow --dir="$HOME/.dotfiles" --target="$HOME" --no-folding --simulate --verbose scripts
stow --dir="$HOME/.dotfiles" --target="$HOME" --no-folding --verbose scripts
```

Review the scripts first. `monitor_hotplug.sh` assumes `DISPLAY=:0` and outputs
`DP1`/`eDP1` and changes monitor layout using `xrandr` (`x11-xserver-utils` on
Debian/Ubuntu). It requires X11 and also calls `feh` with a machine-specific
wallpaper path, which can override Awesome's configured background.
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
stow --dir="$HOME/.dotfiles" --target="$HOME" --no-folding --restow awesome alacritty rofi gtk xscreensaver
```

After pulling changes on another PC, restow the packages and reload Awesome.
Use Git commits and pushes deliberately; Stow never commits anything for you.

To remove this repository's links without deleting its source files:

```sh
stow --dir="$HOME/.dotfiles" --target="$HOME" --no-folding --delete awesome alacritty rofi gtk xscreensaver
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

The October 2026 rice update preserved the original Rofi and GTK3 settings in
`~/.local/state/dotfiles-rice-backup.EPNTNT/` on the original laptop. This local
directory also contains `tracked-before-rice.tar`, a snapshot of the previously
committed dotfiles. These backups are not part of Git.

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
