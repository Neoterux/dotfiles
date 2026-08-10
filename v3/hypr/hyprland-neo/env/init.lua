local envs = {
    --[[
     Configuraciones de variables para XDG
    ]]
    XDG_CURRENT_DESKTOP = 'Hyprland',
    XDG_SESSION_TYPE = 'wayland',
    XDG_SESSION_DESKTOP = 'Hyprland',
    --[[
      Configuraciones de variables para QT
    ]]
    QT_AUTO_SCREEN_SCALE_FACTOR = '1',
    QT_QPA_PLATFORM = 'wayland;xcb',
    QT_WAYLAND_DISABLE_WINDOWDECORATION = '1',
    QT_QPA_PLATFORMTHEME = 'qt5ct',
    --[[
        Configuraciones para XCursor y temas
    ]]
    GTK_THEME = 'Nord',
    XCURSOR_THEME = 'Nordzy Cursor',
    XCURSOR_SIZE = '24',

    GDK_BACKEND = 'wayland,x11,*',
    SFL_VIDEODRIVER = 'wayland',
    CLUTTER_BACKEND = 'wayland',
}
local M = {}

function M.setup()
    for key, value in pairs(envs) do
        hl.env(key, value)
    end
end

return M
