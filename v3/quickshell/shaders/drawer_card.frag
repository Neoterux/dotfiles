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
// Ademas dibuja el BORDE de la tarjeta, que es lo que hace que la
// contracurva se vea: sin una linea que la recorra, la curva queda
// insinuada nada mas por el corte del fondo translucido contra el
// escritorio y practicamente no se lee. El borde se dibuja en todo el
// contorno MENOS en el filo de arriba: ahi la tarjeta se funde con la
// barra, y la barra continua la misma linea desde su propia superficie
// (ver shaders/bar_edge.frag). Las dos mitades empalman sin escalon
// porque el arco del filete llega a la barra con tangente horizontal.
//
// Sistema de coordenadas: pixeles, origen arriba-izquierda, Y hacia
// abajo (qt_TexCoord0 * size), NO el Y-arriba de shadertoy.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;         // tamaño del item, en px
    float radius;      // radio de las esquinas de ABAJO
    float wing;        // lado del filete concavo de arriba
    float borderWidth; // grosor del contorno, en px
    float sweep;       // 0..1, destello que recorre el frente al abrir
    // Continuacion de la aurora de la barra (ver theme/Sheen.qml). La
    // onda se evalua en coordenadas ABSOLUTAS de la barra, no del popup:
    // por eso hacen falta el offset y el ancho de la barra, si no cada
    // drawer arrancaria la onda de cero y la juntura se notaria.
    float sheenTime;
    float sheenIntensity;
    float sheenOriginX; // x del popup dentro de la barra
    float sheenSpanX;   // ancho de la barra
    float sheenFade;    // en cuantos px se apaga hacia abajo
    // Vidrio: realce especular por dentro del contorno. El desenfoque de
    // fondo NO se hace aca -- lo pone el compositor (layer_rule blur de
    // Hyprland). Lo que falta para que se lea como vidrio y no como un
    // panel plano es esto: un filo brillante arriba que se apaga hacia
    // abajo, mas un gradiente muy suave en el relleno.
    float rimWidth;     // grosor del realce interno, en px
    float rimFade;      // en cuantos px se apaga hacia abajo
    float rimStrength;  // 0..1
    vec4 fill;          // color de la tarjeta (Qt lo entrega premultiplicado)
    vec4 borderColor;   // idem
    vec4 rimColor;
    vec4 tintA;
    vec4 tintB;
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

// Un filete = una caja MENOS un disco centrado en el lado opuesto. Lo que
// queda es el hueco concavo que abre la tarjeta hacia afuera a medida que
// sube hasta tocar la barra.
//   interseccion(A, B) = max(dA, dB)
//   "afuera del disco" como SDF = r - length(p - c)
//
// La caja va por `lo`/`hi` y no por centro+lado porque tiene que
// EXTENDERSE hacia adentro del cuerpo. Si terminara justo donde empieza
// el cuerpo, ahi quedaria una juntura interna entre las dos piezas, y
// `min()` de dos SDF devuelve ~0 sobre una juntura asi aunque el punto
// este bien adentro de la union -- la banda del contorno se encendia y
// se veia una linea vertical de mas, paralela al arco (justo "entre la
// tarjeta y la contracurva"). Estirando la caja, la juntura queda
// enterrada donde los dos SDF son bien negativos. El area agregada ya
// estaba dentro del cuerpo, asi que la forma no cambia.
//
// Hacia ABAJO en cambio no se puede estirar: ahi el disco deja de tapar
// y aparecerian pinches fuera de la silueta.
float wingFillet(vec2 p, vec2 lo, vec2 hi, vec2 discCenter, float w) {
    vec2 c = (lo + hi) * 0.5;
    vec2 h = (hi - lo) * 0.5;
    float dBox = sdBox(p - c, h);
    float dOutsideDisc = w - length(p - discCenter);
    return max(dBox, dOutsideDisc);
}

void main() {
    // La forma llega hasta el filo de arriba del item, sin corrimiento.
    // Eso importa para la juntura con la barra: el arco del filete toca
    // y=0 en x=0 con tangente HORIZONTAL, o sea en la misma direccion que
    // la linea de la barra, y las dos se continuan sin codo.
    //
    // (Antes la forma se dibujaba unos px mas arriba y el item la
    // cortaba. Eso resolvia el filo superior, pero se comia justo el
    // pedazo tangente del arco: lo que quedaba se encontraba con la barra
    // a ~25 grados y la juntura se veia corrida, como si los dos
    // contornos no se tocaran.)
    vec2 p = qt_TexCoord0 * ubuf.size;
    vec2 shape = ubuf.size;
    float w = ubuf.wing;

    // El cuerpo va metido `wing` px de cada lado: los filetes ocupan ese
    // margen y solo alla arriba, asi que la tarjeta "se ensancha" al
    // acercarse a la barra.
    vec2 bodyHalf = vec2(shape.x * 0.5 - w, shape.y * 0.5);
    float d = sdRoundBox(p - shape * 0.5, bodyHalf, 0.0, ubuf.radius);

    if (w > 0.0) {
        d = min(d, wingFillet(p, vec2(-w, 0.0), vec2(w * 2.0, w), vec2(0.0, w), w));
        d = min(d, wingFillet(p, vec2(shape.x - w * 2.0, 0.0), vec2(shape.x + w, w), vec2(shape.x, w), w));
    }

    // Antialias: el SDF esta en px, asi que la rampa es directa. 1.0 y no
    // 0.7 porque cerca de la juntura el arco corre casi horizontal, y con
    // una rampa corta ese tramo queda escalonado -- se ve como un
    // saltito de un pixel justo en el empalme.
    float aa = 1.0;
    float alpha = 1.0 - smoothstep(-aa, aa, d);

    // Contorno HACIA ADENTRO, no centrado en d=0. Centrado, la mitad de
    // la banda cae del lado de afuera de la silueta -- o sea, en la
    // juntura, del lado de la barra, donde la barra ya esta dibujando su
    // propia linea; las dos se pisaban medio pixel corridas y el empalme
    // quedaba con un escaloncito. La linea de la barra tambien vive
    // enteramente dentro de su superficie (ver bar_edge.frag), asi que
    // con las dos hacia adentro los trazos quedan alineados de verdad.
    float inD = -d; // positivo hacia adentro de la forma
    float b = smoothstep(-aa, aa, inD) * (1.0 - smoothstep(ubuf.borderWidth - aa, ubuf.borderWidth + aa, inD));

    // El filo de ARRIBA no se contornea: ahi la tarjeta hace cuerpo con
    // la barra, y una linea cruzando la union es justo lo contrario de
    // "una sola pieza".
    //
    // No se puede enmascarar por "y < k": cerca de la juntura el arco del
    // filete tambien es casi horizontal y una mascara asi se lo come. Lo
    // que si distingue los dos casos es preguntar CUAL borde es el mas
    // cercano. Para un punto interior, la distancia al filo superior es
    // simplemente `p.y`; si eso coincide con la distancia al contorno
    // (`-d`), entonces el borde mas cercano ES el filo superior y no hay
    // que dibujarlo. Sobre el arco, en cambio, `-d` es bastante menor que
    // `p.y`, asi que el arco se dibuja entero hasta la esquina.
    float isTopEdge = 1.0 - smoothstep(0.0, 1.2, p.y - (-d));
    b *= 1.0 - isTopEdge;

    // Destello que acompaña el desenrollado: el contorno va mas brillante
    // cerca del filo de abajo, que es el que avanza mientras se abre.
    float front = (1.0 - smoothstep(0.0, 46.0, shape.y - p.y)) * ubuf.sweep;

    vec4 stroke = ubuf.borderColor;
    stroke.rgb *= 1.0 + front * 1.8; // solo el color: el alfa no se toca

    // Aurora: MISMA funcion de onda que bar_sheen.frag evaluada en la
    // MISMA coordenada absoluta, para que el degrade cruce la juntura sin
    // saltos. Verticalmente arranca donde la barra lo dejo (su gradiente
    // termina en 0.35 abajo de todo) y se disuelve hacia el fondo del
    // drawer: sin esto la tarjeta es un plano liso pegado a una barra
    // teñida, y se lee como un recorte.
    float sx = (ubuf.sheenOriginX + p.x) / max(ubuf.sheenSpanX, 1.0);
    float w1 = sin((sx * 2.0 - ubuf.sheenTime * 0.35) * 3.14159);
    float w2 = sin((sx * 3.7 + ubuf.sheenTime * 0.21) * 3.14159 + 1.7);
    float wave = (w1 * 0.6 + w2 * 0.4) * 0.5 + 0.5;
    float vgrad = 0.35 * (1.0 - smoothstep(0.0, max(ubuf.sheenFade, 1.0), p.y));
    vec4 tint = mix(ubuf.tintA, ubuf.tintB, wave);

    // Realce de vidrio: banda por DENTRO del contorno (distancia al borde
    // entre borderWidth y borderWidth+rimWidth), fuerte arriba y apagada
    // hacia abajo, como un filo de vidrio agarrando luz de la barra.
    float inside = inD;
    float rim = smoothstep(ubuf.borderWidth, ubuf.borderWidth + 1.0, inside) * (1.0 - smoothstep(ubuf.borderWidth + ubuf.rimWidth, ubuf.borderWidth + ubuf.rimWidth + 2.0, inside));
    float rimA = rim * (1.0 - smoothstep(0.0, max(ubuf.rimFade, 1.0), p.y)) * ubuf.rimStrength;

    // "over" con alfa premultiplicado: borde encima del relleno.
    vec4 body = ubuf.fill * alpha;
    body += tint * (wave * vgrad * ubuf.sheenIntensity * alpha);
    // El relleno se aclara apenas arriba: sin esto, con el fondo
    // translucido la tarjeta queda igual de plana en todo el alto.
    body.rgb *= 1.0 + 0.10 * (1.0 - smoothstep(0.0, 160.0, p.y));
    body = body + ubuf.rimColor * (rimA * alpha);

    vec4 edge = stroke * b;
    fragColor = (edge + body * (1.0 - edge.a)) * ubuf.qt_Opacity;
}
