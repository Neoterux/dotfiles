local M = {}

function M.setup()
    hl.config({
        xwayland = {
            force_zero_scaling = true,
        },
    })

    -- Glassmorphism real para Quickshell (la barra y sus dropdowns): sin
    -- esto, la transparencia de Quickshell solo deja ver el escritorio
    -- tal cual, sin desenfoque -- se ve "plano", no como vidrio
    -- esmerilado. `ignore_alpha` hace que el blur tambien se aplique a
    -- las zonas mas transparentes (si no, con alpha bajo Hyprland puede
    -- saltearse el blur ahi).
    hl.layer_rule({
        name = "glass-quickshell",
        match = { namespace = "^quickshell$" },
        blur = true,
        ignore_alpha = 0.05,
    })

    hl.window_rule({
        name = "suppress-maximize-firefox",
        match = { class = "^(firefox)$" },
        suppress_event = "maximize",
    })

    hl.window_rule({
        name = "float-kitty",
        match = { class = "kitty", title = "kitty" },
        float = true,
    })

    hl.window_rule({
        -- NOTE: typo inherited from hyprland-legacy ("Fiends" instead of "Friends"),
        -- so this particular rule never actually matches anything.
        name = "float-steam-friends-list-legacy",
        match = { class = "steam", initial_title = "(Fiends List)" },
        float = true,
    })

    hl.window_rule({
        name = "float-firefox-bitwarden",
        match = { class = "firefox", title = "(.*Bitwarden.*)" },
        float = true,
    })

    hl.window_rule({
        name = "float-opencv-viewer",
        match = { title = "^(OpenCV Viewer)(.*)$" },
        float = true,
    })

    -- Satty (el anotador de capturas que abre el bind de screenshot con
    -- `hyprshot --freeze --raw -m region | satty -f -`). Es un editor efimero de un
    -- solo uso: tilearlo reacomoda todo el workspace justo cuando uno solo
    -- queria marcar algo y cerrar, asi que se trata como un modal.
    -- El class real es el app_id de Wayland, "com.gabm.satty" (coincide con
    -- el StartupWMClass de su .desktop).
    hl.window_rule({
        name = "satty-modal",
        match = { class = "^(com\\.gabm\\.satty)$" },
        float = true,
        center = true,
        -- OJO: el API Lua de reglas NO parsea porcentajes ("75% 80%" se
        -- ignora en silencio, verificado en vivo), pero si evalua expresiones
        -- con las variables monitor_w/monitor_h. Asi la ventana queda
        -- relativa al monitor donde abra y no hay resoluciones hardcodeadas.
        size = "monitor_w*0.75 monitor_h*0.8",
        -- Oscurecer lo de atras refuerza el caracter modal y evita que el
        -- escritorio compita con la captura mientras se dibuja encima
        -- (solo aplica mientras satty tiene el foco, que es justo cuando
        -- estorba el fondo).
        dim_around = true,
    })

    hl.window_rule({
        name = "no-initial-focus-xwayland",
        match = { xwayland = true },
        no_initial_focus = true,
    })

    hl.window_rule({
        name = "Steam",
        match = { class = "^(steam)$", title = "^(Steam)$" },
        tile = true,
        suppress_event = "maximize",
    })

    hl.window_rule({
        name = "fix-steam-float",
        match = { class = "steam", initial_title = "Steam", float = true },
        float = false,
        maximize = true,
    })

    hl.window_rule({
        name = "Steam PopUps",
        match = {
            class = "^(steam)$",
            title = "^(Steam Settings|Friends List|Screenshot Uploader|Special Offers)$",
        },
        float = true,
        center = true,
        no_initial_focus = true,
        opacity = 0.85,
        dim_around = false,
        keep_aspect_ratio = true,
        focus_on_activate = true,
        no_blur = true,
        no_screen_share = true,
        no_vrr = true,
        immediate = true,
    })

    hl.window_rule({
        name = "Other PopUps",
        match = { class = "^(steam)$", title = "^(.* - All Categories|.* - Installing)$" },
        float = true,
        opacity = 0.8,
    })

    hl.window_rule({
        name = "Steam Notifications",
        match = { class = "^(steam)$", title = "^()$" },
        float = true,
        pin = true,
        no_initial_focus = true,
        stay_focused = false,
        focus_on_activate = false,
        no_focus = true,
    })

    hl.window_rule({
        name = "fix-bitwarden-firefox",
        match = {
            class = "firefox",
            -- El titulo real (verificado en logs en vivo) es
            -- "Extension: (Bitwarden Password Manager) - Bitwarden — Mozilla Firefox",
            -- distinto al que asumia hyprland-legacy (traia "- Free" de mas).
            -- Se deja un patron laxo en vez de anclar todo el string para no
            -- depender de caracteres como el guion largo "—".
            title = ".*Bitwarden.*Bitwarden.*",
        },
        float = true,
        stay_focused = true,
    })

    -- IMPORTANTE (encontrado debuggeando en vivo con `hyprctl dispatch`):
    -- en esta version de Hyprland (Lua config), `hyprctl dispatch "<string
    -- viejo>"` YA NO FUNCIONA -- el string se evalua como Lua
    -- (`hl.dispatch(<eso>)`), asi que la sintaxis clasica
    -- `hyprctl --batch "dispatch resizewindowpixel exact 20% 54%,address:..."`
    -- que usaba xdg-autostart.sh (via exec_cmd) fallaba en silencio: "ok" en
    -- apariencia, pero el dispatcher nunca se ejecutaba. Ahora se llama
    -- directo a hl.dispatch(hl.dsp.window.xxx({...})) con el nuevo shape,
    -- que valide con pruebas manuales via `hyprctl dispatch 'hl.dsp...'`:
    --   - window.resize acepta { x, y, relative?, window? } en pixeles.
    --   - window.move   acepta { x, y, relative?, window? } en pixeles.
    --   - window.float  acepta { action = "on"|"off", window? }.
    --   - window.center NO soporta `window?`: solo actua sobre la ventana
    --     activa, por eso el centrado se calcula a mano con window.move.
    -- El campo `window` recibe un selector tipo "address:0x...", igual que
    -- el hyprctl clasico.
    --
    -- DEBUG: el stdout de Hyprland suele apuntar a la tty desde la que
    -- arranco (p.ej. /dev/tty1), asi que un print() normal no se ve desde
    -- la sesion grafica. En vez de eso, escribimos a un archivo aparte:
    --   tail -f /tmp/hyprland-neo-debug.log
    -- Una vez confirmado que el fix funciona, se puede borrar este bloque.
    local TAG = "[hn-bitwarden-fix]"
    local LOG_PATH = "/tmp/hyprland-neo-debug.log"
    local function dlog(fmt, ...)
        local line = string.format("%s %s " .. fmt, os.date("%H:%M:%S"), TAG, ...)
        print(line)
        local fh = io.open(LOG_PATH, "a")
        if fh then
            fh:write(line .. "\n")
            fh:close()
        end
    end

    dlog("registrando handler window.title")

    hl.on("window.title", function(...)
        local window = select(1, ...)
        if window == nil then
            window = hl.get_active_window()
        end
        if not window then
            return
        end

        local ok, class, title, address, monitor = pcall(function()
            return window.class, window.title, window.address, window.monitor
        end)
        if not ok then
            dlog("no se pudo leer la ventana (err=%s), abortando", tostring(class))
            return
        end

        if class ~= "firefox" then
            return
        end

        title = title or ""
        local from = title:find("(Bitwarden", 1, true)
        if not from or not title:find("Password Manager) - Bitwarden", from, true) then
            return
        end

        dlog("MATCH class=%q title=%q address=%s", class, title, tostring(address))

        monitor = monitor or hl.get_monitor_at_cursor() or hl.get_active_monitor()
        if not monitor then
            dlog("no se pudo resolver el monitor de la ventana, abortando")
            return
        end

        local scale = monitor.scale or 1
        local mon_w = monitor.width / scale
        local mon_h = monitor.height / scale
        local w = math.floor(mon_w * 0.20)
        local h = math.floor(mon_h * 0.54)
        local x = math.floor(monitor.x + (mon_w - w) / 2)
        local y = math.floor(monitor.y + (mon_h - h) / 2)

        local selector = "address:" .. tostring(address)
        dlog("monitor=%s (%dx%d) -> resize %dx%d, move a %d,%d", tostring(monitor.name), mon_w, mon_h, w, h, x, y)

        local r1 = hl.dispatch(hl.dsp.window.float({ action = "on", window = selector }))
        dlog("float(on) -> %s", tostring(r1))

        local r2 = hl.dispatch(hl.dsp.window.resize({ x = w, y = h, window = selector }))
        dlog("resize -> %s", tostring(r2))

        local r3 = hl.dispatch(hl.dsp.window.move({ x = x, y = y, window = selector }))
        dlog("move -> %s", tostring(r3))

        hl.notification.create({
            text = TAG .. " aplicado a " .. tostring(address),
            timeout = 3,
        })
    end)

    -- Fix XWayland video bridge (screen sharing helper window)
    hl.window_rule({
        name = "fix-xwaylandvideobridge",
        match = { class = "^(xwaylandvideobridge)$" },
        opacity = "0.0 override",
        no_anim = true,
        no_initial_focus = true,
        max_size = "1 1",
        no_blur = true,
        no_focus = true,
    })
end

return M
