#version 440

// Resplandor suave alrededor de una caja redondeada -- se dibuja DETRAS
// del elemento activo (workspace enfocado, notificacion critica), nunca
// encima: el contenido real lo tapa en el centro y solo se ve el halo
// asomando por los bordes.
//
// No anima nada: con uniforms constantes QtQuick lo dibuja una vez y no
// vuelve a repintar hasta que cambie el estado (cambio de workspace).
// Eso lo deja practicamente gratis para una barra que vive prendida.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;       // tamaño del item (la caja + el margen del halo)
    vec2 boxHalf;    // media caja interior, en px
    float radius;    // radio de la caja interior
    float spread;    // caida del halo, en px
    float cutoff;    // distancia a la que el halo TIENE que valer 0
    float intensity; // opacidad del halo en su punto mas fuerte
    vec4 glowColor;  // Qt lo entrega premultiplicado
} ubuf;

float sdRoundBox(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

void main() {
    vec2 p = qt_TexCoord0 * ubuf.size - ubuf.size * 0.5;
    float d = sdRoundBox(p, ubuf.boxHalf, ubuf.radius);

    // Caida exponencial desde el borde: mucho mas parecido a un bloom
    // real que un smoothstep lineal, y sin el costo de un blur de verdad
    // (que serian dos pasadas y una textura intermedia).
    float dist = max(d, 0.0);
    float glow = exp(-dist / max(ubuf.spread, 0.001));

    // La exponencial nunca llega a cero, asi que sola deja un escalon
    // visible justo en el borde del item (se veia como un recuadro claro
    // alrededor del workspace activo, confirmado en pantalla). Esta
    // ventana la obliga a apagarse del todo antes de llegar al limite.
    glow *= 1.0 - smoothstep(0.0, max(ubuf.cutoff, 0.001), dist);

    fragColor = ubuf.glowColor * glow * ubuf.intensity * ubuf.qt_Opacity;
}
