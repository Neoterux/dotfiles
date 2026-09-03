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
  shaders/                   fragment shaders (.frag) + su .qsb compilado
    bake.sh                    recompila todos los .frag -> .qsb
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
compositor blur, see below) + shadow + open/scale animation.

**La tarjeta ya NO es un `Rectangle`: la dibuja un fragment shader**
(`shaders/drawer_card.frag`, ver la seccion Shaders). Redondeada abajo y
con **contracurva** arriba — dos filetes concavos que la abren hacia los
costados hasta fundirla con la barra.

Esto revierte una decision vieja de este archivo. La version anterior
decia que la contracurva estaba descartada y que no se reintentara: los
intentos de entonces la armaban componiendo `Rectangle`/`Canvas`, y por
ahi no sale, porque unir un cuerpo convexo con dos recortes concavos no
es componer formas sino operar sobre distancias con signo (`min` para la
union, `max` para la interseccion). Es lo mismo que hace el plugin C++ de
caelestia, y en QML se puede desde que existe `ShaderEffect`. Lo unico
que faltaba era la herramienta, no la idea.

Dos consecuencias de geometria que hay que respetar al tocarlo:

- El popup arranca **a ras del borde de abajo de la barra**, no debajo
  del pill que lo abre (que flota unos px mas arriba). `anchor.margins.top`
  se calcula con `anchorItem.mapToItem(null, 0, height)` contra el alto de
  la `panelWindow`. Si el popup queda separado, la contracurva no toca
  nada y el efecto no se lee.
- El popup es `wing` px mas ancho de cada lado que su contenido: ese
  margen es area de los filetes. `inner` lleva `leftMargin`/`rightMargin`
  = `pad + wing` para no meter contenido ahi.

### Shaders (`shaders/`)

Quickshell no tiene API propia de shaders: es `ShaderEffect` de QtQuick a
secas. Lo que si cambia respecto de Qt5 es que **el GLSL inline no
existe** — `fragmentShader` toma la URL de un bundle `.qsb` precompilado
con `qsb` (paquete `qt6-shadertools`). Como esta config se carga en
runtime y no tiene build, los `.qsb` van **commiteados** al repo.

Flujo: tocaste un `.frag` -> `shaders/bake.sh` -> commiteá los dos.
Quickshell recarga solo al guardar un `.qml`, pero **no** mira los
`.qsb`: despues de rehornear hay que reiniciar el shell (o tocar
cualquier `.qml`) o se sigue viendo el shader viejo.

Los que hay y donde se usan:

| shader | lo usa | anima en reposo |
|---|---|---|
| `drawer_card.frag` | `drawer/Drawer.qml` (contracurva + contorno) | no |
| `bar_edge.frag` | `bar/Bar.qml` (la otra mitad del contorno) | no |
| `glow.frag` | `bar/Workspaces.qml` (workspace enfocado) | no |
| `dissolve.frag` | `notifications/NotificationToast.qml` (entrada) | no, ~380ms |
| `bar_sheen.frag` | `bar/Bar.qml` (aurora del fondo) | **si** |

**Regla de costo**: la barra vive prendida, asi que un shader con
uniforms constantes es gratis (QtQuick no repinta si nada cambia) y uno
animado no. `bar_sheen` es el unico que anima solo, lo mueve un `Timer` a
~15fps a proposito (una `NumberAnimation` repinta a la tasa del monitor)
y se apaga entero con `Bar.sheenEnabled: false`. Cualquier shader nuevo
que quiera animar en reposo tiene que justificarse igual.

Gotchas propios de esto:

- **`layer.effect` necesita que el `ShaderEffect` declare
  `property var source` a mano.** `layer.effect` asigna la textura con
  `setProperty()` sobre el nombre de `layer.samplerName` ("source" por
  defecto); si esa property no existe, Qt crea una **dinamica**, que el
  ShaderEffect no mira nunca — el sampler queda vacio y la tarjeta sale
  en negro, sin ningun error en el log.
- **`anchor.margins.top` de `PopupWindow` no se aplica.** Se puede
  setear y leer (devuelve el valor), pero la superficie igual queda
  pegada al filo de abajo del ANCLA. Como el pill flota unos px arriba
  del filo de la barra, el drawer terminaba montado sobre los ultimos px
  de la barra y su contracurva arrancaba ahi -- por eso los dos contornos
  se veian corridos. Se compensa puertas adentro (`Drawer.barOverlap`
  corre la tarjeta hacia abajo dentro de su propia superficie). Misma
  familia que la nota vieja de margenes negativos: los margenes de
  PopupWindow no son de fiar, medir siempre en pantalla.
- **Dos trazos que se encuentran en una juntura tienen que estar los dos
  del mismo lado del borde.** El contorno del drawer estaba centrado en
  `d = 0` (mitad adentro, mitad afuera) y el de la barra vivia entero
  dentro de su superficie: en el empalme se pisaban medio pixel corridos
  y quedaba un escaloncito. Los dos hacia adentro y con la MISMA rampa de
  antialias (1.0 px en los dos shaders) y el empalme cierra.
- **`min()` de dos SDF miente sobre las junturas internas.** Es exacto
  para el exterior de la union, pero sobre la costura donde se tocan dos
  piezas devuelve ~0 aunque el punto este bien adentro. Si el contorno se
  dibuja como banda alrededor de `d = 0`, esa costura se enciende y
  aparece un trazo que no corresponde a ningun borde real -- en
  `drawer_card.frag` era una linea vertical de mas, paralela al arco,
  justo donde el filete se encuentra con el cuerpo. La solucion no es
  tocar la banda sino **superponer las piezas**: se estira la caja del
  filete hacia adentro del cuerpo, y como esa area ya estaba dentro del
  cuerpo la silueta no cambia, pero la costura queda enterrada donde los
  dos SDF son bien negativos. (Hacia abajo NO se puede estirar: ahi el
  disco deja de tapar y salen pinches fuera de la silueta.)
- **Para animar la SALIDA de algo que vive en un modelo, el id tiene que
  quedarse en el modelo hasta que la animacion termine.** El `Repeater`
  destruye el delegate en el mismo instante en que el elemento sale del
  modelo, asi que "sacarlo y despues animar" no existe: ya no hay nada
  que animar, desaparece de un frame al otro. El patron que si funciona
  es una lista aparte de "salientes" (`NotificationState.exitingIds`): el
  timer de expiracion MARCA, el delegate ve la marca y se disuelve, y
  recien al terminar avisa (`exited`) para que el id salga del modelo de
  verdad (`finishPopup`). Ojo con el que se cae por el tope de toasts
  mientras estaba saliendo: su delegate ya no existe y nunca va a avisar,
  hay que podar esa lista aparte.
- **`MultiEffect` dibuja la FUENTE ademas del efecto, y corrida.** Con
  `autoPaddingEnabled` (true por defecto) la copia sale desplazada ~21px.
  Mientras la tarjeta del drawer fue un rectangulo liso no se noto nunca;
  apenas tuvo contorno, la copia aparecio como un **doble borde
  fantasma** (dos contornos anidados, cada uno con su contracurva). Si
  aparece un duplicado espectral de algo, sospechar de esto antes que del
  shader: para confirmarlo, cambiar el color del borde y ver si las DOS
  lineas cambian (si cambian, las dibuja el mismo shader dos veces).
  - De paso: la sombra de ese MultiEffect nunca se habia visto, porque el
    popup mide exactamente lo que la tarjeta y el desenfoque caia fuera
    de la superficie. Se saco el MultiEffect entero del `Drawer`: la
    profundidad la dan el contorno y el blur del compositor.
- **Una caida `exp()` no llega a cero nunca**, asi que un halo se corta
  con un escalon visible justo en el borde del item (se veia como un
  recuadro claro alrededor del workspace activo). Hay que multiplicarla
  por una ventana que la apague antes del limite — ver el par
  `spread`/`cutoff` en `glow.frag`.
- **Los colores de QML llegan premultiplicados** al uniform `vec4`, asi
  que la salida se arma como `color * alpha` y no `vec4(color.rgb, alpha)`.
- El `vec2 size` en px se pasa como `property vector2d size:
  Qt.vector2d(width, height)` — es un binding, se actualiza solo al
  cambiar de tamaño. Un shader que asume 0..1 y no sabe su tamaño real no
  puede hacer esquinas de radio fijo.
- **Para probar un shader, lo mas rapido es una config aparte de 20
  lineas** (`quickshell -p /ruta/test.qml`) con un `PanelWindow` chico y
  el `ShaderEffect` adentro: itera en segundos y no depende de que el
  modulo real este en el estado correcto. `status` del ShaderEffect
  arranca en 1 (Uncompiled) y pasa a 0 (Compiled) recien al dibujarse por
  primera vez; si se queda en 1, el item no se esta dibujando (tamaño 0,
  invisible, o la capa no se activo).
  - Ojo al armar el mock: envolver el componente real en un `Loader` para
    fabricarlo a mano **no reprodujo** el efecto (el `ShaderEffect` de la
    capa quedaba para siempre en Uncompiled) aunque el componente real
    anda bien. Si algo no se ve en un mock, verificalo instanciando el
    componente de verdad antes de salir a buscar el bug en el shader.

### El contorno que une barra y drawer

Con un drawer abierto, barra y drawer comparten un unico contorno: entra
por el filo de abajo de la barra, baja por la contracurva, rodea el
drawer y vuelve a salir a la barra del otro lado. Es lo que hace que la
contracurva se VEA -- con 16px y sin linea que la recorriera, la curva no
se leia contra el fondo translucido (por eso ahora `wing` es 26 *y* hay
contorno: una cosa sin la otra no alcanzaba).

Son **dos superficies Wayland distintas** (layer-shell y xdg-popup), asi
que el contorno son dos mitades dibujadas por dos shaders que se
encuentran en la juntura. Lo que las mantiene alineadas:

- **La barra tiene que saber donde cayo el popup, y `PopupWindow` no lo
  dice**: `x`/`y` dan `undefined` y `anchor.rect` viene en cero
  (verificado). Hay que predecirlo. La regla del compositor, medida en
  pantalla con un popup magenta (ancla en x=1600 w=24, popup de 380 ->
  ocupo 1422..1801), es **centrado en el ancla y despues acotado a la
  pantalla** por `PopupAdjustment.Slide`. Eso es `Drawer.predictedX`.
  Es a ciegas: si alguna vez el compositor lo ubica distinto, el contorno
  se desalinea y no hay forma de que el shell se entere.
- **La geometria viaja por `drawer/DrawerLink.qml`** (singleton), porque
  las dos puntas estan en ramas distintas del arbol: el Drawer lo crea
  cada modulo bien adentro, y quien dibuja la otra mitad es `Bar.qml`,
  arriba de todo. `DrawerLink.window` desempata entre monitores.
- **El drawer se abre desenrollandose hacia abajo, no escalando.** No es
  solo estetica: con `scale` el ancho renderizado no coincide con el
  logico, asi que el hueco de la barra bailaba durante toda la animacion.
  Desenrollando (`reveal` mueve el alto de la tarjeta), el ancho es
  constante desde el primer frame.
- **La aurora de la barra sigue adentro del drawer.** Sin eso el drawer
  es un plano liso pegado a una barra teñida y se lee como un recorte
  aunque el contorno sea continuo. `drawer_card.frag` evalua la MISMA
  onda que `bar_sheen.frag` en la MISMA coordenada absoluta (por eso le
  llegan `sheenOriginX` y el ancho de la barra) y arranca en el valor con
  el que la barra termina su gradiente vertical, disolviendose hacia
  abajo. El tiempo sale de `theme/Sheen.qml`, singleton justamente para
  que las dos superficies no lleven contadores distintos. Medido en la
  juntura: ultima fila de la barra y primera del drawer dan el mismo RGB.
- **El filo de arriba de la tarjeta no se puede enmascarar, hay que
  cortarlo.** La forma se dibuja `overlap` px MAS ARRIBA del item y el
  item la corta, asi adentro de lo que se ve no hay borde superior que
  contornear. Apagar la banda con una mascara "y < k" no sirve: cerca de
  la juntura el arco del filete es casi horizontal, y cualquier mascara
  asi se come ~10px de arco y abre un agujero justo en el empalme. Como
  el corte deja la tarjeta un poco mas angosta arriba que el popup,
  `Drawer.topInset` calcula cuanto, y la barra cierra su hueco ahi.

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
- **`Pill.hovered` miente si el Pill no declara `hoverable: true`.** El
  `MouseArea` de `Pill.qml` lleva `hoverEnabled: root.hoverable`, y
  `hoverable` arranca en `false`: un Pill que solo pone `interactive:
  true` recibe clicks perfectamente pero su `containsMouse` no se prende
  NUNCA, asi que `hovered` queda clavado en false. No hay error de
  ningun tipo — la property existe y devuelve un bool valido — asi que un
  `Drawer { hoverOpen: true }` sobre semejante Pill carga limpio y
  simplemente no abre jamas. Paso con Volume y WorkspaceLayout. Ahora lo
  arma el propio Drawer (`armHoverSource()`), pero si aparece algo que
  depende del hover de un Pill por fuera de esa via, es lo primero a
  revisar. `IconButton` no tiene el problema: su MouseArea trackea
  siempre (y por eso tampoco tiene `hoverable`, ojo al asignarla a
  ciegas).
  - **Un `Drawer` por hover con un control de ARRASTRE adentro necesita
    `hoverHold`.** Mientras se arrastra, el MouseArea del control se
    queda con el grab del puntero, asi que el mouse puede salir de la
    superficie del popup sin soltar: `hovered` se cae y el drawer se
    cierra en plena arrastrada. Se ata al `pressed` del control (ver
    `Slider.pressed` <- `Volume.qml`).
- **Para probar el hover con el cursor a mano, hay que ACERCARSE en
  pasos.** Un warp de un solo salto hasta la barra mueve el puntero
  (`hyprctl cursorpos` lo confirma) pero **no** dispara el hover: el
  drawer no abre ni siquiera en modulos que andan bien, lo que hace
  parecer que el bug esta en el modulo. Con varios `cursor.move`
  intermedios (y ~250ms entre uno y otro) el enter llega y se puede
  verificar de verdad. El dispatcher, con la config en Lua, es
  `hyprctl repl 'hl.dispatch(hl.dsp.cursor.move({ x = N, y = N }))'` —
  `hyprctl dispatch movecursor N N` no parsea, y llamar a
  `hl.dsp.cursor.move(...)` sin `hl.dispatch()` alrededor devuelve el
  dispatcher sin ejecutarlo (silencioso: parece que anduvo).
- **Matar quickshell le regala las notificaciones a `mako`.** Esta
  habilitado como servicio de usuario Y es dbus-activatable
  (`fr.emersion.mako.service`), asi que agarra
  `org.freedesktop.Notifications` apenas el shell suelta el nombre, y al
  volver el shell ya no lo puede tomar (loguea "presumably because one
  is already registered" y sigue andando sin notificaciones). Pasa en
  CADA reinicio del shell. Chequear con
  `busctl --user call org.freedesktop.DBus /org/freedesktop/DBus
  org.freedesktop.DBus GetConnectionUnixProcessID s
  org.freedesktop.Notifications` y comparar contra el pid del shell.
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
  - Dos drawers pidiendo el grab **a la vez** (p.ej. el mismo modulo
    abierto en los dos monitores) no conviven: el compositor le limpia el
    grab a uno de los dos en el acto y ese se cierra solo, sin que haya
    habido ningun click. En uso real no pasa (se abre uno por vez), pero
    si aparece al testear con dos instancias abiertas a proposito, es
    esto y no un bug del modulo.
- **`ObjectModel.values` (`trackedNotifications.values`,
  `trayItems.values`, etc.) es una vista VIVA del modelo, no una copia** —
  el wrapper de secuencia de QML relee la propiedad en cada acceso por
  indice, asi que sacar elementos del modelo mientras se la itera
  (`for...of`, `forEach`) saltea uno de cada dos. Fue un bug real en
  `NotificationState.clearAll()`: "limpiar todo" limpiaba la mitad, y otra
  mitad en el siguiente click. Congelar con `.slice()` antes de tocar
  nada. Solo para leer/`.length`/`.filter` sin mutar es seguro tal cual.
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

**`blur` solo no alcanza para los drawers: hace falta ademas
`blur_popups = true`.** Los drawers son xdg-popups, no layer surfaces --
ni siquiera figuran en `hyprctl layers`, ahi solo estan la barra y la
ventana de toasts. Con `blur` a secas la barra quedaba esmerilada y los
drawers translucidos pero SIN desenfocar, o sea que se leia el texto de
la ventana de atras a traves del dashboard. Verificado prendiendo y
apagando la linea en vivo.

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
