local machine = require('hyprland-neo/lib/machine')
local stacked = require('hyprland-neo/stacked-dwindle')

local M = {}

local mainMod = "SUPER" -- Windows Key como principal
-- Cada app en su propio scope de systemd (ver hypr/scripts/app-scope);
-- rofi hace lo mismo con su run-command.
local appScope = os.getenv("HOME") .. "/.config/hypr/scripts/app-scope "
local filemanager = appScope .. "dolphin"
local terminal = appScope .. "kitty"
local menu = "rofi -show drun"

function M.setup()
    hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
    hl.bind(mainMod .. " + C", hl.dsp.window.close())
    hl.bind(mainMod .. " + M", hl.dsp.exit())
    hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
    hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(filemanager))
    hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
    hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
    hl.bind(mainMod .. " + SHIFT + P", hl.dsp.workspace.toggle_special("magic"))
    hl.bind(mainMod .. " + P", hl.dsp.window.move({ workspace = "special:magic" }))

    -- Navegación usando scroll + mainMod

    hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = 'e+1' }))
    hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = 'e-1' }))

    -- Portapapeles (cliphist)
    hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd(
        [[cliphist list | wofi --dmenu --pre-display-cmd "echo '%s' | cut -f 2" | cliphist decode | wl-copy]]
    ))

    -- Navegacion de workspaces por numero.
    --
    -- El esquema se invierte segun el teclado de la maquina (lo define
    -- `keyboard.layout` en machines/<hostname>.json):
    --   standard -- SUPER + N cambia de workspace, SUPER + SHIFT + N manda la
    --               ventana activa ahi (el clasico).
    --   split    -- invertido, para el corne: los numeros ya estan en una capa
    --               accedida con el pulgar, asi que el gesto sin SHIFT queda
    --               para mover ventanas y el foco se pide con SHIFT.
    local isUsingSplitKeyboard = machine.get().keyboard.is_split
    local focusAction = isUsingSplitKeyboard and " + SHIFT + " or " + "
    local moveAction = isUsingSplitKeyboard and " + " or " + SHIFT + "
    for i = 1, 10 do
        local key = i % 10 -- 10 maps to key 0
        hl.bind(mainMod .. focusAction .. key, hl.dsp.focus({ workspace = i }))
        hl.bind(mainMod .. moveAction .. key, hl.dsp.window.move({ workspace = i }))
    end

    -- Capturas de pantalla. `--freeze` congela la imagen (via hyprpicker)
    -- mientras se selecciona la region: sin eso, todo lo que se mueva
    -- durante el arrastre -- un video, un menu que se cierra, el reloj de la
    -- barra -- termina distinto en la captura de lo que se estaba viendo al
    -- momento de decidir el recorte.
    --   sin SHIFT-equivalente: al portapapeles y listo.
    --   con SHIFT-equivalente: se abre en satty para anotar (ver la regla
    --   "satty-modal" en workspaces/init.lua).
    hl.bind(mainMod .. focusAction .. "S", hl.dsp.exec_cmd("hyprshot --freeze --clipboard-only -m region"))
    hl.bind(mainMod .. moveAction .. "S", hl.dsp.exec_cmd([[hyprshot --freeze --raw -m region | satty -f -]]))

    -- Move/resize windows with mainMod + LMB/RMB and dragging
    hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
    hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

    -- Dwindle: invertir la orientacion del split actual -- las dos ventanas
    -- del contenedor pasan de lado-a-lado a apiladas y viceversa. Sirve
    -- sobre lo que YA existe (se ve el efecto al instante), no para elegir
    -- donde se abre la proxima ventana (eso seria `preselect l|r|u|d`).
    --
    -- Va en el boton del medio (mouse:274) porque SUPER + click izq/der ya
    -- estan tomados por el arrastre de mover/redimensionar de arriba, y
    -- SUPER + rueda por la navegacion de workspaces.
    --
    -- OJO: sin `{ mouse = true }`. Esa opcion es el `bindm` clasico y
    -- existe solo para los dispatchers de arrastre (drag/resize), que
    -- necesitan el boton mantenido y despues liberado; `togglesplit` es
    -- una accion instantanea y va como bind normal.
    --
    -- Solo hace algo en workspaces en dwindle: los otros layouts responden
    -- "Unknown <layout> layoutmsg" y no pasa nada. Tampoco hace nada si el
    -- workspace tiene una sola ventana ("can't togglesplit in the current
    -- workspace") -- no hay split que invertir todavia.
    hl.bind(mainMod .. " + mouse:274", hl.dsp.layout("togglesplit"))

    -- Scratchpad (special:magic) con el mouse, ademas de SUPER + P de arriba.
    --   boton lateral "adelante" (mouse:276): mostrar/ocultar.
    --   boton lateral "atras"    (mouse:275): mandar ahi la ventana activa,
    --     que con focus-follows-mouse es la que esta bajo el cursor.
    --   SHIFT + boton del medio: mostrar/ocultar (el medio solo sigue siendo
    --     togglesplit).
    -- La barra (Workspaces.qml) y la esquina inferior izquierda
    -- (quickshell/modules/hotcorner) hacen lo mismo sin teclado.
    hl.bind(mainMod .. " + mouse:276", hl.dsp.workspace.toggle_special("magic"))
    hl.bind(mainMod .. " + mouse:275", hl.dsp.window.move({ workspace = "special:magic" }))
    hl.bind(mainMod .. " + SHIFT + mouse:274", hl.dsp.workspace.toggle_special("magic"))

    -- Paginas del layout "stacked-dwindle" (ver stacked-dwindle/init.lua).
    -- Fuera de un workspace "lua:stacked-dwindle" no hacen nada (stacked.msg
    -- lo chequea antes de despachar).
    --   J / K: pagina de abajo / de arriba. Las paginas se deslizan en
    --     vertical, asi que las teclas de vim coinciden con lo que se ve; y en
    --     el corne estan en la fila base, sin capa. (H/L no: SUPER + L es
    --     hyprlock.)
    --   SHIFT + J / K: llevar la ventana activa a la pagina de abajo / de
    --     arriba; pasando el borde abre una pagina nueva. Mismo esquema que
    --     vim/i3: sin modificador se mueve uno, con SHIFT se mueve la ventana.
    --     OJO: NO sigue la inversion del corne de los numeros de arriba -- esa
    --     existe porque los numeros viven en una capa, y J/K no.
    --   N: abrir una pagina nueva vacia (lo que se abra ahi, cae ahi).
    --   TAB: ciclar paginas dando la vuelta (atajo de un solo acorde).
    --   SHIFT + rueda: scrollear entre paginas; hacia abajo desde la ultima
    --     abre una nueva (SUPER + rueda sola sigue cambiando de workspace).
    hl.bind(mainMod .. " + J", stacked.msg("page down"))
    hl.bind(mainMod .. " + K", stacked.msg("page up"))
    hl.bind(mainMod .. " + SHIFT + J", stacked.msg("movetopage next"))
    hl.bind(mainMod .. " + SHIFT + K", stacked.msg("movetopage prev"))
    hl.bind(mainMod .. " + N", stacked.msg("page new"))
    hl.bind(mainMod .. " + Tab", stacked.msg("page next"))
    hl.bind(mainMod .. " + SHIFT + mouse_down", stacked.msg("page down"))
    hl.bind(mainMod .. " + SHIFT + mouse_up", stacked.msg("page up"))
end

return M
