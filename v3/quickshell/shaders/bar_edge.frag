#version 440

// La mitad del contorno que le toca a la BARRA cuando hay un drawer
// abierto: una linea sobre su filo de abajo con un HUECO exactamente del
// ancho del drawer, para que la linea del drawer (drawer_card.frag) la
// continue y las dos se lean como un solo contorno alrededor de las dos
// piezas.
//
// Por que hacen falta dos shaders y no uno: la barra y el drawer son dos
// superficies Wayland distintas (layer-shell y xdg-popup). Ninguna puede
// dibujar un pixel en la otra, asi que el contorno "unico" son dos
// mitades que se tienen que encontrar en la juntura. Empalman sin
// escalon porque el arco del filete del drawer llega a la barra con
// tangente horizontal, o sea en la misma direccion que esta linea.
//
// El hueco NO se calcula aca: se lo pasa Bar.qml, que predice donde cae
// el popup (PopupWindow no expone su posicion -- `x`/`y` dan undefined,
// verificado). La regla del compositor, medida en pantalla, es "centrado
// en el ancla y despues acotado a la pantalla".
//
// La linea ademas se desvanece al alejarse del drawer en vez de cruzar
// la pantalla entera: asi se lee como el contorno del drawer derramado
// sobre la barra, y no como una regla que le apareció a la barra.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;        // tamaño de la barra, en px
    float lineWidth;  // grosor de la linea, en px
    float gapStart;   // borde izquierdo del drawer, en px de la barra
    float gapEnd;     // borde derecho
    float falloff;    // a cuantos px de distancia la linea ya no se ve
    vec4 borderColor; // Qt lo entrega premultiplicado
} ubuf;

void main() {
    vec2 p = qt_TexCoord0 * ubuf.size;
    // Misma rampa de antialias que drawer_card.frag: las dos mitades del
    // contorno se encuentran en la juntura y si una difumina distinto que
    // la otra, el empalme se nota.
    float aa = 1.0;

    // Banda pegada al filo de abajo.
    float fromBottom = ubuf.size.y - p.y;
    float line = 1.0 - smoothstep(ubuf.lineWidth - aa, ubuf.lineWidth + aa, fromBottom);

    // Hueco donde arranca el drawer.
    float gap = smoothstep(ubuf.gapStart - aa, ubuf.gapStart + aa, p.x) * (1.0 - smoothstep(ubuf.gapEnd - aa, ubuf.gapEnd + aa, p.x));
    line *= 1.0 - gap;

    // Distancia horizontal al hueco (0 dentro, crece al alejarse).
    float dx = max(max(ubuf.gapStart - p.x, p.x - ubuf.gapEnd), 0.0);
    float fade = 1.0 - smoothstep(0.0, max(ubuf.falloff, 1.0), dx);

    fragColor = ubuf.borderColor * line * fade * ubuf.qt_Opacity;
}
