---
name: quickshell-module
description: Add or change a module/drawer/tab in the custom Quickshell status bar (~/.config/quickshell). Use whenever the task touches the Hyprland status bar, its dropdowns, the dashboard tabs, tray, or launcher.
---

# Working in the Quickshell shell

Read `~/.config/hypr/CLAUDE.md` first if this is a fresh session — it has
the directory map, the `uiScale` contract, and the list of gotchas this
skill assumes you already know. This skill is the *procedure*; that file
is the *reference*.

## Deciding where new code goes

- A new bar module (something that sits in the left/center/right row) →
  `modules/bar/`, follow the `Pill.qml` (colored capsule) or
  `IconButton.qml` (icon-only, right-side tray style) pattern depending on
  whether it needs a background color.
- A new dashboard tab → `modules/dashboard/`, add it to `Dashboard.qml`'s
  `tabs` array and the `Loader`'s component list.
- Anything with a dropdown → don't build a new popup mechanism, use
  `modules/drawer/Drawer.qml` as `anchorItem`/`panelWindow`/`uiScale` and
  put content as its default-property children, same as
  `bar/Volume.qml`/`bar/PowerMenu.qml`/`bar/BluetoothButton.qml` do.
- Needs real keyboard focus (a text field)? A `PopupWindow`/`Drawer` won't
  work (see grabFocus gotcha) — build a `PanelWindow` with `focusable`
  instead, like `launcher/LauncherPanel.qml`.

## Checklist for any new/edited `.qml` file

1. **Icons**: Nerd Font glyphs go in as `\uXXXX` / `\u{XXXXX}` escapes,
   never a pasted literal character — and then **verify by codepoint, not
   by reading the file back**. PUA glyphs render invisible in most fonts,
   so a Read/grep can't tell a working icon from a silently-empty one, and
   the escape-text Edit itself isn't 100% reliable (same input has both
   worked and silently produced `""` in this repo, no error either way).
   After writing an icon: `python3 -c "print([hex(ord(c)) for c in
   open('file').readlines()[N-1]])"` on that line. If the codepoint's
   missing, fix it with a small Python script (open, `re.sub` in
   `chr(0xF0XX)`, write back) instead of retrying the same Edit — that's
   been reliable every time the direct Edit wasn't. Before finishing any
   icon-touching task, grep the tree for `// nf-` and codepoint-check
   every hit — this file has accumulated genuine empty-glyph bugs in files
   nobody was actively touching.
2. **Imports**: same-folder types need no import. Cross-folder needs an
   explicit `import "../<folder>"`. `theme/Colors.qml` is `../../theme`
   from any `modules/<subfolder>/*.qml`.
3. **uiScale**: every pixel size (`width`, `height`, `font.pixelSize`,
   `radius`, `spacing`, margins...) must be `<value> * uiScale`, and the
   component must declare `property real uiScale: 1.0` and forward it to
   every child component it instantiates. Don't add a size that ignores
   this — it'll look wrong on the HiDPI/scaled monitor(s).
4. **MouseArea placement**: never a direct child of a `RowLayout`/
   `ColumnLayout`/`GridLayout` sibling to `Layout.*` items. Wrap the
   visual + a `MouseArea { anchors.fill: parent }` in a plain `Item` that
   carries the `Layout.*` properties instead.
5. **Reactive data**: prefer Quickshell's existing services (`Pipewire`,
   `Mpris`, `Hyprland`, `Bluetooth`, `SystemTray`) — they're push-based.
   If you must read a file that updates over time, use one `FileView` +
   explicit `onLoaded`/`onTextChanged` (not a declarative binding on
   `.text()`), and a `Timer` only if the source doesn't support
   file-watching (e.g. `/proc/*`, confirmed not inotify-friendly).
6. **Comments**: match the existing style — terse, Spanish, explain *why*
   (a workaround, a gotcha, a non-obvious constraint), never *what* the
   code visibly does.

## Verifying before calling it done

```bash
SCRATCH=/tmp/claude-*/*/scratchpad/qs-test   # use your actual scratchpad path
rm -rf "$SCRATCH" && mkdir -p "$SCRATCH"
cp -r ~/.config/quickshell/* "$SCRATCH"/
setsid nohup quickshell -p "$SCRATCH" > "$SCRATCH.log" 2>&1 < /dev/null & disown
sleep 2 && pgrep -f "quickshell -p $SCRATCH"   # confirm it's alive
cat "$SCRATCH.log"                              # look for WARN/ERROR beyond
                                                 # pre-existing icon-theme noise
```

A clean run prints `Configuration Loaded` with no type-resolution or
binding errors. For visual changes, `grim -g "<x,y widthxheight>"` a
screenshot of the affected region (get monitor geometry from `hyprctl
monitors -j`) and look at it before reporting success. Kill the scratch
process and delete the scratch copy afterward — never leave a second
`quickshell` instance running, and never test directly against the user's
live bar.

## Hyprland-side hooks

- Compositor blur for any new top-level Quickshell surface needs an
  `hl.layer_rule` match on its layer-shell namespace in
  `hyprland-neo/workspaces/init.lua` (existing rule already covers
  everything under namespace `quickshell`, which is what the bar and every
  drawer share — a new *separate* namespace would need its own rule).
- Workspace/window data comes from `Quickshell.Hyprland` (IPC-backed,
  reactive) — don't shell out to `hyprctl` and parse JSON for anything
  that module already exposes.
