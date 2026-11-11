# Cómo poner modelos 3D en la Hidra

El juego busca modelos en tu lugar de Studio. Si los encuentra, los usa; si no, construye
la Hidra con bloques. No hace falta tocar código.

## 1. Consigue los modelos (por piezas)

La Hidra pierde y regenera cabezas, así que necesita **piezas separadas**:

| Nombre exacto | Qué es | Obligatorio |
|---|---|---|
| `Head` | Una cabeza de dragón **sin cuello** | Sí, para cambiar las cabezas |
| `GoldenHead` | La cabeza inmortal dorada | No (si falta, usa `Head` con brillo dorado) |
| `Body` | Cuerpo de cuatro patas **sin cabezas ni cuellos**, con cola | Sí, para cambiar el cuerpo |

Los cuellos se siguen dibujando solos.

### Estilo oficial (referencia del equipo)
Hidra de escamas **negro carbón**, **vientre y garganta color hueso** con escamas grandes,
**crestas de púas** color hueso en la nuca, **fauces abiertas** con colmillos largos,
cuatro patas con **garras curvas** y una **cola enroscada cubierta de púas**.

> Si ya tenéis la Hidra completa (con las tres cabezas pegadas), el juego no puede
> usarla tal cual: una figura de una pieza no puede perder una cabeza ni hacer crecer
> dos. Hay que generar el cuerpo y la cabeza **por separado**, con el mismo estilo.

### Opción A: generarlos con la IA de Roblox (gratis)
1. Studio → **Archivo → Funciones beta** → activa **Assistant Mesh Generation**.
2. Abre el **Asistente** y escribe (en inglés suele salir mejor):
   - **Head:** `/generate menacing dragon head of a hydra, black charcoal scales, bone colored spiky crest and horns, wide open jaws with long fangs, cream scaled throat, no neck, isolated`
   - **Body:** `/generate four legged hydra dragon body with no heads and no necks, black charcoal scales, cream scaled belly, bone colored spikes along the back, long curled tail covered in spikes, curved claws`
   - **GoldenHead:** `/generate golden armored dragon head with glowing red eyes, spiky crest, wide open jaws with fangs, no neck, isolated`
3. Genera varias veces hasta que te guste el resultado. Si el cuerpo sale con cuellos,
   no pasa nada grave: los cuellos del juego se dibujan encima.

### Opción B: la Creator Store (Cuadro de herramientas)
1. Pestaña **Ventana → Cuadro de herramientas** (Toolbox), busca `dragon head`, `hydra`…
2. Usa solo modelos con licencia que permita usarlos en tu juego.
3. El juego **borra automáticamente cualquier script** que traiga el modelo (pueden ser
   peligrosos), pero revisa igualmente que solo tenga piezas.

### Opción C: un modelador 3D
Un artista (o tú, con Blender) exporta en `.fbx` u `.obj` y se importa con
**Archivo → Importar 3D**.

## 2. Colócalos donde el juego los busca

1. En el **Explorador**, clic derecho en **ServerStorage → Insertar objeto → Folder**.
2. Llama a la carpeta exactamente **`HydraModels`**.
3. Arrastra cada modelo dentro y renómbralo `Head`, `GoldenHead` o `Body`.
4. Cada uno debe ser un **Model**. Si son piezas sueltas, selecciónalas y pulsa
   **Ctrl+G** para agruparlas.

No hace falta ajustar tamaño ni posición: el juego los escala y los coloca solo.

## 3. Si sale mirando hacia otro lado

El juego espera que el frente del modelo mire hacia delante (su eje −Z). Si la cabeza
sale de lado o al revés:
1. Selecciona el modelo dentro de `HydraModels`.
2. En **Propiedades → Atributos → +**, crea un atributo numérico llamado **`Rotacion`**.
3. Prueba con `90`, `180` o `-90`.

## 4. ¡Guarda el lugar!

Rojo solo sincroniza el código: **los modelos viven en tu archivo de Studio**.
- Guarda con **Archivo → Guardar en Roblox** (o Guardar en archivo).
- Abre **ese mismo lugar** cada vez (no una Baseplate nueva) y conecta Rojo como siempre.

## 5. Comprueba

Pulsa Jugar, entra por la puerta dorada y mira a la Hidra. Si algo sale raro (enorme,
diminuto, flotando, girado), manda una captura.
