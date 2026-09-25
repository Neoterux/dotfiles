local M = {}

-- Zoom corre por XWayland y TODAS sus ventanas comparten class "zoom": la
-- unica forma de distinguir un overlay de la ventana principal es el titulo.
-- Los titulos son los nombres internos que Zoom le pone a cada surface
-- (verificables con `hyprctl clients` mientras estan abiertas):
--   - "menu window"                    menus desplegables (reacciones, "Mas", ...)
--   - "zoom"                           tooltips y popups sueltos
--   - "as_toolbar"                     barra de control al compartir pantalla
--   - "zoom_linux_float_video_window"  miniatura flotante de video al compartir
--   - "cpt_frame_xcb_window"           marco verde que rodea lo compartido
--   - "AnnoInputLinux" / "annotate_toolbar"  anotaciones sobre lo compartido
--
-- Este modulo se carga DESPUES de workspaces: la regla generica
-- "no-initial-focus-xwayland" le quita el foco inicial a toda ventana
-- XWayland, y los menus de Zoom se cierran solos si no lo reciben. Aca se
-- revierte solo para los menus.
local ZOOM = "^(zoom)$"

-- Lo comun a todo overlay: sin decoracion ni animacion, porque Hyprland les
-- dibujaba borde, sombra y blur a surfaces que Zoom ya dibuja como
-- flotantes sin marco.
local function overlay(spec)
    local rule = {
        float = true,
        border_size = 0,
        no_shadow = true,
        no_blur = true,
        no_anim = true,
        no_dim = true,
    }
    for key, value in pairs(spec) do
        rule[key] = value
    end
    return rule
end

function M.setup()
    -- TODAS las ventanas de Zoom flotan, incluida la principal y la de la
    -- reunion: tileadas reacomodaban el workspace cada vez que Zoom abria o
    -- cerraba algo. Va PRIMERO y solo con `float`: las reglas de abajo
    -- (centrado, tamaño, pin) pisan lo que corresponda por titulo, y un
    -- `center` aca moveria tambien los overlays (toolbar, video flotante).
    hl.window_rule({
        name = "zoom-float-all",
        match = { class = ZOOM },
        float = true,
    })

    -- Ventana principal y de reunion: centradas y grandes, no del tamaño
    -- chico con el que Zoom las pide. Titulos de Zoom 6.x/7.x ("Zoom
    -- Workplace" es el inicio; la reunion es "Zoom Meeting" o "Meeting"
    -- segun la version) -- NO verificados en vivo con esta version (7.2.1):
    -- si una no matchea, `hyprctl clients` con Zoom abierto da el titulo real.
    hl.window_rule({
        name = "zoom-main",
        match = { class = ZOOM, title = "^(Zoom Workplace|Zoom Meeting|Meeting)$" },
        center = true,
        size = "monitor_w*0.7 monitor_h*0.8",
    })

    -- "confirm window" es el popup de confirmacion (p.ej. al entrar a una
    -- breakout room): se cierra solo apenas se mueve el mouse igual que los
    -- menus. Encontrado por la comunidad:
    -- https://notes.joshrnoll.com/notes/hyprland-hot-fixes/
    hl.window_rule(overlay({
        name = "zoom-menus",
        match = { class = ZOOM, title = "^(menu window|confirm window|zoom)$" },
        no_initial_focus = false,
        stay_focused = true,
    }))

    -- Pinneados para que sigan visibles al cambiar de workspace durante
    -- la reunion, y sin foco inicial para no robarselo a lo que se comparte.
    hl.window_rule(overlay({
        name = "zoom-share-toolbar",
        match = { class = ZOOM, title = "^(as_toolbar)$" },
        pin = true,
        no_initial_focus = true,
    }))

    hl.window_rule(overlay({
        name = "zoom-float-video",
        match = { class = ZOOM, title = "^(zoom_linux_float_video_window)$" },
        pin = true,
        no_initial_focus = true,
    }))

    -- El marco de pantalla compartida es puramente decorativo: nunca debe
    -- tomar el foco ni quedar en el ciclo de ventanas.
    hl.window_rule(overlay({
        name = "zoom-share-frame",
        match = { class = ZOOM, title = "^(cpt_frame_xcb_window|cpt_frame_window)$" },
        pin = true,
        no_focus = true,
        no_initial_focus = true,
    }))

    hl.window_rule(overlay({
        name = "zoom-annotations",
        match = { class = ZOOM, title = "^(AnnoInputLinux|annotate_toolbar)$" },
        pin = true,
    }))

    -- Paneles secundarios: son dialogos, no merecen reacomodar el workspace.
    -- Mismo truco de tamaño que float-file-chooser (el API Lua ignora
    -- porcentajes, pero evalua monitor_w/monitor_h).
    hl.window_rule({
        name = "zoom-dialogs",
        match = { class = ZOOM, title = "^(Settings|Chat|Participants.*|Polls.*|Zoom - .* Account)$" },
        float = true,
        center = true,
        size = "monitor_w*0.4 monitor_h*0.6",
    })

    -- xwaylandvideobridge (autostart de KDE, se deja prendido a proposito):
    -- Zoom corre por XWayland y solo ve ventanas XWayland, asi que para
    -- compartir una ventana Wayland o la pantalla entera pasa por el puente.
    -- El puente abre una ventana propia que en KDE se oculta sola; en
    -- Hyprland no (wiki de Screen Sharing), y quedaba como una ventana vacia
    -- robando foco. Estas son las reglas que usa la comunidad para
    -- volverla invisible e inerte.
    hl.window_rule({
        name = "xwaylandvideobridge-hide",
        match = { class = "^(xwaylandvideobridge)$" },
        opacity = "0.0 override",
        max_size = "1 1",
        no_anim = true,
        no_blur = true,
        no_focus = true,
        no_initial_focus = true,
    })
end

return M
