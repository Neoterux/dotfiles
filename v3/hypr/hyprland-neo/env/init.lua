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
    SDL_VIDEODRIVER = 'wayland',

    --[[
        SSH agent: single owner is gcr-ssh-agent (unlocked by gnome-keyring at
        login). Exporting it session-wide stops every GUI app - and any shell
        that inherits the session env - from spawning its own stray ssh-agent.
        UID 1000 is fixed on this box; Hyprland does not expand $XDG_RUNTIME_DIR.
    ]]
    SSH_AUTH_SOCK = '/run/user/1000/gcr/ssh',

    --[[
        Electron / Firefox / JetBrains on wlroots
    ]]
    ELECTRON_OZONE_PLATFORM_HINT = 'auto',
    MOZ_ENABLE_WAYLAND = '1',
    _JAVA_AWT_WM_NONREPARENTING = '1',
}
local M = {}

function M.setup()
    for key, value in pairs(envs) do
        hl.env(key, value)
    end
end

return M
