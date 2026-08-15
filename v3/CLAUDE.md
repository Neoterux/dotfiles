# Hyprland + Quickshell rice — project context

This repo is `labfernandez2014@gmail.com`'s Hyprland setup on Arch Linux
("GMachine", dual monitor DP-1 2560x1440 + DP-3 1920x1080, gruvbox theme).
It has two living parts:

- **`hyprland-neo/`** — the active Hyprland config, written in Lua against
  Hyprland 0.56.1's native Lua config API (`hl.*`). `hyprland.lua` is the
  entrypoint. `hyprland-legacy/` is the old `.conf`-based config, kept for
  reference only — don't edit it expecting it to do anything.
- **`quickshell/`** (symlinked in as `hypr/quickshell` from `../quickshell`)
  — a custom Quickshell (QtQuick/QML Wayland shell toolkit) status bar that
  replaced Waybar. This is where most day-to-day UI work happens.

## Role expected of Claude here

Act as an expert in QML/QtQuick and in Hyprland's Lua config surface and
IPC. The shell is a live product, not a one-off script: prioritize —

1. **Efficient UI/settings surface** — the bar + drawer system (see below)
   is the extension point for anything the user wants surfaced or
   controllable at a glance.
2. **Low resource usage** — prefer Quickshell's reactive services
   (`Quickshell.Services.Pipewire`, `.Mpris`, `.Hyprland`, `.Bluetooth`,
   `.SystemTray`) over polling. Where polling is unavoidable (CPU/mem/temp,
   which have no push API), keep intervals as loose as the UI can tolerate
   and reuse a single `FileView`/`Timer` instead of spawning a `Process`
   per tick. Current cadence: CPU+mem+temps every 2s (`PerformanceTab.qml`),
   network route check every 10s (`NetworkStatus.qml`), backlight every 1s
   only while a backlight device exists, uptime every 60s. Loosen these
   first if memory/CPU ever becomes a real concern.
3. **Extensibility** — new integrations (Discord/Steam-style tray applets,
   media players, future dashboards) should slot into the existing
   patterns below rather than growing new ad hoc mechanisms.

## Quickshell architecture

```
quickshell/
  shell.qml                 entrypoint: one PanelWindow per Quickshell.screens,
                             owns the per-monitor uiScale table
  theme/Colors.qml           pragma Singleton gruvbox palette — Colors.accent, etc.
  modules/
    bar/                     the bar itself + every left/right module
      Bar.qml                 left/center/right layout, full-width, no border
      Pill.qml, IconButton.qml  the two reusable building blocks every module wraps
      Slider.qml
      Launcher.qml, Backlight.qml, Volume.qml, Workspaces.qml
      NetworkStatus.qml, BluetoothButton.qml, Terminal.qml, Processes.qml
      PowerMenu.qml, PowerMenuButton.qml
      Clock.qml               centered, hover-opens the Dashboard drawer
    tray/                    SystemTrayRow.qml + TrayItem.qml (StatusNotifierItem/SNI)
    drawer/Drawer.qml        the ONE shared dropdown/popup component (see below)
    dashboard/               content shown inside Clock's drawer, tabbed
      Dashboard.qml            tab bar + Loader switching between the 4 tabs
      DashboardTab.qml, Calendar.qml
      MediaTab.qml, PerformanceTab.qml, RingGauge.qml, WorkspacesTab.qml
    launcher/                AppLauncher.qml (search+grid) + LauncherPanel.qml (its window)
```

Cross-folder references need an explicit relative `import "../drawer"` etc.
(QML only auto-resolves types within the *same* directory). `theme/` is two
levels up from any `modules/<subfolder>/*.qml`, so it's `import "../../theme"`.

### The `uiScale` chain

`shell.qml` has a `monitorScale` table keyed by output name (`hyprctl
monitors` names, e.g. `"DP-1"`) so each monitor's bar — and everything that
hangs off it, including drawer contents — can be sized independently. This
is how HiDPI/mixed-DPI monitors are handled: **every** component that has a
pixel size takes a `uiScale` property and multiplies its sizes by it, and
every parent forwards its own `uiScale` down to children it instantiates.
When adding a new module or dashboard tab, thread `uiScale` through it the
same way — a component with a size that doesn't scale is a bug, not a
style choice. `Drawer.qml` and everything under `dashboard/` take
`uiScale` too, not just the bar row — the drawer's own PopupWindow content
looked wrong/tiny on scaled monitors before this was wired through
end-to-end.

### `Drawer.qml`

The shared dropdown used by Clock, Volume, BluetoothButton, PowerMenu.
It's a `PopupWindow` anchored to the item that opens it (`anchorItem`),
sized to its content, glass background (`Colors.bgTranslucent` + Hyprland
compositor blur, see below) + shadow + open/scale animation. **Deliberately
plain rounded corners, no border, no cutout/connector effect in the gap
between bar and drawer** — several attempts at a caelestia-style
"contracurva" effect (concave cutout, outward wing bulge, a little
connector tab in the gap) were all tried and rejected as looking wrong;
caelestia's actual effect is SDF/metaball rendering from a compiled C++
plugin, not reproducible in plain QML/JS. Don't reattempt this without a
concrete new approach — plain rounded corners is the settled answer.

### Real gotchas (not obvious from reading the code cold)

- **Nerd Font glyphs**: never paste the literal glyph character — it
  unreliably saves as an empty string depending on the edit path. Typing
  the `\uXXXX` / `\u{XXXXX}` escape as literal text in an Edit/Write call
  is the right idea but **still not reliable** — in one sweep across this
  repo, some Edit calls with that exact escape text silently produced a
  real glyph and others silently produced an empty string, with no error
  either way, and `Read`-ing the result back doesn't tell them apart (PUA
  glyphs render invisible in most fonts, so a "successful" real glyph and
  a truly-empty string can look identical in a Read/grep). **Never trust
  a visual/Read check for these.** The reliable loop:
  1. Write the icon with the `\uXXXX` text as usual.
  2. Verify with a byte/codepoint check, not a Read:
     `python3 -c "print([hex(ord(c)) for c in open('file').readlines()[N-1]])"`
     (or grep the line and `od -An -tx1` it — UTF-8 for `U+F0XX` is three
     bytes starting `ef`).
  3. If the codepoint isn't there, don't just retry the same Edit blindly
     — fix it deterministically with Python instead (bypasses whatever in
     the tool pipeline drops the character):
     `python3 -c "..."` that opens the file, does a targeted
     `str.replace`/`re.sub` inserting `chr(0xF0XX)` at the right spot, and
     writes it back. This has been 100% reliable every time the escape-text
     Edit wasn't.
  4. After any icon fix, `grep` the whole tree for the trailing `// nf-*`
     comment convention and codepoint-check every hit — this repo has
     accumulated real empty-glyph bugs this way more than once, in files
     nobody was actively editing at the time.
- **`MouseArea` as a direct child of a `Layout`** (RowLayout/ColumnLayout/
  GridLayout, i.e. a sibling of `Layout.*`-using items) is undefined
  behavior in QtQuick and misaligns the click target. Fix: wrap the visual
  content + a `MouseArea { anchors.fill: parent }` together inside a plain
  `Item`, and put `Layout.*` on that `Item`, not on the MouseArea or its
  siblings.
- **`PopupWindow` with `grabFocus: true` silently fails to render** — no
  error, `visible` stays true internally, but no Wayland surface appears.
  Anything needing real keyboard focus (the launcher's search box) needs
  its own `PanelWindow` with `focusable: true` instead — see
  `launcher/LauncherPanel.qml`.
- **`FileView.text()` never refreshes on its own — not even polled
  imperatively from a `Timer`.** This is broader than "declarative
  bindings don't update reactively": `text()` re-reads by reassigning
  `path` to itself, and a same-value property assignment is a no-op, so
  nothing actually reloads. Confirmed live in `PerformanceTab.qml` —
  CPU/mem/temp rings sat frozen at their first sample for the entire
  session (generating real CPU/disk load moved nothing) because the code
  polled `.text()` on a 2s `Timer` assuming that alone would pick up
  fresh content. `watchChanges` (inotify) doesn't save you either for
  `/proc/*`/`/sys/*` — those don't reliably emit change events since the
  content is regenerated on read, not "modified". The fix: call
  `.reload()` explicitly, and read the result from an `onLoaded`/
  `onTextChanged` handler, not immediately after `.reload()`.
- **Negative `anchor.margins.*` on `PopupWindow` doesn't work reliably** —
  confirmed via pixel-scanning screenshots, effect is either zero or
  non-linearly clamped. Don't rely on it for overlap/concave effects.
- **Local QML filenames can't shadow imported Quickshell type names** —
  e.g. a file can't be named `Bluetooth.qml` because `import
  Quickshell.Bluetooth` already exports a type called `Bluetooth`. Hence
  `BluetoothButton.qml`.
- **`IconImage`/`Quickshell.iconPath(name)` "succeeds" (`status ===
  Image.Ready`) even when `name` doesn't exist in the icon theme** — the
  `image://icon/` provider silently substitutes the theme's own "broken
  image" icon (renders as a magenta/black checkerboard) instead of
  failing, so `status` can't be used to detect this. Confirmed live for
  several real names (`input-gaming`, `audio-card`, `network-wired`,
  `bluetooth`, and any Wayland `appId` used directly as an icon name —
  see below). The fix is `Quickshell.hasThemeIcon(name)`, which correctly
  returns `false` for all of these — check it *before* building the
  `source`, don't try to detect failure after the fact.
  - Separately: a window's Wayland **`appId` is not reliably its icon
    name** — VSCode's appId is `code-oss` but its real icon is
    `com.visualstudio.code.oss` (its own `.desktop` file's `Icon=`
    disagrees with its `StartupWMClass`). Using `appId` straight into
    `iconPath()` hits exactly the checkerboard bug above. Resolve it
    properly first: `DesktopEntries.byId(appId) ||
    DesktopEntries.heuristicLookup(appId)`, then use that entry's
    `.icon`, falling back to the bare `appId` only if no entry matches —
    see `bar/Workspaces.qml`/`dashboard/WorkspacesTab.qml`.
  - For URLs that are already fully-formed (`trayItem.icon` from
    StatusNotifierItem, e.g. `image://icon/...` or the raw-pixmap
    `image://qsimage/...`), `hasThemeIcon` needs the bare name, not the
    URL — strip the `image://icon/` prefix (and any `?fallback=...`
    query) before checking, and skip the check entirely for
    `image://qsimage/` since that's a raw pixmap with no theme name
    involved — see `tray/TrayItem.qml`.

### Hyprland-side integration

`hyprland-neo/workspaces/init.lua` has an `hl.layer_rule` for namespace
`^quickshell$` with `blur = true` — this is what makes the bar and every
drawer glass/translucent (they're all the same layer-shell namespace, so
one rule covers all of them). If a new top-level Quickshell surface is
added with a different namespace, it needs its own rule or an adjustment
to the match pattern.

## Testing changes

Never test against the user's live bar blind. Copy the whole `quickshell/`
tree to the scratchpad, launch with `quickshell -p <scratch-path>` via
`setsid nohup ... & disown`, and check the log for `WARN`/`ERROR` (a clean
"Configuration Loaded" with no type/binding errors is the bar for "didn't
break anything"). Grab a `grim -g "<geometry>"` screenshot of the bar
region when a visual change needs confirming. Kill the scratch process and
delete the scratch copy when done — never leave a second quickshell
instance running.
