import Quickshell.Io

// Procesos: abre btop en una terminal.
IconButton {
    id: root
    icon: "" // nf-fa-tasks

    Process {
        id: proc
        command: ["kitty", "--", "btop"]
    }

    onLeftClicked: proc.startDetached()
}
