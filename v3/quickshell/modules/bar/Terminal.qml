import Quickshell.Io

// Abre una terminal (kitty).
IconButton {
    id: root
    icon: "" // nf-fa-terminal

    Process {
        id: proc
        command: ["kitty"]
    }

    onLeftClicked: proc.startDetached()
}
