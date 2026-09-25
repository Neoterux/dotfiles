local env = require('hyprland-neo/env')

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
--
-- Bajo uwsm (`uwsm start hyprland-uwsm.desktop`, ver ~/.zprofile) eso lo
-- hace `uwsm finalize`: exporta WAYLAND_DISPLAY + las variables que se le
-- pasan a systemd/D-Bus y le avisa a uwsm que el compositor esta listo.
-- SIN finalize, uwsm espera HYPRLAND_INSTANCE_SIGNATURE en el entorno de
-- activacion, se vence el timeout y baja la sesion entera. Con eso arranca
-- graphical-session.target, y de ahi hyprpolkitagent, los portals y las
-- entradas de XDG autostart (~/.config/autostart) solos.
-- uwsm se reconoce por UWSM_FINALIZE_VARNAMES, que su plugin de Hyprland
-- exporta antes de lanzarlo. Otra maquina que arranque Hyprland pelado
-- sigue por el camino viejo.
local under_uwsm = os.getenv("UWSM_FINALIZE_VARNAMES") ~= nil

local session_bootstrap = under_uwsm and {
    "uwsm finalize " .. table.concat(env.names(), " "),
} or {
    "dbus-update-activation-environment --systemd --all",
    "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE",
    "systemctl --user start hyprpolkitagent.service",
}

-- Quickshell se lanza con su propio entorno, NO por hyprland-neo/env: esas
-- variables aplican a TODA la sesion y estas dos solo tienen sentido para
-- este proceso.
--
-- HONESTIDAD SOBRE EL AHORRO: no esta demostrado. Una primera medicion
-- de una sola corrida dio -36 MB, pero repitiendo el A/B tres veces por
-- rama los numeros quedaron asi (RSS a los 15s):
--   sin env: 454 / 462 / 458 MB
--   con env: 452 / 454 / 481 MB
-- O sea que la varianza entre arranques (+-35 MB, segun cuantos iconos de
-- bandeja alcanzaron a conectarse y que ventanas hay abiertas) se come
-- cualquier efecto de este tamaño. Se dejan puestas porque el
-- razonamiento es solido y no cuestan nada, NO porque se haya visto el
-- ahorro. Si alguna vez molestan, sacarlas sin culpa.
--
-- Moraleja para la proxima vez que se optimice memoria aca: medir dentro
-- de UN proceso (antes/despues de una accion), nunca comparando dos
-- arranques.
--
--  * MALLOC_ARENA_MAX: glibc abre hasta 8*nucleos arenas de malloc y el
--    shell corre ~30 hilos, asi que se fragmentaba en decenas de arenas
--    que nunca devolvian memoria. Con 2 alcanza de sobra: el trabajo
--    pesado es de un solo hilo (el de QML).
--  * QSG_ATLAS_*: el atlas de texturas de Qt Quick arranca en 2048x2048
--    RGBA = 16 MB por ventana. Los iconos de la barra son de 16-42 px y
--    entran de sobra en 512x512 (1 MB). Si alguna vez se mete una imagen
--    grande en la barra y se ve borrosa o se pierde, subir esto es lo
--    primero a probar.
local quickshell_env = "MALLOC_ARENA_MAX=2 QSG_ATLAS_WIDTH=512 QSG_ATLAS_HEIGHT=512"

local commands = {
    "env " .. quickshell_env .. " quickshell",
    "hyprpaper",
    -- GNOME Keyring: Secret Service para Bitwarden (el agente SSH lo
    -- sigue dando gcr-ssh-agent por separado -- gnome-keyring 50.0 ya
    -- no trae componente "ssh"). Sin --unlock: el login por autologin
    -- (`login -f`) no tiene password, asi que el daemon arranca
    -- bloqueado; lo desbloquea el hyprlock del arranque, cuya password
    -- pasa por pam_gnome_keyring (ver scripts/session-unlock). Si el
    -- daemon ya lo levanto PAM, --start solo se engancha a ese.
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
