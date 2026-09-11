import QtQuick
import Quickshell.Io
import "../../theme"

// Equivalente a "backlight" de waybar. A diferencia de waybar, si la
// maquina no tiene ningun dispositivo en /sys/class/backlight (como esta,
// que son monitores externos sin control por software) el modulo se
// esconde solo en vez de mostrar basura.
Pill {
    id: root
    bg: Colors.backlight
    fg: Colors.textDark
    interactive: true
    // RowLayout/ColumnLayout excluyen automaticamente del layout a los
    // items con visible:false, asi que esto alcanza para "esconder" el
    // modulo entero cuando no hay backlight que controlar.
    visible: device.length > 0

    property string device: ""
    property int pct: 0

    Text {
        // nf-fa-lightbulb_o, mismo codepoint que "backlight" en waybar/config
        text: "\u{f0eb} " + root.pct + "%"
        color: root.fg
        font.family: Colors.fontFamily
        font.pixelSize: root.fontPixelSize
    }

    Process {
        id: detect
        command: ["sh", "-c", "ls /sys/class/backlight 2>/dev/null | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.device = text.trim();
                if (root.device.length > 0)
                    readProc.running = true;
            }
        }
    }

    Process {
        id: readProc
        command: root.device.length > 0 ? ["sh", "-c", `cat /sys/class/backlight/${root.device}/brightness /sys/class/backlight/${root.device}/max_brightness`] : []
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").map(Number);
                if (lines.length === 2 && lines[1] > 0)
                    root.pct = Math.round((lines[0] / lines[1]) * 100);
            }
        }
    }

    // `brightnessctl` y no `light`: light NO esta en los repos de Arch
    // (solo AUR), asi que pedirlo en el setup hacia fallar la transaccion
    // entera de pacman -- "target not found: light" y no se instalaba
    // NADA, ni los otros paquetes de la misma linea. brightnessctl esta
    // en `extra` y hace lo mismo.
    //
    // No necesita root: sus reglas de udev le dan acceso al grupo
    // `video`. Si algun dia sube/baja "sin efecto y sin error", chequear
    // `id -nG | grep video` antes que nada.
    //
    // Solo se usa para SUBIR/BAJAR. La lectura sigue saliendo directo de
    // /sys (readProc), asi que el modulo muestra el porcentaje correcto
    // aunque el brillo lo cambie otra cosa.
    Process {
        id: raiseProc
        command: ["brightnessctl", "set", "+5%"]
    }

    Process {
        id: lowerProc
        // `5%-` (y no `-5%`): con el guion adelante brightnessctl lo toma
        // como una opcion y tira error de parseo.
        command: ["brightnessctl", "set", "5%-"]
    }

    Timer {
        interval: 1000
        running: root.device.length > 0
        repeat: true
        onTriggered: {
            readProc.running = false;
            readProc.running = true;
        }
    }

    Component.onCompleted: detect.running = true

    onWheelUp: {
        raiseProc.running = false;
        raiseProc.running = true;
    }
    onWheelDown: {
        lowerProc.running = false;
        lowerProc.running = true;
    }
}
