#version 440

// Entrada de las tarjetas de notificacion: en vez de un fade plano, la
// tarjeta se "materializa" con un barrido de izquierda a derecha y grano
// de ruido en el frente de la ola.
//
// Va como `layer.effect`, asi que `source` es la tarjeta ya rasterizada
// (fondo + icono + textos) y aca solo se decide que pixeles ya
// aparecieron. Dura ~350ms y despues NotificationToast apaga la capa
// entera: en reposo no queda ni la textura intermedia ni el shader.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D source;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;  // 0 = nada visible, 1 = tarjeta entera
    vec4 sparkColor; // tinte del frente de la ola (premultiplicado)
} ubuf;

// Hash de siempre para ruido barato. No hace falta nada mejor: el grano
// se ve 300ms y en celdas de varios px.
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 src = texture(source, uv);

    // Ruido en celdas, no por pixel: por pixel se ve como estatica de TV
    // y a este tamaño de tarjeta queda sucio.
    float n = hash(floor(uv * vec2(60.0, 26.0)));

    // El barrido va adelantado a la izquierda y atrasado a la derecha.
    // Las constantes NO son arbitrarias, son las que hacen que el efecto
    // empiece y termine limpio:
    //   - en progress=0, reveal <= -0.1 < n - 0.09 para todo n >= 0, o
    //     sea alfa 0 en TODAS las celdas (con reveal=0 pelado, las celdas
    //     de ruido bajo arrancaban ya medio visibles: un destello).
    //   - en progress=1, reveal >= 1.2 > n + 0.09 para todo n < 1, o sea
    //     alfa 1 en todas. Sin esto las celdas de ruido alto quedaban en
    //     ~55% y saltaban a opaco de golpe al apagarse la capa.
    float reveal = ubuf.progress * 1.75 - uv.x * 0.45 - 0.1;

    // Visible cuando la ola ya paso el umbral de ruido de esta celda.
    float a = smoothstep(n - 0.09, n + 0.09, reveal);

    // Chispa en el frente: se apaga sola al alejarse la ola.
    float front = (1.0 - smoothstep(0.0, 0.14, abs(reveal - n))) * a;

    fragColor = (src * a + ubuf.sparkColor * front * 0.55) * ubuf.qt_Opacity;
}
