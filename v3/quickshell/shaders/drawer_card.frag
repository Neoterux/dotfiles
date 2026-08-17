#version 440

// Tarjeta del Drawer dibujada por SDF en vez de con un Rectangle: cuerpo
// redondeado abajo + "contracurva" arriba (dos filetes CONCAVOS en las
// esquinas superiores) que la funden con la barra en vez de dejarla como
// un rectangulo flotando debajo.
//
// El truco que faltaba en los intentos viejos (ver v3/CLAUDE.md) es que
// esto no se puede componer con Rectangles/Canvas: la union de un cuerpo
// convexo con dos recortes concavos es una operacion booleana sobre
// distancias con signo, y sale en tres lineas de fragment shader.
//
// Sistema de coordenadas: pixeles, origen arriba-izquierda, Y hacia
// abajo (qt_TexCoord0 * size), NO el Y-arriba de shadertoy.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;      // tamaño del item, en px
    float radius;   // radio de las esquinas de ABAJO
    float wing;     // lado del filete concavo de arriba
    vec4 fill;      // color de la tarjeta (Qt lo entrega premultiplicado)
} ubuf;

// Caja redondeada con radio distinto arriba y abajo. `p` va relativo al
// centro. Arriba el radio es 0: ese borde queda a ras de la barra.
float sdRoundBox(vec2 p, vec2 halfSize, float rTop, float rBot) {
    float r = (p.y < 0.0) ? rTop : rBot;
    vec2 q = abs(p) - halfSize + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

float sdBox(vec2 p, vec2 halfSize) {
    vec2 q = abs(p) - halfSize;
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0)));
}

// Un filete = el cuadrado de la esquina MENOS un disco centrado justo en
// el lado opuesto. Lo que queda es el hueco concavo que abre la tarjeta
// hacia afuera a medida que sube hasta tocar la barra.
//   interseccion(A, B) = max(dA, dB)
//   "afuera del disco" como SDF = r - length(p - c)
float wingFillet(vec2 p, vec2 boxCenter, vec2 discCenter, float w) {
    float dBox = sdBox(p - boxCenter, vec2(w * 0.5));
    float dOutsideDisc = w - length(p - discCenter);
    return max(dBox, dOutsideDisc);
}

void main() {
    vec2 p = qt_TexCoord0 * ubuf.size;
    float w = ubuf.wing;

    // El cuerpo va metido `wing` px de cada lado: los filetes ocupan ese
    // margen y solo alla arriba, asi que la tarjeta "se ensancha" al
    // acercarse a la barra.
    vec2 bodyHalf = vec2(ubuf.size.x * 0.5 - w, ubuf.size.y * 0.5);
    float d = sdRoundBox(p - ubuf.size * 0.5, bodyHalf, 0.0, ubuf.radius);

    if (w > 0.0) {
        d = min(d, wingFillet(p, vec2(w * 0.5, w * 0.5), vec2(0.0, w), w));
        d = min(d, wingFillet(p, vec2(ubuf.size.x - w * 0.5, w * 0.5), vec2(ubuf.size.x, w), w));
    }

    // ~1px de antialias: el SDF esta en px, asi que la rampa es directa.
    float alpha = 1.0 - smoothstep(-0.7, 0.7, d);
    fragColor = ubuf.fill * alpha * ubuf.qt_Opacity;
}
