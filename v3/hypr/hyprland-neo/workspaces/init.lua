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
    --
    -- `blur_popups` NO es redundante con `blur`: los drawers de la barra
    -- son xdg-popups, no layer surfaces -- no aparecen siquiera en
    -- `hyprctl layers`, ahi solo figuran la barra y la ventana de toasts.
    -- Con `blur` a secas la barra quedaba esmerilada y los drawers no:
    -- translucidos pero sin desenfocar, o sea que se leia el texto de la
    -- ventana de atras a traves del dashboard. Verificado en vivo
    -- prendiendo y apagando esta linea.
    hl.layer_rule({
        name = "glass-quickshell",
        match = { namespace = "^quickshell$" },
        blur = true,
        blur_popups = true,
        ignore_alpha = 0.05,
    })

    -- Mismo vidrio para los dos lanzadores. Son layer surfaces con
    -- namespace propio (verificado con `hyprctl layers` con cada uno
    -- abierto: `rofi` cae en el nivel `overlay`, `wofi` en `top`), asi
    -- que la regla de quickshell no los alcanza y necesitan la suya.
    --
    -- Aca NO hace falta `blur_popups`: a diferencia de los drawers de la
    -- barra, rofi y wofi dibujan todo dentro de su propia layer surface,
    -- no abren xdg-popups.
    --
    -- Sin esto, bajarles el alpha al fondo (ver rofi/theme.rasi y
    -- wofi/style.css) solo deja ver el escritorio nitido a traves de la
    -- tarjeta, que se lee como "translucido y sucio" en vez de vidrio:
    -- justamente lo que la nota de arriba describe para Quickshell.
    -- `animation = "popin 0%"`: los lanzadores se ABREN desenrollandose
    -- desde el centro en vez de aparecer con el `fade` que usan todas las
    -- layers por defecto (ver `layersIn` en lookandfeel/init.lua). Como
    -- los dos estan centrados en pantalla, el punto del que crecen ES el
    -- centro de la pantalla.
    --
    -- OJO con el alcance de esto: "popin" escala la tarjeta ENTERA de
    -- forma isotropica. Una linea fina que se estira hacia los costados y
    -- recien despues se abre en tarjeta necesitaria escalar cada eje por
    -- separado, y los estilos de animacion de layers de Hyprland
    -- (`fade` / `slide` / `popin`) no exponen eso -- no hay como pedirlo
    -- desde la config. Lo mas cerca que se llega sin escribir un plugin
    -- es esto.
    hl.layer_rule({
        name = "glass-rofi",
        match = { namespace = "^rofi$" },
        blur = true,
        ignore_alpha = 0.05,
        animation = "popin 0%",
    })

    hl.layer_rule({
        name = "glass-wofi",
        match = { namespace = "^wofi$" },
        blur = true,
        ignore_alpha = 0.05,
        animation = "popin 0%",
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

    -- El dialogo de archivos (el que abre Firefox con Ctrl+O, zenity, y en
    -- general cualquier app que pase por el portal) sale TILEADO: se comia
    -- media pantalla y reacomodaba el workspace entero por un dialogo que se
    -- usa 3 segundos y se cierra. Es un modal, se trata como tal.
    --
    -- El class correcto es "xdg-desktop-portal-gtk", NO "zenity" ni el de la
    -- app que lo pidio: verificado en vivo con `hyprctl clients` mientras el
    -- dialogo estaba abierto -- el que dibuja la ventana es el proceso del
    -- portal, asi que una sola regla cubre a todos los que lo usan.
    --
    -- Mismo truco que satty para el tamaño: el API Lua ignora porcentajes en
    -- silencio, pero si evalua expresiones con monitor_w/monitor_h.
    hl.window_rule({
        name = "float-file-chooser",
        match = { class = "^(xdg-desktop-portal-gtk)$" },
        float = true,
        center = true,
        size = "monitor_w*0.6 monitor_h*0.7",
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
