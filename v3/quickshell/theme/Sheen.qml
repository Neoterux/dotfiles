pragma Singleton
import QtQuick

// Reloj y parametros compartidos de la aurora del fondo: la que dibuja la
// barra (shaders/bar_sheen.frag) y su continuacion dentro de los drawers
// (shaders/drawer_card.frag).
//
// Es un singleton justamente porque el degrade tiene que ser EL MISMO en
// las dos superficies. Si cada una llevara su propio contador, las ondas
// no coincidirian en la juntura y el drawer se volveria a leer como un
// recorte pegado a la barra -- que es lo que se quiere evitar. Un unico
// tiempo global tambien deja los dos monitores en fase.
QtObject {
    id: root

    property bool enabled: true
    property real time: 0
    property real intensity: 0.14

    readonly property color tintA: Colors.accent
    readonly property color tintB: Colors.clock

    // A proposito un Timer y no una NumberAnimation: la animacion
    // declarativa repinta a la tasa del monitor (144/165Hz aca), y para
    // un degrade que tarda ~40s en cruzar la barra eso es tirar ~130
    // frames por segundo a la basura. A 15fps se ve igual.
    readonly property Timer ticker: Timer {
        running: root.enabled
        repeat: true
        interval: 66
        onTriggered: root.time += 0.066
    }
}
