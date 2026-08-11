-- Layout de monitores y workspaces iniciales.
--
-- Esto NO se hardcodea aca: cada maquina describe sus outputs y su workspace
-- inicial en `hyprland-neo/machines/<hostname>.json`. Ver machines/README.md.

local machine = require('hyprland-neo/lib/machine')

local M = {}

function M.setup()
    local profile = machine.get()

    for _, spec in ipairs(profile.monitors) do
        hl.monitor(spec)
    end

    for _, rule in ipairs(profile.workspace_rules) do
        hl.workspace_rule(rule)
    end
end

return M
