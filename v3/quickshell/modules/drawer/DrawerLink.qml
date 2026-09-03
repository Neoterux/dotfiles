pragma Singleton
import QtQuick

// Puente entre el drawer que esta abierto y la barra que tiene que
// continuarle el contorno (ver shaders/bar_edge.frag).
//
// Hace falta un singleton y no una property encadenada porque las dos
// puntas viven en ramas distintas del arbol: el Drawer lo instancia cada
// modulo (Clock, Volume, NotificationCenter, ...) bien adentro, y quien
// tiene que dibujar el otro pedazo es Bar.qml, que esta arriba de todos.
// Pasarlo a mano obligaria a que cada modulo intermedio reenvie una
// property que no le importa -- justo lo que ya se evita con
// NotificationState.
//
// Solo puede haber un drawer abierto a la vez (Bar.qml cierra los demas
// al abrir uno), asi que alcanza con un unico juego de valores. `window`
// desempata entre monitores: cada barra dibuja el contorno solo si el
// drawer abierto es de SU PanelWindow.
QtObject {
    // PanelWindow del drawer abierto, o null si no hay ninguno.
    property var window: null
    // Borde izquierdo del popup y su ancho, en coordenadas de la barra.
    property real x: 0
    property real width: 0
    // Cuantos px se mete la linea de la barra por encima del ancho del
    // drawer, para que los dos trazos se solapen en la juntura en vez de
    // apenas tocarse (ver Drawer.joinOverlap).
    property real join: 0
    // 0..1 de la animacion de apertura: la barra desvanece su mitad del
    // contorno con el mismo valor para que las dos aparezcan juntas.
    property real reveal: 0
}
