# Overtime · export HTML5 servido por nginx.
#
# Etapa 1: exporta el proyecto con Godot 4.7.2 headless (la imagen godot-ci trae el motor y las
# plantillas). Etapa 2: nginx:alpine con build/web y la configuración de deploy/nginx.conf.
#
#   docker build -f deploy/Dockerfile -t overtime-web .
#   docker run --rm -p 8080:80 overtime-web
#
# Los medios de assets/ van por Git LFS: el contexto de build debe traer los archivos reales, no los
# punteros (en GitHub Actions: actions/checkout con lfs: true). La etapa 1 lo comprueba y falla con
# un mensaje claro si no es así.

FROM barichello/godot-ci:4.7.2 AS export
WORKDIR /src
COPY . .
RUN set -e; \
    probe="assets/scenes/desk_tuesday/work_top_bottom_none.png"; \
    if head -c 12 "$probe" | grep -q "version https"; then \
      echo "ERROR: $probe es un puntero de Git LFS. Clona con LFS (git lfs pull) antes de construir." >&2; exit 1; \
    fi; \
    mkdir -p build/web; \
    godot --headless --path . --import >/dev/null 2>&1 || true; \
    godot --headless --path . --export-release Web build/web/index.html; \
    test -s build/web/index.pck && test -s build/web/index.wasm; \
    ls -la build/web

FROM nginx:1.27-alpine
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=export /src/build/web/ /usr/share/nginx/html/
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s CMD wget -q -O /dev/null http://127.0.0.1/healthz || exit 1
