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
una prenda **lleva tiempo** (anillo de progreso, no se produce mientras).

**Dos formas de atenderlos** (12 sep 2026): en modo **Trabajar** ella sigue tecleando y él aprovecha lo que
lleva al aire: sin blusa le toca las tetas, sin falda le mete mano, desnuda la folla mientras teclea
(`is_touching`, escenas `work_*_<quien>`; se calienta despacio con `touch_rate`, no se impacienta, y a ella
le cuesta concentrarse). Con **Follar** ella deja el portátil: el informe **no avanza**, el acto va a tope
(`arousal_rate`) y las escenas `fuck_*` no muestran el portátil en uso. Si él acaba mientras ella trabaja
sale la viñeta `climaxwork_*`. **El móvil solo se contesta trabajando** (`can_answer`) y cada mensaje sin
responder drena productividad. Desvestida
viste o llega alguien. Cada visita tiene saludo, pista, línea del acto, clímax (viñeta) y despedida en la
barra de diálogo sobre la escena.

Un visitante al que se ignora se cabrea al agotar su paciencia y **se va** poco después con un golpe a la
productividad. Las opciones de los mensajes pueden adelantar visitas (`visit_delay`), echar a alguien (`reject`)
o dar productividad (`productivity`, el café de Mario).

Gana: informe al 100 % antes del fin. Estrellas por atendidos (≥3) y por acabar con ≥30 min de margen.

**Calibración** (12 sep 2026): `tools/balance_sim.tscn` juega la jornada a toda velocidad con cuatro jugadores
automáticos (worker: vestida e ignorando; tease: sin blusa con visita, sigue tecleando mientras la tocan; flirty:
folla con todos y se viste para los controles; nude: desnuda todo el día). Estado: worker 15:39 (2★), tease 15:30
(3★, visitas de ~30 min de juego), flirty 15:47 (3★, ~19 min), nude pierde. Jornada de 10 min reales (1,25 s por
minuto de juego), 12 mensajes + 7 huecos de charla y 8 visitas.
Tocar `report_rate_per_minute`, ritmos/paciencia en `coworkers.json` o los drenajes de `day.gd` → volver a correrlo.

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

## Vídeo: bucles H3 nativos en HD (lo que se ve en el juego)

Los bucles se generan con MiniMax H3 **directamente a 1120×768** (misma proporción que la escena, 24 fps, 90
frames, turbo 6 pasos, ~265 s por clip, con su audio nativo de gemidos): `tools/gen_video.py` con `W,H=1120,768`
(`loops_v2.json` / `loops_hd_part*.json` tienen los prompts por estado) → `.godot/video/hd/*.mp4` →
`tools/finish_hd.sh` (`ffmpeg2theora -v 9` + OGG del propio clip) → `assets/video/<nivel>/<estado>.ogv` + `.ogg`.
El reescalado ×2 de los clips viejos (`tools/upscale_video.py`, RealESRGAN anime) se probó y el usuario lo vio
flojo; el nativo HD es claramente mejor. `scene_view.gd`: vídeo si existe → spritesheet (`assets/anim`, respaldo
704×480 a 12 fps) → imagen fija. El `VideoStreamPlayer` va oculto y se dibuja su textura a mano para que la ropa
colgada y el compañero queden encima (`tools/video_test.tscn`). Godot solo reproduce Theora de forma nativa, también
en HTML5; `brew install ffmpeg2theora` (el ffmpeg de Homebrew ya no lo trae).

**Licencia H3**: la Community License prohíbe *mostrar* sus salidas en EE. UU., UE, UK y Corea (comercial o no) y exige
el cartel "MiniMax H3" en la UI. El usuario lo sabe y decidió seguir con H3 por ahora (12 sep 2026).

## Alternativa descartada: Wan 2.2 + Stable Audio 3

Se montó completa y se descartó tras probarla (movimiento flojo, sonidos que no cuadraban). Queda por si la
monetización obliga a salir de H3:

- **Vídeo**: `tools/gen_video_wan.py` → Wan 2.2 I2V A14B (Apache 2.0; MoE destilado Lightx2v en NVFP4 para la
  Blackwell del pod, 4 pasos sin CFG) con `WanFirstLastFrameToVideo` y la escena como primer y último frame:
  **1056×720, 16 fps, 4,8 s, ~130 s por clip**. `tools/finish_wan_loops.sh` los pasa a Theora con `ffmpeg2theora -v 9`
  (`brew install ffmpeg2theora`; el ffmpeg de Homebrew ya no trae el codificador) → `assets/video/<nivel>/<estado>.ogv`
  (~1 MB cada uno). `scene_view.gd`: vídeo si existe → spritesheet → imagen fija. El `VideoStreamPlayer` va oculto
  y se dibuja su textura a mano para que la ropa colgada y el compañero queden encima (`tools/video_test.tscn`
  comprueba que oculto sigue decodificando). Godot solo reproduce Theora de forma nativa, también en HTML5.
- **Sonido**: `tools/gen_sfx.py` → Stable Audio 3 medium (pesos abiertos, Stability Community License, entrenado
  con audio licenciado) con la receta de la plantilla oficial de ComfyUI: `CLIPLoader` t5gemma tipo `stable_audio`,
  `KSampler` **lcm / simple, 50 pasos, cfg 7**, sin `ConditioningStableAudio` (con la receta de Stable Audio Open
  sale ruido blanco). Clips de 12 s convertidos en bucle sin corte (los últimos 1,5 s se funden con el principio),
  normalizados a −16 LUFS → `assets/sfx/<acto>.ogg` (`work`, `hot`, `oral`, `titjob`, `sex`); `scene_view._sfx_for`
  elige por estado y ropa. No lanzar vídeo y audio a la vez en el pod: cada cambio de modelo cuesta ~100 s.

## Sonido de interfaz, mensajes y pulido

- **Sonidos de UI** sintetizados con ffmpeg (`assets/sfx/ui/*.ogg`: notify, send, click, cloth, steps, knock, bell,
  success, fail, reward) y el autoload `Sfx` (`Sfx.play("notify")`, seis voces, volúmenes `ui`/`scene` guardados en
  `user://audio.json`). Todos los botones de `UIKit` suenan; `game.gd` engancha mensajes, visitas, ropa, clímax,
  castigos y fin de jornada; `scene_view` toma el volumen de escena de `Sfx`.
- **Listado grande de mensajes** (`data/messages.json`, decisión del usuario: nada de LLM): pools por compañero
  (`flirt`, `after`, `angry`) y del jefe (`nag`) con opciones por defecto por pool. Los niveles ponen huecos
  `{"type":"chatter","from":"dani","pool":"flirt"}` y `Day` saca un mensaje no repetido; además cada visita
  satisfecha programa un mensaje `after` y cada visitante que se va cabreado uno `angry`. Solo el primer rechazo del
  día a un compañero tiene consecuencias.
- **Pulido / UI** (12 sep 2026, segunda pasada): fuente **Nunito** (OFL, `assets/fonts`, tema en `assets/ui/theme.tres`,
  negrita como `FontVariation` wght 800 en `UIKit.bold/title`); **HUD sobre la escena** (reloj, tiempo restante,
  informe y pips de productividad; el móvil vuelve a ser solo un móvil) con píldora de estado de Candela; tarjeta de
  acciones con icono y pista bajo el botón principal, estado de cada prenda; pie con velocidad, **pausa**, pantalla
  completa y ajustes; ficha del visitante con avatar, deseo, excitación (llama) y paciencia (reloj de arena); barra de
  diálogo con avatar y nombre; avisos como píldoras con icono. `UIKit.card/pill/bar/round_icon_button`.
  **Pausa real**: `get_tree().paused` (jornada, vídeo y sonido de escena se congelan; música y clics siguen porque `Sfx`
  va en `PROCESS_MODE_ALWAYS`); Esc, el botón de pausa o el de ajustes; "Seguir" continúa donde estaba.
  Botones del pie diferenciados: **‖ pausa** (solo congela; "Seguir" retoma) y **⚙ ajustes** (volúmenes, pantalla
  completa, abandonar con confirmación). Fundido de entrada. `tools/shot_scene.tscn` captura cualquier escena.
- **Menú de inicio** (12 sep 2026): splash art propio a pantalla completa (`assets/ui/title_splash.png`, Qwen desde lienzo
  16:9 con la escena base como referencia: Candela a la derecha apoyada en la mesa, luz dorada) con el **menú en una
  columna a la izquierda** sobre un degradado; **logotipo** (`assets/ui/logo.png`: Qwen sobre verde → `tools/chroma_key.gd`; la O es un reloj y hay un corazón sobre la I; alternativas en `.godot/logo_alts/`), corazones, jornadas con mejor puntuación, pantalla completa,
  salir y versión (los ajustes solo en el juego, ⚙). Candidatos alternativos en `.godot/scene_candidates/splash_menu_*`.
- **Música**: `assets/music/theme.ogg` (Stable Audio 3, funk lo-fi de oficina, 93 s en bucle sin corte) en el
  autoload `Sfx` con su propio slider; se atenúa 10 dB durante sexo, tocarse y clímax (`Sfx.duck_music`).

## TODO

- Nivel 2 (unidad de venta), monetización (días/outfits/packs como contenido, no ventajas), export HTML5 probado en
  navegador, más mensajes en `data/messages.json`.
- `assets/anim` (238 MB) ya no se usa si hay vídeo: borrarlo o moverlo a Git LFS cuando el usuario lo decida.

## Export HTML5

`export_presets.cfg` trae el preset **Web** (GL Compatibility, sin hilos para no exigir cabeceras COOP/COEP en el
hosting, sin PWA). Plantillas de exportación 4.7.2 en `~/Library/Application Support/Godot/export_templates/`.

    godot --headless --path . --export-release Web build/web/index.html
    python3 tools/serve_web.py            # http://localhost:8060 (añade COOP/COEP por si se activan los hilos)

Vídeo Theora y OGG funcionan en web; el navegador exige un clic antes de reproducir audio (Godot lo gestiona: el
primer clic del jugador arranca el mezclador). Tamaño del export: 134 MB (pck de 100 MB + wasm de 40 MB; `assets/anim` queda excluido del preset); en itch.io el límite
por archivo es 500 MB (1 GB en proyectos HTML5 con permiso), así que cabe.

## Hosting (Dokploy)

Todo lo necesario está en `deploy/` y `.github/workflows/deploy.yml`:

- `deploy/Dockerfile`: dos etapas. La primera exporta el juego con `barichello/godot-ci:4.7.2` (Godot + plantillas
  preinstaladas) y comprueba que los medios no sean punteros LFS; la segunda es `nginx:1.27-alpine` con
  `deploy/nginx.conf` (MIME de `.wasm`/`.pck`, gzip, COOP/COEP, `/healthz`). Imagen final ≈ 150 MB.
- `deploy.yml`: en cada push a `main`, checkout **con LFS**, construye la imagen y la publica en
  `ghcr.io/teaminfinityprojects/overtime:latest` (y `:<sha>`); si existe el secreto `DOKPLOY_WEBHOOK_URL`, llama al
  webhook para redeplegar.

Pasos en Dokploy (una vez):

1. Crear una aplicación de tipo **Docker** con la imagen `ghcr.io/teaminfinityprojects/overtime:latest`. Si el paquete
   es privado, añadir en Dokploy un registro `ghcr.io` con un token de GitHub con permiso `read:packages`; o hacer el
   paquete público en GitHub → Packages → overtime → Package settings.
2. Puerto del contenedor **80**; dominio (p. ej. `overtime.fakecams.com` o `play.fakecams.com`) con HTTPS por Traefik.
3. Copiar la URL del webhook de despliegue de la app y guardarla en GitHub → Settings → Secrets → `DOKPLOY_WEBHOOK_URL`.
4. Cada push a `main` publica y redespliega solo. Para probar antes: **Actions → deploy-web → Run workflow**.

Alternativa (Dokploy construyendo desde el repo, tipo *Application* con Dockerfile `deploy/Dockerfile`): solo funciona si
su clon resuelve Git LFS; si no, la primera etapa falla con "es un puntero de Git LFS". Por eso el camino recomendado
es la imagen de GHCR.

Recordatorio legal: la licencia de MiniMax H3 no permite mostrar sus salidas en EE. UU., UE, UK y Corea. Si el
despliegue es público, decidir si se asume o se bloquean esas regiones en Traefik/Cloudflare.

## Git LFS

Desde `b07c8ab` los medios de `assets/` (png, ogv, ogg, mp3, ttf) van por **Git LFS** (`.gitattributes`). Solo hacia
delante: el historial anterior conserva los blobs (el clon sigue pesando ~500 MB; para reescribirlo haría falta
`git lfs migrate import --everything` y un push forzado, decisión pendiente). Cuota gratuita de GitHub: 1 GB de
almacenamiento y 1 GB/mes de ancho de banda LFS; cada clon baja ~260 MB de medios.

## Comandos

    godot -e --path .
    godot --path .
    godot --headless --path . res://tools/smoke_test.tscn        # dos jornadas automáticas: cooperar e ignorar
    godot --headless --path . res://tools/ui_smoke_test.tscn     # jornada completa con la UI montada
    godot --headless --path . res://tools/balance_sim.tscn       # equilibrio: worker / flirty / nude
    godot --path . res://tools/video_test.tscn                   # el vídeo oculto sigue decodificando
    HEARTLINE_POD=<pod> python3 tools/gen_video_wan.py --batch .godot/video/wan_loops.json   # bucles Wan 2.2
    HEARTLINE_POD=<pod> python3 tools/gen_sfx.py --batch .godot/sfx/sfx.json                 # efectos Stable Audio 3
    zsh tools/finish_wan_loops.sh                                # espera al lote, pasa a .ogv y genera los SFX
    python3 tools/pick_sfx.py [.godot/sfx] [--force hot=2]        # elige la semilla más audible por acto → assets/sfx/
    HEARTLINE_POD=<pod> python3 tools/upscale_video.py [clips]    # (descartado) bucles H3 ×2 con RealESRGAN anime
    zsh tools/finish_hd.sh                                       # .godot/video/hd/*.mp4 → assets/video/*.ogv + .ogg
    godot --path . res://tools/shot_scene.tscn -- res://scenes/main_menu.tscn captura.png
    godot --path . --resolution 1280x720 res://tools/screenshot.tscn -- captura.png 28 [fuck|ring|nude|notop|answer|list] [compañero]
    godot --path . res://tools/resize_test.tscn -- prefijo      # comprueba el reescalado en dos tamaños de ventana
