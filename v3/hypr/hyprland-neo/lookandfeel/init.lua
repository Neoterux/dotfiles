local M = {}

local curves = {
    { name = "easeOutQuint",   points = { { 0.23, 1 }, { 0.32, 1 } } },
    { name = "easeInOutCubic", points = { { 0.65, 0.05 }, { 0.36, 1 } } },
    { name = "linear",         points = { { 0, 0 }, { 1, 1 } } },
    { name = "almostLinear",   points = { { 0.5, 0.5 }, { 0.75, 1 } } },
    { name = "quick",          points = { { 0.15, 0 }, { 0.1, 1 } } },
}

local animations = {
    { leaf = "global",        speed = 10,   bezier = "default" },
    { leaf = "border",        speed = 5.39, bezier = "easeOutQuint" },
    { leaf = "windows",       speed = 4.79, bezier = "easeOutQuint" },
    { leaf = "windowsIn",     speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" },
    { leaf = "windowsOut",    speed = 1.49, bezier = "linear",       style = "popin 87%" },
    { leaf = "fadeIn",        speed = 1.73, bezier = "almostLinear" },
    { leaf = "fadeOut",       speed = 1.46, bezier = "almostLinear" },
    { leaf = "fade",          speed = 3.03, bezier = "quick" },
    { leaf = "layers",        speed = 3.81, bezier = "easeOutQuint" },
    { leaf = "layersIn",      speed = 4,    bezier = "easeOutQuint", style = "fade" },
    { leaf = "layersOut",     speed = 1.5,  bezier = "linear",       style = "fade" },
    { leaf = "fadeLayersIn",  speed = 1.79, bezier = "almostLinear" },
    { leaf = "fadeLayersOut", speed = 1.39, bezier = "almostLinear" },
    { leaf = "workspaces",    speed = 1.94, bezier = "almostLinear", style = "fade" },
    { leaf = "workspacesIn",  speed = 1.21, bezier = "almostLinear", style = "fade" },
    { leaf = "workspacesOut", speed = 1.94, bezier = "almostLinear", style = "fade" },
    { leaf = "zoomFactor",    speed = 7,    bezier = "quick" },
}

function M.setup()
    hl.config({
        general = {
            gaps_in = 2,
            gaps_out = {
                top = 2,
                right = 8,
                bottom = 8,
                left = 8,
            },
            border_size = 1,

            -- https://wiki.hypr.land/Configuring/Variables/#variable-types for info about colors
            col = {
                active_border = { colors = { "rgb(ebdbb2)", "rgb(d65d0e)" }, angle = 60 },
                inactive_border = "rgb(272727)",
            },

            resize_on_border = true,
            allow_tearing = false,

            layout = "dwindle",
        },

        decoration = {
            rounding = 8,

            shadow = {
                enabled = true,
                range = 4,
                render_power = 3,
                color = "rgba(1a1a1aee)",
            },

            -- Blur detras de ventanas translucidas (kitty corre con
            -- background_opacity 0.45). OJO: `background_blur` de kitty NO
            -- hace nada en Hyprland -- kitty solo implementa blur propio en
            -- macOS y KWin; en Hyprland el desenfoque lo hace el compositor
            -- y depende enteramente de esta seccion.
            blur = {
                enabled = true,
                size = 6,
                passes = 2,
            },
        },

        animations = {
            enabled = true,
        },

        dwindle = {
            preserve_split = true, -- You probably want this
        },

        misc = {
            col = {
                splash = "0x665c54",
            },
            splash_font_family = "JetBrains Mono",
            force_default_wallpaper = -1,
            -- Rendimiento en un escritorio de desarrollo (pantalla estatica la
            -- mayor parte del tiempo): no repintar a full framerate cuando nada
            -- se mueve, y no renderizar logo/splash de fondo.
            --vfr = true,
            vrr = 0,
            disable_hyprland_logo = true,
            disable_splash_rendering = true,
            background_color = "0x1d2021",
        },

        render = {
            -- explicit_sync = 1,
            -- explicit_sync_kms = 1,
            direct_scanout = true,
        },

        input = {
            kb_layout = "us",
            kb_variant = "altgr-intl",
            kb_options = "",
        },
    })

    for _, curve in ipairs(curves) do
        hl.curve(curve.name, { type = "bezier", points = curve.points })
    end

    for _, animation in ipairs(animations) do
        hl.animation({
            leaf = animation.leaf,
            enabled = true,
            speed = animation.speed,
            bezier = animation.bezier,
            style = animation.style,
        })
    end
end

return M
