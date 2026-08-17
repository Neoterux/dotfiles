#version 440

// Brillo/aurora que recorre el fondo de la barra muy despacio. Se dibuja
// ENCIMA del fondo de la barra con alfa bajisima, asi que tiñe sin tapar.
//
// OJO CON EL COSTO: este es el unico shader del shell que anima solo, y
// una barra esta visible el 100% del tiempo -- cada frame que pida es un
// frame de GPU que nadie pidio. Por eso `time` NO lo maneja una
// NumberAnimation (que repinta a la tasa del monitor, 144/165Hz): lo
// mueve un Timer a ~15fps desde Bar.qml, que para un degrade que tarda
// ~40s en cruzar la pantalla es visualmente identico y cuesta 10 veces
// menos. Ver el comentario en Bar.qml antes de "mejorarlo".

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float intensity; // alfa maxima del tinte
    vec4 tintA;      // premultiplicados por Qt
    vec4 tintB;
} ubuf;

void main() {
    vec2 uv = qt_TexCoord0;

    // Dos ondas de periodos distintos (y una desplazada en contrafase)
    // para que el patron no se lea como un loop obvio -- con una sola
    // onda se nota el ciclo enseguida.
    float w1 = sin((uv.x * 2.0 - ubuf.time * 0.35) * 3.14159);
    float w2 = sin((uv.x * 3.7 + ubuf.time * 0.21) * 3.14159 + 1.7);
    float wave = (w1 * 0.6 + w2 * 0.4) * 0.5 + 0.5;

    // Un poco mas fuerte arriba que abajo: le da volumen a una barra que
    // por lo demas es un rectangulo plano.
    float vgrad = mix(1.0, 0.35, uv.y);

    vec4 tint = mix(ubuf.tintA, ubuf.tintB, wave);
    float a = wave * vgrad * ubuf.intensity;

    fragColor = tint * a * ubuf.qt_Opacity;
}
