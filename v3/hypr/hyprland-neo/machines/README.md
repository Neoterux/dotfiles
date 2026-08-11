# Perfiles de máquina

Este repo se comparte entre varias máquinas. Lo que cambia entre ellas no es la
config sino los **datos**: qué outputs existen, cómo se ordenan, en qué monitor
arranca cada workspace, y si el teclado es un split (corne) o uno completo.

Cada máquina tiene su archivo acá: **`<hostname>.json`**, en minúsculas.
`hyprland-neo/lib/machine.lua` lo carga y `monitors/init.lua` + `binds/init.lua`
lo consumen.

## Orden de resolución

1. `$HYPRNEO_MACHINE` → `machines/$HYPRNEO_MACHINE.json`
2. `hostname` (de `/etc/hostname`) → `machines/<hostname>.json`
3. `machines/default.json`

Si nada existe o el JSON no parsea, se cae a un perfil vacío seguro (Hyprland
autodetecta los monitores) y aparece una notificación con el error — una config
de monitores rota deja la máquina sin imagen, y eso es peor que un layout mal.

La variable de entorno sirve para probar el perfil de otra máquina sin renombrar
nada:

```sh
HYPRNEO_MACHINE=gmachine Hyprland
```

## Agregar una máquina

```sh
hostname                          # así se tiene que llamar el archivo
hyprctl monitors -j | jq '.[] | {name, width, height, refreshRate, x, y, scale}'
cp machines/default.json machines/$(hostname).json
```

## Formato

```jsonc
{
  "name": "wmachine",              // opcional, solo para logs
  "comment": "...",                // opcional, ignorado (también "note")

  "keyboard": {
    "layout": "split"              // "split" | "standard"
  },

  "monitors": [
    {
      "output": "DP-2",            // requerido; sin esto el monitor se ignora
      "mode": "1920x1080@60",
      "position": "0x0",
      "scale": 1,
      "default_workspace": 1,      // workspace inicial de ESTE monitor
      "workspaces": [3, 5, 7]      // workspaces fijados a este monitor
    }
  ],

  "workspace_rules": [             // opcional, reglas que no cuelgan de un monitor
    { "id": 9, "persistent": true, "layout": "master" }
  ]
}
```

### `keyboard.layout`

Define el esquema de las binds numéricas de workspace (ver `binds/init.lua`):

| valor        | `SUPER + N`        | `SUPER + SHIFT + N` |
|--------------|--------------------|---------------------|
| `standard`   | cambia de workspace | manda la ventana ahí |
| `split`      | manda la ventana ahí | cambia de workspace |

Alias aceptados: `corne`/`ergo` → `split`; `normal`/`full`/`tkl` → `standard`.
Un valor desconocido cae a `standard` con una advertencia.

### `monitors[]`

Todo campo que no sea `workspaces`, `default_workspace`, `comment` o `note` se
pasa **tal cual** a `hl.monitor(...)`. O sea que cualquier campo de
`HL.MonitorSpec` funciona sin tocar el Lua: `transform`, `vrr`, `mirror`,
`disabled`, `bitdepth`, `cm`, `icc`, `reserved`, etc. La referencia completa
está en `/usr/share/hypr/stubs/hl.meta.lua`.

`position` acepta lo mismo que Hyprland: `"0x0"`, `"auto"`, `"auto-left"`,
`"auto-right"`, `"auto-up"`, `"auto-down"`.

### `workspaces[]` y `default_workspace`

Cada elemento puede ser un atajo o un objeto:

```jsonc
"workspaces": [
  3,                                        // igual a { "id": 3 }
  { "id": 4, "persistent": true },
  { "id": 5, "default": true, "layout": "master" }
]
```

El objeto se pasa a `hl.workspace_rule(...)` con `monitor` completado
automáticamente con el `output` del monitor que lo contiene, así que sirve
cualquier campo de `HL.WorkspaceRuleSpec` (`persistent`, `default_name`,
`gaps_in`, `on_created_empty`, `border_size`, ...).

`default_workspace` es azúcar: marca `default: true` en la regla de ese
workspace, y la crea si el workspace no estaba en la lista. Es el workspace que
Hyprland abre en ese monitor al arrancar.

Las claves que empiezan con `_` o `$` se ignoran en todos los niveles, por si
querés dejar notas o un `$schema`.
