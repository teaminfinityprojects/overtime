# Overtime

Juego +18 de gestión de atención, en Godot 4.7 (GL Compatibility, exportable a HTML5).
Referencia: *Barely Working* (DPMaker). Estilo elegido: **animación Flash de los 2000** (LoRA
`flash_cartoon_il` sobre Illustrious), fijado en `data/art_style.json`; ambas herramientas de arte lo leen.

## Bucle

Candela tiene que entregar el informe antes de las 17:00. El informe avanza según su
**productividad** (10 pips). Los compañeros le mandan **mensajes** con pistas y **vienen a su
mesa**: mientras esperan drenan productividad; atenderlos (modo *Follar*) los satisface más
rápido si la ropa (**Blusa / Falda**) es la que quieren, y devuelve productividad. El jefe
avisa de visitas de clientes: si te pilla sin ropa, penalización. Rechazar por mensaje echa a
unos y cabrea a otros (vienen antes y traen refuerzos).

**El acto depende de la ropa** (regla central, tomada de la referencia): vestida → oral; sin blusa → con
las tetas; sin falda o desnuda → sexo. La pista del compañero dice qué acto quiere. Quitarse o ponerse
una prenda **lleva tiempo** (anillo de progreso, no se produce mientras). **Trabaja y folla a la vez**: el
informe avanza según la productividad, que se hunde con él dentro y se recupera al terminar. Desvestida
viste o llega alguien. Cada visita tiene saludo, pista, línea del acto, clímax (viñeta) y despedida en la
barra de diálogo sobre la escena.

Gana: informe al 100 % antes del fin. Estrellas por atendidos (≥3) y por acabar antes de las 16:00.

## Datos

    data/characters/candela/character.json   la chica
    data/coworkers.json                      compañeros: qué quieren, ritmo, paciencia, reacción al rechazo, frases
    data/levels/<id>.json                    jornada: horario, ritmo del informe, eventos (mensajes con opciones, visitas, dress_check)
    assets/scenes/<nivel>/<estado>.png       ilustración por estado (ver clave abajo); si falta, placeholder dibujado

Clave de estado de la escena: `{work|fuck|hot|climax}_{top|notop}_{bottom|nobottom}_{compañero|none}`
(`hot` = distraída y sola; `climax` cae a `fuck` si no hay imagen propia).
Ej.: `fuck_notop_bottom_mario.png`. Añadir un nivel = un JSON; añadir arte = PNG con esa clave.

## Código

    scripts/game/day.gd          simulación pura (sin UI): reloj, informe, productividad, visitas, mensajes
    scripts/game/game.gd         pantalla: panel izquierdo + escena + feedback
    scripts/game/scene_view.gd   ilustración por estado o placeholder
    scripts/autoload/            Metrics (eventos), Catalog (datos), Meta (progreso; persist=false en herramientas)

## Arte: una base + Qwen-Image-Edit (decisión final)

Una imagen base bien hecha (`assets/scenes/<nivel>/work_top_bottom_none.png`) y **todo lo demás por
instrucciones** con Qwen-Image-Edit 2511 (`tools/qwen_edit.py`, batch JSON `in/prompt/out/ref/lora/seed`):
quitar ropa, añadir al compañero con su sprite como referencia (`ref`), actos, tocarse. Fondo, mesa,
tamaño y personaje se conservan solos; no hay máscaras ni capas.

- Modelo `qwenImageEdit2511_fp8` + encoder `qwen_2.5_vl_7b_fp8_scaled` + acelerador Lightning 4 pasos
  (~50 s por edición). Instalados en el pod vía Civicomfy (rápido) y ComfyUI-Manager.
- Actos explícitos: LoRA `qwen_edit_2511_nsfw_all` a 1.0 con su vocabulario ("oral, fellatio", "paizuri,
  titjob", "vaginal, penetration, intercourse", "masturbation"). Sin ella el modelo los esquiva.
- Recetas: partir de la imagen **sin** el hombre y añadirlo en la misma edición (editar sobre una que ya lo
  tiene lo duplica); decir la ropa que debe conservar y "only one man"; 1 de cada 2 semillas suele valer.
- Lotes de prueba y candidatos en `.godot/art_tests/qwen/`; los elegidos se copian a `assets/scenes/`.

## Arte por estados (herramientas anteriores, superadas)

Regla: **una imagen base por nivel y todo lo demás por edición**, para no perder estilo ni continuidad.

    HEARTLINE_POD=<pod> python3 tools/gen_scene.py desk_tuesday work_top_bottom_none        # base (txt2img)
    HEARTLINE_POD=<pod> python3 tools/inpaint_scene.py desk_tuesday --all                   # derivar todos los estados

`inpaint_scene.py` repinta solo una zona (máscaras en `ZONES`, medidas sobre la base) y copia el resto de
píxeles exactos: ropa → zonas `face` (expresión según lo desvestida que va) + `torso`/`hips`; sexo → dos
pasos (`pose_*`: ella inclinada sobre la mesa, luego él detrás en `behind_bent`, estrecha para no tocar la
mesa izquierda).

El compañero **esperando** no se inpainta (el modelo cambia el género o intercambia los roles): es un
**sprite por capas**: `tools/gen_coworker_sprites.py` lo genera de pie sobre verde, `chroma_key.gd` quita el
fondo y `scene_view.gd` lo superpone en `coworker_anchor` del nivel sobre la imagen de ella sola.

Pruebas de estilo guardadas en `.godot/art_tests/` (`styles/` etiquetas, `styles2/` LoRAs y checkpoint).

## Ropa colgada y clímax

- La prenda que se quita aparece colgada en la escena como **sprite superpuesto**: `tools/cutout_diff.gd` recorta
  por diferencia lo que una edición de Qwen añadió a la escena (la blusa en la mampara, la falda sobre el cajón) y
  `scene_view.gd` lo dibuja anclado en fracciones del lienzo (`data/levels/<id>.json → props`). Funciona igual
  sobre imagen fija y sobre bucle animado. Generar la ropa sola sobre verde no funciona: el modelo pinta un cuerpo.
- Viñetas de clímax `climax_{ropa}_{quien}.png`: edición de la escena de sexo con la LoRA NSFW; hay que decir que
  la cara de él queda limpia o le pone fluidos.

## Iconos

Nada de emojis en la UI: **Tabler Icons** (MIT) como SVG en `assets/icons/`, importados a escala 4 (96 px) para que no
pixelen al agrandar la ventana, y tintados por `modulate`. Helpers en `UIKit`: `icon(name, size, color)`,
`icon_text_button(icon, texto, …)`, `flat_icon_button(icon, …)`, `stars(n)`. Godot solo *encoge* el icono de un
botón (`icon_max_width`), nunca lo agranda por encima del alto del texto: si un icono sale pequeño, sube el alto
mínimo del botón. Añadir un icono = descargar el SVG de `@tabler/icons/icons/outline/<nombre>.svg`.

## TODO

- **Calidad de vídeo**: los bucles están a 704×480 y 12 fps en spritesheets de ~8–10 MB (239 MB en total). Para que
  se vea de alta calidad en cualquier pantalla: generar a 1344×768 (máximo local de H3), 24 fps, y servir vídeo real
  (VP9/WebM en el export HTML5, Theora en escritorio) en vez de spritesheets. Pedido por el usuario el 12 sep 2026.
- Sonido de UI, mensajes generados por LLM, nivel 2 (unidad de venta), monetización, commit inicial.

## Comandos

    godot -e --path .
    godot --path .
    godot --headless --path . res://tools/smoke_test.tscn        # dos jornadas automáticas: cooperar e ignorar
    godot --path . --resolution 1280x720 res://tools/screenshot.tscn -- captura.png 28 [fuck|ring|nude|notop|answer|list] [compañero]
    godot --path . res://tools/resize_test.tscn -- prefijo      # comprueba el reescalado en dos tamaños de ventana
