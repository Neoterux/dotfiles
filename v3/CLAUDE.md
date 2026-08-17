# Hyprland + Quickshell rice — project context

This repo is `labfernandez2014@gmail.com`'s Hyprland setup on Arch Linux
(gruvbox theme), shared across **several machines** — "GMachine" (DP-1
2560x1440 + DP-3 1920x1080, full keyboard) and "wmachine" (the work box:
two 1080p outputs, corne split keyboard). Anything that differs per machine
lives in `hyprland-neo/machines/<hostname>.json`, never hardcoded in the
Lua — see "Per-machine profiles" below. It has two living parts:

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
      WorkspaceLayout.qml     layout de tiling del workspace activo (ver abajo)
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
  - Consequence: an xdg-popup never hears about clicks outside its own
    surface, so "close when I click elsewhere" can't be done inside the
    popup. `HyprlandFocusGrab { windows: [popup]; active: shown }` asks
    the compositor for the input grab and fires `cleared` on the first
    outside click — clicks inside keep working and it renders fine (it is
    not the `grabFocus` path). Wired into `drawer/Drawer.qml` as the
    opt-in `dismissOnClickOutside`/`dismissed` pair; the hover-opened
    drawers (Clock) deliberately leave it off. If the compositor ever
    delivers that clearing click to the surface underneath as well, the
    opener has to ignore it — see the `justDismissed()` grace window in
    `tray/TrayItem.qml`, without which the same click closes and reopens
    the menu.
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
    involved.
  - **A `?path=` query means `hasThemeIcon` must NOT be consulted at
    all.** That query is the SNI `IconThemePath`: the app ships its own
    icon dir and quickshell resolves the name from there, but
    `hasThemeIcon` only knows the *system* theme and answers `false`.
    JetBrains Toolbox is the live case (`IconName toolbox-tray-color` +
    `IconThemePath ~/.local/share/JetBrains/Toolbox/bin`, i.e.
    `image://icon/toolbox-tray-color?path=...`) — checking the bare name
    ate its logo and left the fallback glyph. Verified by rendering both
    forms side by side: with the query it draws the real icon, without it
    the checkerboard. All of this now lives in one place,
    `tray/TrayIcons.qml` (`TrayIcons.usable(url)`), used by both
    `tray/TrayItem.qml` and `tray/TrayMenuList.qml`.
- **`trayItem.display(window, x, y)` doesn't work in this shell** — it
  opens a *platform* (QtWidgets) menu and dies with `Cannot display
  PlatformMenuEntry as quickshell was not started in QApplication mode`,
  fixable only by adding `//@ pragma UseQApplication` to `shell.qml`.
  That was rejected: it drags QtWidgets into the process and the menu
  would render in the system style, not the bar's. Tray context menus are
  drawn in QML instead — `QsMenuOpener { menu: trayItem.menu }` exposes
  the DBusMenu entries as a model (`.children.values`, each with `text`,
  `enabled`, `isSeparator`, `icon`, `buttonType`/`checkState`,
  `hasChildren`, and `triggered()` to fire it) — see
  `tray/TrayMenuList.qml`, which renders them inside the shared `Drawer`
  and recurses into submenus through a `Loader` (QML rejects a file that
  instantiates its own type directly).
  - JetBrains Toolbox's DBusMenu doesn't implement
    `Properties.GetAll`, so quickshell logs `Error updating properties of
    …/com.canonical.dbusmenu` on every open. Harmless noise — the entries
    come from `GetLayout` and render fine.

### Layout de tiling por workspace (`bar/WorkspaceLayout.qml`)

Hyprland 0.56 guarda el layout **por workspace**, no solo global:
`hyprctl -j workspaces` trae un campo `tiledLayout` por entrada, y los
valores validos son los de `general:layout` (`dwindle` / `master` /
`scrolling` / `monocle` / `lua:<nombre>`).

- **Lo unico que lo cambia es una workspace rule con campo `layout`** —
  no hay dispatcher para esto, y `hl.dsp.workspace` solo expone
  `change_id`/`move`/`rename`/`swap_monitors`/`toggle_special`. Aplicarla
  en caliente es instantaneo y **retroactivo** sobre las ventanas que ya
  estan en el workspace (verificado en vivo).
- **`hyprctl keyword` no sirve con la config en Lua**: responde `keyword
  can't work with non-legacy parsers. Use eval.` La via es
  `hyprctl eval 'hl.workspace_rule({ workspace = "N", layout = "master" })'`
  desde un `Process`, igual que PowerMenu llama a `hl.dsp.exit()`.
  (`hyprctl eval` devuelve siempre `ok`; para ver el valor de retorno de
  un snippet Lua, `hyprctl repl '<code>'` — util para introspeccionar
  `hl.*` en vivo.)
- **La regla es de runtime**: un reload de la config de Hyprland la borra
  y el workspace vuelve a `general.layout`.
  - Y **Hyprland recarga la config Lua sola al guardar cualquier archivo
    de `hyprland-neo/`** (confirmado en vivo: editar `binds/init.lua`
    aplico el bind nuevo sin pedir nada, y de paso borro las
    workspace/window rules que se habian seteado por `hyprctl eval`).
    O sea: editar la config = perder los layouts elegidos desde la barra.
    Si algun workspace tiene que arrancar siempre con un layout dado, va
    como `hl.workspace_rule({ workspace = "3", layout = "master" })` en
    `workspaces/init.lua`, no por la barra.
  - Corolario al registrar binds a mano: si ya hubo hot-reload, el bind
    del archivo YA esta puesto, y un `hyprctl eval 'hl.bind(...)'` encima
    lo **duplica** (`hyprctl binds` lo muestra dos veces con args Lua
    distintos). Para un toggle eso es peor que inutil: se dispara dos
    veces por click y queda todo igual. Se limpia con
    `hl.unbind("<chord>")`, que saca TODAS las registraciones de esa
    combinacion, y despues se vuelve a registrar una sola vez.
- **Cambiar una workspace rule no emite ningun evento IPC**, asi que
  Quickshell no se entera solo: hay que llamar a
  `Hyprland.refreshWorkspaces()` a mano para que
  `HyprlandWorkspace.lastIpcObject.tiledLayout` se actualice. El modulo lo
  hace en el `onExited` del `Process` y tambien al cambiar de workspace
  activo (el layout pudo haber cambiado desde afuera mientras tanto).
- El modulo apunta al workspace activo **de su propio monitor**
  (`Hyprland.monitorFor(panelWindow.screen).activeWorkspace`), no a
  `Hyprland.focusedWorkspace` — si no, la barra del monitor secundario
  mostraria y cambiaria el layout del otro.
- **El workspace especial (scratchpad) NO aparece nunca como
  `activeWorkspace`.** Hyprland lo lleva en un slot aparte por monitor
  (`specialWorkspace` en `hyprctl -j monitors`, `{id=0, name=""}` cuando
  esta cerrado) y lo deja *superpuesto* sobre el workspace normal, que
  sigue figurando como el activo — asi que ni `activeWorkspace` ni
  `focusedWorkspace` se enteran de que el scratchpad esta arriba.
  `HyprlandMonitor` no expone ese slot como propiedad; sale de
  `monitor.lastIpcObject.specialWorkspace`. El selector para la regla es
  el nombre completo (`workspace = "special:magic"`), y funciona igual.
  - Abrirlo/cerrarlo tampoco emite ningun evento de workspace: lo unico
    que llega es `activespecial>>special:magic,<MONITOR>` (+ la variante
    `activespecialv2` con el id). Se escucha con
    `Connections { target: Hyprland; function onRawEvent(event) {...} }`
    y se responde con `Hyprland.refreshMonitors()`, que actualiza
    `lastIpcObject` y recalcula los bindings.

### Hyprland-side integration

`hyprland-neo/workspaces/init.lua` has an `hl.layer_rule` for namespace
`^quickshell$` with `blur = true` — this is what makes the bar and every
drawer glass/translucent (they're all the same layer-shell namespace, so
one rule covers all of them). If a new top-level Quickshell surface is
added with a different namespace, it needs its own rule or an adjustment
to the match pattern.

## Per-machine profiles

`hyprland-neo/machines/<hostname>.json` describes everything that is a
property of the *machine* rather than of the config: monitor layout (the
full `HL.MonitorSpec` surface, passed through verbatim), which workspaces
are pinned to which output, each monitor's initial workspace, and whether
the keyboard is a split (corne) or a standard one. `lib/machine.lua`
resolves it (`$HYPRNEO_MACHINE` → `<hostname>` → `default.json`),
normalizes it, and caches it; `lib/json.lua` is a self-contained pure-Lua
decoder (the embedded Lua has no cjson/yaml, and a broken external
dependency means a session that won't start).

**Rule: never hardcode an output name, a resolution, a workspace-to-monitor
binding, or a keyboard assumption in the Lua.** Add a field to the JSON
schema instead. `monitors/init.lua` and `binds/init.lua` are deliberately
thin — they just iterate what the profile hands them. Full format reference
in `hyprland-neo/machines/README.md`.

Loading failures degrade instead of throwing: a missing or malformed
profile falls back to "no `hl.monitor` calls at all" (Hyprland autodetects)
and raises a notification. Keep it that way — a config error that leaves
the machine with no display is much worse than a wrong layout.

Testable outside a live session: stub `hl` and `require` the modules under
plain `lua` (both are pure data transforms), which is how the current
profiles were validated.

## Testing changes

Never test against the user's live bar blind. Copy the whole `quickshell/`
tree to the scratchpad, launch with `quickshell -p <scratch-path>` via
`setsid nohup ... & disown`, and check the log for `WARN`/`ERROR` (a clean
"Configuration Loaded" with no type/binding errors is the bar for "didn't
break anything"). Grab a `grim -g "<geometry>"` screenshot of the bar
region when a visual change needs confirming. Kill the scratch process and
delete the scratch copy when done — never leave a second quickshell
instance running.
