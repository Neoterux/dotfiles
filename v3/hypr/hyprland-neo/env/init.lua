local XDG_RUNTIME_DIR = os.getenv('XDG_RUNTIME_DIR')

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
    -- 'gtk3' y no 'qt5ct': qt5ct NO esta instalado (ni qt6ct), asi que
    -- esta variable apuntaba a un plugin de platform theme inexistente.
    -- Qt6 entonces se quedaba sin tema de iconos y caia a `hicolor`
    -- pelado, que no trae casi nada -- de ahi la lluvia de "Could not
    -- load icon ... at size QSize(42, 42)" en el log de Quickshell:
    -- `printer`, `network-wired`, hasta el propio fallback
    -- `application-x-executable` daban `hasThemeIcon() == false` aunque
    -- los tres existen en Adwaita/breeze, que SI estan instalados.
    --
    -- Medido con `quickshell -p` y una config de 5 lineas, cambiando solo
    -- esta variable:
    --   qt5ct / xdgdesktopportal / vacio -> application-x-executable false
    --   gtk3                             -> application-x-executable true
    -- `libqgtk3.so` esta en /usr/lib/qt6/plugins/platformthemes/, y ademas
    -- deja a las apps Qt siguiendo el tema GTK, que ahora sale de
    -- ~/.config/gtk-3.0 (ver abajo).
    QT_QPA_PLATFORMTHEME = 'gtk3',
    --[[
        Configuraciones para XCursor y temas
    ]]
    -- GTK_THEME iba en 'Nord', pero ese tema NUNCA estuvo instalado:
    -- /usr/share/themes solo tiene Default y Emacs. Y GTK_THEME pisa a
    -- gsettings, asi que GTK3 no encontraba 'Nord', caia al Adwaita
    -- CLARO de fabrica e ignoraba `color-scheme = 'prefer-dark'`. De ahi
    -- que el dialogo de archivos de Firefox saliera blanco en un
    -- escritorio gruvbox. Peor: hl.env llega al entorno de systemd
    -- --user, asi que tambien se lo comian los portals activados por
    -- dbus.
    --
    -- Sin la variable, GTK lee gtk-theme='Adwaita' + prefer-dark de
    -- gsettings y el tinte gruvbox lo ponen ~/.config/gtk-3.0/gtk.css y
    -- ~/.config/gtk-4.0/gtk.css. Una sola fuente de color para GTK y,
    -- via QT_QPA_PLATFORMTHEME=gtk3, tambien para Dolphin y demas Qt.
    --
    -- Mismo cuento con el cursor: 'Nordzy Cursor' tampoco existe aca.
    -- Instalados hay Adwaita, breeze* y Bibata-*; Bibata-Modern-Amber es
    -- el que pega con el naranja #fe8019 del rice.
    XCURSOR_THEME = 'Bibata-Modern-Amber',
    XCURSOR_SIZE = '24',

    GDK_BACKEND = 'wayland,x11,*',
    SDL_VIDEODRIVER = 'wayland',
    CLUTTER_BACKEND = 'wayland',

    --[[
        SSH agent: single owner is gcr-ssh-agent (unlocked by gnome-keyring at
        login). Exporting it session-wide stops every GUI app - and any shell
        that inherits the session env - from spawning its own stray ssh-agent.
        UID 1000 is fixed on this box; Hyprland does not expand $XDG_RUNTIME_DIR.
    ]]
    SSH_AUTH_SOCK = '/run/user/1000/gcr/ssh',

    --[[
      GNOME Keyring (Secret Service para Bitwarden). En esta version
      (50.0) gnome-keyring-daemon YA NO soporta un componente "ssh"
      (--help solo lista pkcs11,secrets) -- el agente SSH lo sigue
      dando gcr-ssh-agent (paquete gcr), que ya exporta su propio
      SSH_AUTH_SOCK via systemd --user, asi que no se pisa aca.
      gnome-keyring-daemon siempre crea sus sockets en
      $XDG_RUNTIME_DIR/keyring.
    ]]
    GNOME_KEYRING_CONTROL = XDG_RUNTIME_DIR .. '/keyring',

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
