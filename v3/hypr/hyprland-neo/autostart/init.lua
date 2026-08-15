local M = {}

-- El fix de Bitwarden ya no depende de un script/socat externo:
-- se resuelve con el evento "window.title" en hyprland-neo/workspaces.
--
-- swaync YA NO se levanta aca: Quickshell mismo es el daemon de
-- notificaciones ahora (NotificationServer en modules/notifications/
-- NotificationState.qml, registra org.freedesktop.Notifications) --
-- solo un proceso puede tener ese nombre DBus a la vez, asi que los dos
-- corriendo juntos no funciona (el segundo en registrarse se queda
-- afuera, silenciosamente).
local commands = {
    "quickshell",
    "systemctl --user start hyprpolkitagent",
    "hyprpaper",
    "wl-paste --type text --watch cliphist store",  -- Stores only text data
    "wl-paste --type image --watch cliphist store", -- Stores only image data
}

function M.setup()
    hl.on("hyprland.start", function()
        for _, cmd in ipairs(commands) do
            hl.exec_cmd(cmd)
        end
    end)
end

return M
