-- Arranque de sesion por maquina: bloquear apenas arranca Hyprland y lanzar
-- el entorno de trabajo despues del primer desbloqueo.
--
-- Todo sale del bloque `session` de machines/<hostname>.json (ver
-- machines/README.md), nada se hardcodea aca:
--
--   "session": {
--     "lock_on_start": true,
--     "after_unlock": [
--       { "command": "code ~/Documents/SPErp", "workspace": "2 silent" },
--       { "command": "./launch-workspace.sh", "cwd": "~/Documents/SPErp" }
--     ]
--   }
--
-- Con `lock_on_start`, hyprland.start lanza scripts/session-unlock, que corre
-- hyprlock y al autenticar vuelve a entrar aca via
-- `hyprctl repl 'require("hyprland-neo/session").after_unlock()'` (el repl
-- corre en el MISMO estado Lua que la config, verificado en vivo). Sin
-- `lock_on_start`, after_unlock corre directo al arrancar.
--
-- Cada comando va por scripts/app-scope (un scope de systemd por app) y,
-- si trae `workspace`, se abre ahi via las reglas de hl.exec_cmd, que
-- siguen al proceso aunque pase por systemd-run (verificado en vivo).

local machine = require('hyprland-neo/lib/machine')

local M = {}

local SCRIPTS = os.getenv("HOME") .. "/.config/hypr/scripts"
local APP_SCOPE = SCRIPTS .. "/app-scope"

-- Una sola vez por instancia de Hyprland: un SUPER+L posterior no pasa por
-- session-unlock, pero un `hyprctl repl` a mano no debe duplicar todo.
local launched = false

function M.after_unlock()
    if launched then
        return
    end
    launched = true

    for _, entry in ipairs(machine.get().session.after_unlock) do
        local cmd = APP_SCOPE .. " " .. entry.command
        if entry.cwd then
            cmd = "cd " .. entry.cwd .. " && " .. cmd
        end
        if entry.workspace then
            hl.exec_cmd(cmd, { workspace = entry.workspace })
        else
            hl.exec_cmd(cmd)
        end
    end
end

function M.setup()
    local session = machine.get().session

    hl.on("hyprland.start", function()
        if session.lock_on_start then
            hl.exec_cmd(SCRIPTS .. "/session-unlock")
        else
            M.after_unlock()
        end
    end)
end

return M
