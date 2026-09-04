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

-- Importar el entorno de Wayland al bus de systemd/D-Bus ANTES de lanzar
-- servicios de usuario: sin esto, graphical-session.target no arranca y
-- hyprpolkitagent (ConditionEnvironment=WAYLAND_DISPLAY) no levanta ->
-- se rompe todo prompt de polkit (incl. "desbloquear Bitwarden con
-- autenticacion del sistema").
local session_bootstrap = {
    "dbus-update-activation-environment --systemd --all",
    "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE",
    "systemctl --user start hyprpolkitagent.service",
}

local commands = {
    "quickshell",
    "hyprpaper",
    -- GNOME Keyring: Secret Service para Bitwarden (el agente SSH lo
    -- sigue dando gcr-ssh-agent por separado -- gnome-keyring 50.0 ya
    -- no trae componente "ssh"). Sin --unlock: se deja bloqueado hasta
    -- el primer pedido de un secreto (dispara el prompt grafico de gcr)
    -- o desbloqueo manual en Seahorse -- autologin es sin password, asi
    -- que no hay forma de derivar la clave de desbloqueo automaticamente.
    "gnome-keyring-daemon --start --components=pkcs11,secrets --daemonize",
    "wl-paste --type text --watch cliphist store",  -- Stores only text data
    "wl-paste --type image --watch cliphist store", -- Stores only image data
}

function M.setup()
    hl.on("hyprland.start", function()
        for _, cmd in ipairs(session_bootstrap) do
            hl.exec_cmd(cmd)
        end
        for _, cmd in ipairs(commands) do
            hl.exec_cmd(cmd)
        end
    end)
end

return M
