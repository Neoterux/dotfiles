pragma Singleton
import QtQuick
import Quickshell

// Validador compartido de las URLs de icono que llegan por
// StatusNotifierItem y por DBusMenu (`trayItem.icon`, `menuEntry.icon`).
//
// Hace falta porque el proveedor `image://icon/` NUNCA falla: si el nombre
// no existe en el tema devuelve el placeholder "imagen rota" del tema (el
// cuadriculado magenta/negro) con `status === Image.Ready`, asi que no se
// puede detectar el problema despues de cargar -- hay que validar el
// nombre antes.
//
// Pero `hasThemeIcon` solo conoce el tema del SISTEMA, y varias apps
// mandan su icono de otras formas. De ahi los casos de abajo: JetBrains
// Toolbox, por ejemplo, publica IconName "toolbox-tray-color" +
// IconThemePath a su propio directorio de instalacion, que quickshell
// traduce a `image://icon/toolbox-tray-color?path=/home/.../Toolbox/bin` y
// resuelve bien -- validar solo el nombre pelado contra el tema del
// sistema daba false y se comia el logo.
QtObject {
    readonly property string iconScheme: "image://icon/"
    // Pixmap crudo mandado por la app via DBus: no hay nombre de tema que
    // validar, quickshell ya tiene los bytes.
    readonly property string pixmapScheme: "image://qsimage/"

    function usable(url: string): bool {
        if (!url)
            return false;
        if (url.indexOf(pixmapScheme) === 0)
            return true;
        // file://, data:, o cualquier otra cosa que Image resuelve (o
        // falla) por su cuenta, sin placeholder de por medio.
        if (url.indexOf(iconScheme) !== 0)
            return true;

        const rest = url.slice(iconScheme.length);
        const qi = rest.indexOf("?");
        const name = qi === -1 ? rest : rest.slice(0, qi);
        const query = qi === -1 ? "" : rest.slice(qi + 1);

        // La app trae su propio directorio de iconos (IconThemePath del
        // SNI); quickshell busca ahi y el tema del sistema no opina.
        if (/(^|&)path=/.test(query))
            return true;

        if (Quickshell.hasThemeIcon(name))
            return true;

        const fallback = /(^|&)fallback=([^&]*)/.exec(query);
        return fallback ? Quickshell.hasThemeIcon(decodeURIComponent(fallback[2])) : false;
    }
}
