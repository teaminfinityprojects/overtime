# Guía de Integración - API de Métricas (Landing Metrics)

Documentación completa para integrar el sistema de métricas Landing Metrics en cualquier proyecto web o móvil. Esta API permite registrar eventos de usuario (vistas, clicks, tiempo de permanencia, scroll) con soporte para atribución de campañas UTM, segmentación por dispositivo y geolocalización.

---

## 1. Resumen de la API

Landing Metrics expone un único endpoint HTTP que recibe eventos de analítica vía POST. Cada evento describe una interacción del usuario con tu aplicación.

### Características principales

- **Un solo endpoint** — Toda la analítica se envía al mismo URL
- **5 tipos de evento** — `view`, `click`, `event`, `view_time`, `scroll_depth`
- **Atribución UTM integrada** — Los parámetros UTM se envían como campos de primer nivel
- **Segmentación automática** — Soporte para país (`country`) y dispositivo (`device`)
- **Metadata flexible** — Campo JSON para datos específicos de tu dominio (max 255 chars), con `offer_slug` como campo obligatorio en eventos `click`
- **Endpoint de conversaciones** — Segundo endpoint dedicado para registrar mensajes de conversación de usuarios
- **Fire-and-forget** — Diseñado para no bloquear la experiencia del usuario
- **Uso recomendado desde el cliente** — La integración debe realizarse preferentemente del lado del cliente (navegador) para capturar correctamente el contexto del usuario (URL, device, UTM params, etc.)

---

## 2. Endpoint HTTP

### Request

| Campo | Valor |
|-------|-------|
| **Method** | `POST` |
| **Content-Type** | `application/json` |
| **URL** | `https://landingmetrics.tech555.dev/log` |

### Payload completo

```typescript
interface AnalyticsEvent {
  // --- Campos obligatorios ---
  type: string;           // "click" | "view" | "event" | "view_time" | "scroll_depth"

  // --- Campos de contexto ---
  page?: string;          // URL completa de la página (max 2000 chars)
  uuid?: string;          // UUID único del visitante (max 100 chars)
  metadata?: string;      // JSON stringificado con datos adicionales (max 255 chars)
                          // ⚠️ DEBE contener "offer_slug" en eventos "click" (ver sección 2.1)

  // --- Segmentación ---
  country?: string;       // Código ISO del país (max 5 chars, ej: "US", "MX", "AR")
  device?: string;        // Tipo de dispositivo: "mobile" | "desktop" | "tablet"

  // --- Atribución UTM (max 200 chars cada uno) ---
  utm_source?: string;    // Origen del tráfico (ej: "google", "instagram", "newsletter")
  utm_medium?: string;    // Medio de la campaña (ej: "cpc", "social", "email")
  utm_campaign?: string;  // Nombre de la campaña (ej: "black_friday_2025")
  utm_content?: string;   // Variante del anuncio (ej: "banner_v2", "cta_rojo")
  utm_term?: string;      // Término de búsqueda (ej: "zapatos running")
  a?: string;             // Parámetro personalizado (ej: ID de afiliado, subID)
}
```

### 2.1 Campo crítico: `offer_slug` (obligatorio en clicks)

> **IMPORTANTE:** El campo `offer_slug` dentro del `metadata` es **obligatorio para todos los eventos de tipo `click`**. La API lo utiliza como clave principal para indexar, agrupar y consultar los eventos de click. **Sin `offer_slug`, el evento de click no se procesará correctamente en el backend.**

`offer_slug` responde a la pregunta: **"¿a qué le dio click el usuario?"**. Es la etiqueta que identifica el elemento o la acción que el usuario clickeó, y es lo que permite después filtrar y analizar los clicks por tipo.

No necesita ser el slug de un recurso específico — puede (y suele) ser simplemente **el nombre de la acción que realizó el usuario**:

- `"like"` → El usuario dio like
- `"share"` → El usuario compartió algo
- `"search"` → El usuario usó el buscador
- `"filter"` → El usuario aplicó un filtro
- `"social"` → El usuario clickeó un link de red social
- `"review"` → El usuario clickeó para dejar una reseña
- `"subscribe"` → El usuario se suscribió
- `"add-to-cart"` → El usuario agregó algo al carrito
- `"checkout"` → El usuario inició el checkout
- `"plan-pro"` → El usuario clickeó un plan específico

La idea es que al ver los datos, puedas agrupar por `offer_slug` y saber exactamente **qué tipo de clicks** están ocurriendo en tu aplicación.

```typescript
// ✅ Correcto: el usuario dio like
metadata: '{"offer_slug":"like","action":"like","creator_slug":"juan-perez"}'

// ✅ Correcto: el usuario compartió contenido
metadata: '{"offer_slug":"share","action":"share","method":"whatsapp"}'

// ✅ Correcto: el usuario clickeó un producto específico
metadata: '{"offer_slug":"zapatillas-x100","action":"add_to_cart","product_id":1234}'

// ✅ Correcto: el usuario usó el buscador
metadata: '{"offer_slug":"search","action":"search","term":"zapatos running"}'

// ❌ Incorrecto: click sin offer_slug — NO será procesado correctamente
metadata: '{"action":"add_to_cart","product_id":1234}'
```

**Ejemplos de `offer_slug` por tipo de aplicación:**

| Tipo de app | `offer_slug` | Qué clickeó el usuario |
|-------------|-------------|------------------------|
| **Cualquiera** | `"like"` | Botón de like / favorito |
| **Cualquiera** | `"share"` | Botón de compartir |
| **Cualquiera** | `"search"` | Resultado de búsqueda |
| **Cualquiera** | `"filter"` | Filtro o categoría |
| **Cualquiera** | `"social"` | Link a red social |
| **E-commerce** | `"add-to-cart"` | Botón de agregar al carrito |
| **E-commerce** | `"checkout"` | Botón de comprar |
| **E-commerce** | `"zapatillas-x100"` | Un producto específico |
| **SaaS** | `"export"` | Botón de exportar datos |
| **SaaS** | `"plan-pro"` | Un plan de suscripción |
| **Blog** | `"review"` | Botón de dejar reseña |
| **Blog** | `"subscribe"` | Botón de suscribirse al newsletter |

> Para eventos `click`, el campo `offer_slug` es **obligatorio**. Para eventos `event`, es **altamente recomendado** ya que permite identificar y agrupar el tipo de acción (ej: `"message_sent"`, `"registration"`, `"session_start"`). Para `view`, `view_time` y `scroll_depth`, no es necesario.

### Límites de campo

| Campo | Límite |
|-------|--------|
| `page` | 2000 caracteres |
| `uuid` | 100 caracteres |
| `metadata` | 255 caracteres (JSON stringificado) |
| `metadata.offer_slug` | Obligatorio en eventos `click` |
| `country` | 5 caracteres |
| Campos UTM (`utm_*`, `a`) | 200 caracteres cada uno |

### Respuesta

El endpoint no retorna datos útiles. Se recomienda tratar todas las llamadas como fire-and-forget: no esperar la respuesta ni manejar errores de red.

---

## 2.2 Endpoint de Conversaciones

Además del endpoint principal `/log`, existe un segundo endpoint dedicado para registrar mensajes de conversación de usuarios.

### Request

| Campo | Valor |
|-------|-------|
| **Method** | `POST` |
| **Content-Type** | `application/json` |
| **URL** | `https://landingmetrics.tech555.dev/log_user_conversation` |

### Payload

```typescript
interface ConversationLog {
  session_id: string;   // ID de sesión del chat/conversación
  message: string;      // Contenido del mensaje del usuario
}
```

### Ejemplo

```bash
curl -X POST https://landingmetrics.tech555.dev/log_user_conversation \
  -H "Content-Type: application/json" \
  -d '{
    "session_id": "sess_abc123",
    "message": "Hola, quiero saber más sobre tus servicios"
  }'
```

> Este endpoint es útil para aplicaciones con chat o mensajería donde se desea registrar los mensajes del usuario para análisis posterior. Al igual que `/log`, debe tratarse como fire-and-forget.

---

## 2.3 Recomendación: Uso desde el Cliente (Client-Side)

> **IMPORTANTE:** Se recomienda que la integración con Landing Metrics se realice **desde el lado del cliente** (navegador), no desde el servidor (SSR/backend).

### ¿Por qué client-side?

1. **Contexto del usuario disponible** — Desde el navegador tienes acceso directo a `window.location` (URL completa), `localStorage` (UUID persistente), `sessionStorage` (UTM params), y el User-Agent del dispositivo.

2. **URLs correctas** — Cuando se envían eventos desde el servidor (SSR), la URL de la página no siempre está disponible o requiere construcción manual. Desde el cliente, `window.location.href` siempre tiene la URL completa y correcta.

3. **Parámetros UTM** — Los parámetros UTM llegan en la URL del navegador. Capturarlos y propagarlos es natural desde el cliente; desde el servidor requiere lógica adicional de forwarding.

4. **Detección de dispositivo** — Desde el cliente puedes usar APIs nativas del navegador para detectar el tipo de dispositivo, tamaño de pantalla, etc.

5. **Performance** — Las llamadas fire-and-forget desde el cliente no bloquean el rendering del servidor ni consumen recursos del backend.

### Excepciones válidas para uso server-side

- **Enriquecimiento con geolocalización** — Si necesitas el `country` desde headers como `CF-IPCountry`, puedes usar un middleware que enriquezca los datos antes de que el cliente los envíe, o enviar el país como prop al componente cliente.
- **Logging de conversaciones** — El endpoint `/log_user_conversation` puede llamarse desde el servidor si los mensajes se procesan en un API route o server action.
- **Eventos de backend** — Webhooks, procesamiento batch, o eventos que no tienen origen en una acción del usuario en el navegador.

---

## 3. Tipos de Eventos

### 3.1 `view` — Vista de página o sección

Se registra cuando un usuario carga o ve una página. Debe enviarse una sola vez por carga de página.

```bash
curl -X POST https://landingmetrics.tech555.dev/log \
  -H "Content-Type: application/json" \
  -d '{
    "type": "view",
    "page": "https://mi-tienda.com/productos/zapatillas-running",
    "uuid": "a1b2c3d4-e5f6-4789-abcd-ef0123456789",
    "metadata": "{\"category\":\"running\",\"product_id\":1234}",
    "country": "MX",
    "device": "mobile"
  }'
```

**Usos comunes:**
- Registrar vistas de páginas de producto en un e-commerce
- Contar visitas a artículos de un blog o documentación
- Medir vistas de dashboards en una app SaaS
- Trackear pantallas visitadas en una app móvil (via API REST)

### 3.2 `click` — Interacción del usuario

Se registra cuando un usuario hace click en un elemento interactivo (botón, enlace, tarjeta, CTA).

> **Recordatorio:** El campo `offer_slug` es **obligatorio** en el metadata de este evento. Ver [sección 2.1](#21-campo-crítico-offer_slug-obligatorio-en-clicks) para detalles y ejemplos.

```bash
curl -X POST https://landingmetrics.tech555.dev/log \
  -H "Content-Type: application/json" \
  -d '{
    "type": "click",
    "page": "https://mi-tienda.com/productos/zapatillas-running",
    "uuid": "a1b2c3d4-e5f6-4789-abcd-ef0123456789",
    "metadata": "{\"offer_slug\":\"zapatillas-running\",\"action\":\"add_to_cart\",\"product_id\":1234}",
    "country": "MX",
    "device": "mobile",
    "utm_source": "google",
    "utm_medium": "cpc",
    "utm_campaign": "running_shoes_mx"
  }'
```

**Usos comunes:**
- Trackear clicks en botones "Agregar al carrito" o "Comprar ahora"
- Registrar clicks en links externos (afiliados, partners)
- Medir interacción con elementos de UI (likes, shares, favoritos)
- Trackear uso de filtros y búsquedas
- Registrar clicks en CTAs de landing pages

### 3.3 `event` — Evento personalizado

Se registra para acciones del usuario que no encajan en `view` o `click`. Representa eventos de negocio o interacciones específicas de la aplicación.

```bash
curl -X POST https://landingmetrics.tech555.dev/log \
  -H "Content-Type: application/json" \
  -d '{
    "type": "event",
    "page": "https://mi-app.com/chat/modelo123",
    "uuid": "a1b2c3d4-e5f6-4789-abcd-ef0123456789",
    "metadata": "{\"offer_slug\":\"message_sent\",\"model\":\"Modelo123\"}"
  }'
```

**Usos comunes:**
- Registrar envío de mensajes en un chat (`offer_slug: "message_sent"`)
- Trackear acciones específicas disparadas por el usuario (`offer_slug: "action_triggered"`)
- Registrar cuando un usuario alcanza un rate limit (`offer_slug: "rate_limit_reached"`)
- Marcar inicio de sesión (`offer_slug: "session_start"`)
- Registrar conversiones como registros (`offer_slug: "registration"`)

> **Nota:** Para eventos de tipo `event`, se recomienda incluir `offer_slug` en el metadata para identificar el tipo de evento y permitir agrupación en el análisis.

### 3.4 `view_time` — Tiempo de permanencia

Se registra para medir cuánto tiempo un usuario permanece en una página. Puede enviarse al salir de la página o periódicamente.

```bash
curl -X POST https://landingmetrics.tech555.dev/log \
  -H "Content-Type: application/json" \
  -d '{
    "type": "view_time",
    "page": "https://mi-blog.com/articulo/guia-completa-seo",
    "uuid": "a1b2c3d4-e5f6-4789-abcd-ef0123456789",
    "metadata": "{\"seconds\":185,\"category\":\"seo\"}",
    "country": "AR",
    "device": "desktop"
  }'
```

**Usos comunes:**
- Medir engagement con artículos o contenido largo
- Comparar tiempo de permanencia entre páginas de producto
- Evaluar la calidad del tráfico de diferentes campañas
- Detectar contenido con alta tasa de rebote

### 3.5 `scroll_depth` — Profundidad de scroll

Se registra cuando el usuario alcanza ciertos hitos de scroll (25%, 50%, 75%, 100%). Útil para contenido largo.

```bash
curl -X POST https://landingmetrics.tech555.dev/log \
  -H "Content-Type: application/json" \
  -d '{
    "type": "scroll_depth",
    "page": "https://mi-saas.com/pricing",
    "uuid": "a1b2c3d4-e5f6-4789-abcd-ef0123456789",
    "metadata": "{\"scroll_depth_percent\":75}",
    "country": "US",
    "device": "desktop"
  }'
```

**Usos comunes:**
- Medir hasta dónde leen los usuarios un artículo o landing page
- Detectar si los usuarios llegan a secciones clave (pricing, testimonios, CTA final)
- Optimizar la posición de elementos de conversión
- Evaluar la efectividad del diseño de páginas largas

---

## 4. Campo `metadata` — Datos específicos del dominio

El campo `metadata` es un JSON stringificado que permite enviar datos contextuales específicos de tu negocio. Tiene un límite de **255 caracteres**.

### Diseño del metadata

Incluye solo los datos mínimos necesarios para el análisis. **Para eventos `click`, el campo `offer_slug` es obligatorio.**

Algunos patrones útiles:

#### E-commerce (clicks)

```json
{"offer_slug":"zapatillas-x100","action":"add_to_cart","product_id":1234,"price":89.99}
{"offer_slug":"checkout","action":"purchase","cart_total":245.50,"items_count":3}
{"offer_slug":"search","action":"search","term":"zapatos running","results":42}
```

#### SaaS / Plataforma (clicks)

```json
{"offer_slug":"create-project","action":"create_project","plan":"pro","team_size":5}
{"offer_slug":"export","action":"export","format":"csv","rows":1500}
{"offer_slug":"filter","action":"filter","section":"analytics"}
```

#### Blog / Contenido (views y clicks)

```json
{"category":"tech","author":"jperez","word_count":2400}
{"offer_slug":"share","action":"share","platform":"twitter","article_id":567}
```

#### App Móvil (clicks)

```json
{"offer_slug":"premium-monthly","action":"purchase","price":9.99}
{"offer_slug":"onboarding-skip","action":"skip","step":3}
```

> **Nota:** Para eventos `view`, `view_time` y `scroll_depth`, el campo `offer_slug` no es obligatorio. El metadata es libre para esos tipos de evento.

### Sanitización recomendada

Para evitar superar el límite de 255 chars:

1. **Truncar strings largos** — URLs a ~60 chars, textos generales a ~50 chars
2. **Eliminar caracteres de control** — Strip de `\n`, `\r`, `\t`, etc.
3. **Reducción progresiva** — Si excede el límite, eliminar campos menos críticos uno por uno
4. **No incluir datos sensibles** — Nunca enviar emails, tokens, passwords o PII

```typescript
// Ejemplo de sanitización básica
function sanitizeMetadata(data: Record<string, unknown>): string {
  const clean: Record<string, unknown> = {};

  for (const [key, value] of Object.entries(data)) {
    if (value === null || value === undefined) continue;
    if (typeof value === "string") {
      clean[key] = value.replace(/[\x00-\x1f]/g, "").substring(0, 50);
    } else if (typeof value === "number" || typeof value === "boolean") {
      clean[key] = value;
    }
  }

  const json = JSON.stringify(clean);
  return json.length <= 255 ? json : JSON.stringify({});
}
```

---

## 5. Identificación del Visitante (`uuid`)

El campo `uuid` identifica de forma única a un visitante. La implementación de la persistencia depende de tu plataforma.

### Estrategias de persistencia

| Almacenamiento | Duración | Caso de uso |
|----------------|----------|-------------|
| `localStorage` | Permanente (hasta limpieza manual) | Tracking cross-session en web |
| `sessionStorage` | Hasta cerrar el navegador | Tracking de sesión única |
| Cookie de sesión | Hasta cerrar el navegador | Tracking de sesión (compatible SSR) |
| Cookie persistente | Configurable (ej: 30 días) | Balance entre privacidad y retención |
| Base de datos (app móvil) | Permanente | Tracking en apps nativas |

### Generación del UUID

```typescript
function generateUUID(): string {
  // Preferido: API nativa (navegadores modernos)
  if (typeof crypto !== "undefined" && crypto.randomUUID) {
    return crypto.randomUUID();
  }
  // Fallback: generación manual UUID v4
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
    const r = Math.trunc(Math.random() * 16);
    const v = c === "x" ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}
```

### Ejemplo: persistencia en localStorage (web)

```typescript
const STORAGE_KEY = "analytics_visitor_id";

function getOrCreateVisitorId(): string {
  const existing = localStorage.getItem(STORAGE_KEY);
  if (existing) return existing;

  const id = generateUUID();
  localStorage.setItem(STORAGE_KEY, id);
  return id;
}
```

### Ejemplo: persistencia en SharedPreferences (Android/Kotlin)

```kotlin
fun getOrCreateVisitorId(context: Context): String {
    val prefs = context.getSharedPreferences("analytics", Context.MODE_PRIVATE)
    return prefs.getString("visitor_id", null) ?: UUID.randomUUID().toString().also {
        prefs.edit().putString("visitor_id", it).apply()
    }
}
```

---

## 6. Atribución de Campañas (UTM)

La API acepta parámetros UTM como campos de primer nivel, facilitando la atribución de tráfico a campañas específicas.

### Parámetros soportados

| Parámetro | Descripción | Ejemplo |
|-----------|-------------|---------|
| `utm_source` | Origen del tráfico | `google`, `instagram`, `newsletter`, `partner_x` |
| `utm_medium` | Medio o canal | `cpc`, `social`, `email`, `referral`, `organic` |
| `utm_campaign` | Nombre de la campaña | `black_friday_2025`, `launch_v2`, `reengagement` |
| `utm_content` | Variante del creativo | `banner_hero`, `cta_verde`, `video_30s` |
| `utm_term` | Término de búsqueda (SEM) | `zapatos running baratos`, `mejor crm` |
| `a` | Parámetro personalizado | ID de afiliado, subID, código de referido |

### Flujo recomendado de captura y propagación

```
1. El usuario llega a tu sitio con parámetros UTM en la URL:
   https://tu-sitio.com/landing?utm_source=google&utm_medium=cpc&utm_campaign=verano2025

2. Tu aplicación captura los parámetros de la URL al cargar la página.

3. Los almacena en sessionStorage (para persistir durante la navegación interna).

4. Cada evento de analytics incluye automáticamente los UTM almacenados.

5. (Opcional) Los links salientes se enriquecen con los mismos UTM
   para rastrear la conversión downstream.
```

### Ejemplo de captura (JavaScript genérico)

```javascript
function captureUTMParams() {
  const params = new URLSearchParams(window.location.search);
  const utmKeys = ["utm_source", "utm_medium", "utm_campaign", "utm_content", "utm_term", "a"];
  const captured = {};

  for (const key of utmKeys) {
    const value = params.get(key);
    if (value) captured[key] = value;
  }

  if (Object.keys(captured).length > 0) {
    sessionStorage.setItem("utm_params", JSON.stringify(captured));
  }
}

function getStoredUTMParams() {
  try {
    return JSON.parse(sessionStorage.getItem("utm_params") || "{}");
  } catch {
    return {};
  }
}
```

### Ejemplo de propagación a links salientes

```javascript
function appendTrackingParams(url) {
  const params = getStoredUTMParams();
  const urlObj = new URL(url);

  for (const [key, value] of Object.entries(params)) {
    urlObj.searchParams.set(key, value);
  }

  return urlObj.toString();
}

// Uso
const enrichedUrl = appendTrackingParams("https://partner.com/producto");
// → "https://partner.com/producto?utm_source=google&utm_medium=cpc&..."
```

---

## 7. Segmentación por País y Dispositivo

### País (`country`)

El código de país (ISO 3166-1 alpha-2) se puede obtener de diferentes fuentes según tu infraestructura:

| Fuente | Header/Método | Ejemplo |
|--------|---------------|---------|
| Cloudflare | `CF-IPCountry` | `US`, `MX`, `AR` |
| AWS CloudFront | `CloudFront-Viewer-Country` | `US`, `BR` |
| Nginx GeoIP | `X-Country-Code` | `ES`, `CO` |
| API de terceros | MaxMind, ip-api.com | Requiere lookup |
| Fallback | Valor por defecto | `"XX"` (desconocido) |

### Dispositivo (`device`)

Detección básica a partir del User-Agent:

```typescript
function detectDevice(userAgent: string): "mobile" | "tablet" | "desktop" {
  if (/iPad|tablet|playbook|silk/i.test(userAgent)) return "tablet";
  if (/Android|iPhone|iPod|mobile|opera mini|iemobile/i.test(userAgent)) return "mobile";
  return "desktop";
}
```

### Envío desde un servidor proxy o middleware

Si tu aplicación tiene un backend o middleware, puedes enriquecer los eventos con estos datos del lado del servidor antes de enviarlos a la API:

```typescript
// Ejemplo en un middleware Next.js o Express
async function sendEnrichedEvent(event, request) {
  const country = request.headers["cf-ipcountry"] || "XX";
  const device = detectDevice(request.headers["user-agent"] || "");

  await fetch("https://landingmetrics.tech555.dev/log", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ ...event, country, device }),
  });
}
```

---

## 8. Ejemplos de Integración por Plataforma

### 8.1 E-commerce — Tracking de conversiones

```javascript
// Vista de producto
fetch("https://landingmetrics.tech555.dev/log", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    type: "view",
    page: "https://tienda.com/producto/zapatillas-x100",
    uuid: getOrCreateVisitorId(),
    metadata: JSON.stringify({ product_id: 1234, category: "running", price: 89.99 }),
    ...getStoredUTMParams(),
  }),
});

// Click en "Agregar al carrito"
fetch("https://landingmetrics.tech555.dev/log", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    type: "click",
    page: "https://tienda.com/producto/zapatillas-x100",
    uuid: getOrCreateVisitorId(),
    metadata: JSON.stringify({ offer_slug: "zapatillas-x100", action: "add_to_cart", product_id: 1234 }),
    ...getStoredUTMParams(),
  }),
});

// Click en "Comprar" (checkout)
fetch("https://landingmetrics.tech555.dev/log", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    type: "click",
    page: "https://tienda.com/checkout",
    uuid: getOrCreateVisitorId(),
    metadata: JSON.stringify({ offer_slug: "checkout", action: "purchase", total: 245.50 }),
    ...getStoredUTMParams(),
  }),
});
```

**Análisis posible:** Funnel de conversión (vista → add_to_cart → purchase), atribución por campaña UTM, productos más vistos vs más comprados.

### 8.2 SaaS — Engagement de features

```javascript
// Vista de dashboard
sendEvent({ type: "view", page: "/dashboard", metadata: { section: "overview", plan: "pro" } });

// Click en feature específica
sendEvent({ type: "click", page: "/dashboard", metadata: { offer_slug: "export", action: "export_csv", rows: 1500 } });

// Tiempo de uso del editor
sendEvent({ type: "view_time", page: "/editor/doc-123", metadata: { seconds: 340, doc_type: "report" } });

// Scroll en página de pricing
sendEvent({ type: "scroll_depth", page: "/pricing", metadata: { scroll_depth_percent: 75 } });
```

**Análisis posible:** Features más usadas, tiempo promedio en editor, qué secciones del pricing ven los usuarios, correlación plan vs engagement.

### 8.3 Blog / Contenido — Engagement de lectores

```javascript
// Vista de artículo
sendEvent({ type: "view", page: "/blog/guia-seo-2025", metadata: { category: "seo", word_count: 3200 } });

// Tiempo de lectura
sendEvent({ type: "view_time", page: "/blog/guia-seo-2025", metadata: { seconds: 420, category: "seo" } });

// Scroll (¿leyeron hasta el final?)
sendEvent({ type: "scroll_depth", page: "/blog/guia-seo-2025", metadata: { scroll_depth_percent: 100 } });

// Click en CTA dentro del artículo
sendEvent({ type: "click", page: "/blog/guia-seo-2025", metadata: { offer_slug: "signup", action: "cta_signup", position: "mid_article" } });
```

**Análisis posible:** Artículos con mayor engagement, ratio de lectura completa, efectividad de CTAs por posición, contenido que genera conversión.

### 8.4 App Móvil — Eventos via API REST

Desde una app nativa, los eventos se envían directamente al endpoint:

```swift
// Swift (iOS)
func trackEvent(type: String, screen: String, metadata: [String: Any]) {
    let body: [String: Any] = [
        "type": type,
        "page": "myapp://\(screen)",
        "uuid": getStoredVisitorId(),
        "metadata": try! JSONSerialization.data(withJSONObject: metadata),
        "device": "mobile",
        "country": Locale.current.region?.identifier ?? "XX"
    ]

    var request = URLRequest(url: URL(string: "https://landingmetrics.tech555.dev/log")!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    URLSession.shared.dataTask(with: request).resume()
}

// Uso
trackEvent(type: "view", screen: "product_detail", metadata: ["product_id": 1234])
trackEvent(type: "click", screen: "product_detail", metadata: ["offer_slug": "product-1234", "action": "add_to_cart"])
```

```kotlin
// Kotlin (Android)
fun trackEvent(type: String, screen: String, metadata: Map<String, Any>) {
    val body = JSONObject().apply {
        put("type", type)
        put("page", "myapp://$screen")
        put("uuid", getOrCreateVisitorId(context))
        put("metadata", JSONObject(metadata).toString())
        put("device", "mobile")
        put("country", Locale.getDefault().country)
    }

    // Enviar con Retrofit, OkHttp, Ktor, etc.
    analyticsApi.sendEvent(body)
}
```

**Análisis posible:** Pantallas más visitadas, flujos de navegación, engagement por versión de app, comparación iOS vs Android.

### 8.5 Landing Page — Optimización de conversión

```javascript
// Capturar UTM al cargar la landing
captureUTMParams();

// Vista de la landing
sendEvent({ type: "view", page: window.location.href });

// Scroll milestones (¿ven la sección de pricing? ¿los testimonios?)
window.addEventListener("scroll", () => {
  const percent = Math.round((window.scrollY / (document.body.scrollHeight - window.innerHeight)) * 100);
  const milestones = [25, 50, 75, 100];

  for (const m of milestones) {
    if (percent >= m && !trackedMilestones.has(m)) {
      trackedMilestones.add(m);
      sendEvent({ type: "scroll_depth", page: window.location.href, metadata: { scroll_depth_percent: m } });
    }
  }
});

// Click en CTA principal
document.querySelector("#cta-signup").addEventListener("click", () => {
  sendEvent({ type: "click", page: window.location.href, metadata: { offer_slug: "signup", action: "signup_cta", variant: "hero" } });
});

// Tiempo en la landing (al salir)
window.addEventListener("beforeunload", () => {
  sendEvent({ type: "view_time", page: window.location.href, metadata: { seconds: elapsedSeconds } });
});
```

**Análisis posible:** Conversión por campaña UTM, secciones con mayor drop-off, efectividad de variantes de CTA, tiempo promedio antes de conversión.

---

## 9. Integración con Frameworks Web

### 9.1 Patrón general (Vanilla JS)

```javascript
async function sendEvent(event) {
  try {
    await fetch("https://landingmetrics.tech555.dev/log", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        ...event,
        uuid: getOrCreateVisitorId(),
        page: event.page || window.location.href,
        metadata: typeof event.metadata === "object"
          ? JSON.stringify(event.metadata).substring(0, 255)
          : event.metadata,
        ...getStoredUTMParams(),
      }),
    });
  } catch {
    // Nunca interrumpir la experiencia del usuario por analytics
  }
}
```

### 9.2 React / Next.js — Proxy via Server Action

Para evitar exponer el endpoint en el cliente y acceder a headers del servidor:

```typescript
// server-action: analytics.action.ts
"use server";

import { headers } from "next/headers";

export async function sendAnalyticsEvent(event: AnalyticsEvent) {
  const endpoint = process.env.ANALYTICS_LOG_URL;
  if (!endpoint) return;

  const headersList = headers();
  const country = headersList.get("CF-IPCountry") || "XX";
  const device = detectDevice(headersList.get("User-Agent") || "");

  await fetch(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ ...event, country, device }),
  });
}
```

```typescript
// client hook: useAnalytics.ts
"use client";

export function useAnalytics() {
  const visitorId = useVisitorId();
  const utmParams = useUTMParams();

  const trackView = (options) => {
    sendAnalyticsEvent({
      type: "view",
      uuid: visitorId,
      page: options.page || window.location.href,
      metadata: JSON.stringify(options.metadata || {}),
      ...utmParams,
    });
  };

  const trackClick = (options) => { /* similar */ };
  const trackViewTime = (options) => { /* similar */ };
  const trackScrollDepth = (options) => { /* similar */ };

  return { trackView, trackClick, trackViewTime, trackScrollDepth };
}
```

### 9.3 Vue.js — Composable

```typescript
// composables/useAnalytics.ts
export function useAnalytics() {
  const visitorId = useVisitorId();

  function trackEvent(type: string, metadata?: Record<string, unknown>) {
    fetch(import.meta.env.VITE_ANALYTICS_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        type,
        uuid: visitorId.value,
        page: window.location.href,
        metadata: metadata ? JSON.stringify(metadata).substring(0, 255) : undefined,
        ...getStoredUTMParams(),
      }),
    }).catch(() => {});
  }

  return {
    trackView: (meta?) => trackEvent("view", meta),
    trackClick: (meta?) => trackEvent("click", meta),
    trackViewTime: (seconds, meta?) => trackEvent("view_time", { seconds, ...meta }),
    trackScrollDepth: (percent) => trackEvent("scroll_depth", { scroll_depth_percent: percent }),
  };
}
```

### 9.4 Python (Backend / Batch processing)

```python
import requests
import uuid

ANALYTICS_URL = "https://landingmetrics.tech555.dev/log"

def send_event(event_type: str, page: str, metadata: dict = None, visitor_id: str = None):
    try:
        requests.post(ANALYTICS_URL, json={
            "type": event_type,
            "page": page,
            "uuid": visitor_id or str(uuid.uuid4()),
            "metadata": json.dumps(metadata)[:255] if metadata else None,
        }, timeout=5)
    except Exception:
        pass  # Fire-and-forget

# Uso desde un webhook o endpoint
send_event("click", "https://mi-app.com/api/subscribe", {"offer_slug": "subscribe", "action": "email_subscribe", "plan": "free"})
```

---

## 10. Casos de Uso y Análisis Posibles

Con los datos recopilados, se pueden responder preguntas de negocio como:

### Engagement y comportamiento

- **¿Cuánto tiempo pasan los usuarios en cada página?** → `view_time` agrupado por `page`
- **¿Hasta dónde hacen scroll?** → `scroll_depth` con milestones 25/50/75/100
- **¿Cuáles son las páginas más visitadas?** → `view` agrupados por `page`
- **¿Los usuarios que pasan más tiempo convierten más?** → Correlación `view_time` ↔ `click` por `uuid`

### Conversión y funnel

- **¿Cuál es el ratio vista → click?** → `view` vs `click` por `page`
- **¿En qué paso del funnel se pierden los usuarios?** → Secuencia de `click` actions por `uuid`
- **¿Qué CTAs son más efectivos?** → `click` con `action` segmentado por posición o variante
- **¿Qué productos se ven mucho pero no se compran?** → Vistas altas + clicks bajos

### Atribución de campañas

- **¿Qué campaña trae tráfico de mayor calidad?** → UTM + `view_time` y `click`
- **¿Desde qué medio convierten más?** → `utm_medium` + eventos `click` con `action: "purchase"`
- **¿Los afiliados generan valor?** → Segmentar por param `a` y medir conversiones
- **¿Qué creativos funcionan mejor?** → `utm_content` + ratio de conversión

### Segmentación

- **¿De qué países viene el tráfico más valioso?** → `country` + clicks de conversión
- **¿Mobile vs Desktop: diferencias de engagement?** → Segmentar por `device`
- **¿Hay mercados subatendidos con alto potencial?** → `country` + altas vistas, bajos clicks

### Búsqueda y descubrimiento

- **¿Qué buscan los usuarios?** → `click` con `action: "search"` y `term` en metadata
- **¿Qué filtros usan más?** → `click` con `action: "filter"` y categoría en metadata
- **¿La búsqueda mejora la conversión?** → Sesiones con evento de búsqueda vs sin búsqueda

---

## 11. Buenas Prácticas

1. **Siempre incluir `offer_slug` en clicks** — Es el campo más importante del metadata en eventos `click`. Debe responder a la pregunta "¿a qué le dio click el usuario?" (ej: `"like"`, `"share"`, `"search"`, `"checkout"`). Sin él, los datos no se indexan correctamente y se pierden para el análisis.

2. **Fire-and-forget** — Los errores de analytics NUNCA deben afectar la experiencia del usuario. Enviar sin esperar respuesta, silenciar errores.

3. **Sanitizar metadata** — Respetar el límite de 255 chars. Truncar strings, eliminar caracteres de control, no enviar objetos complejos.

4. **No enviar datos sensibles** — Nunca incluir emails, tokens, passwords, tarjetas de crédito ni información personal identificable (PII) en ningún campo.

4. **Limpiar URLs** — Al registrar `page` o URLs en metadata, eliminar query params que contengan tokens o datos sensibles.

5. **Ocultar el endpoint** — Cuando sea posible, usar un proxy server-side (Server Actions, API routes, middleware) para que el endpoint no quede expuesto en el bundle del cliente.

6. **Evitar duplicados** — Implementar guards para que los eventos de vista no se envíen múltiples veces por re-renders o navegaciones SPA. En React: `useRef(false)`; en Vue: flag en `onMounted`.

7. **Usar `action` consistentemente** — Definir una convención de nombres para el campo `action` en metadata de clicks. Junto con `offer_slug`, forma el par clave para identificar qué hizo el usuario y sobre qué recurso.

8. **Capturar UTM al inicio** — Sincronizar los parámetros UTM en el punto de entrada de la aplicación para no perder la atribución en navegaciones internas.

9. **Metadata conciso y estructurado** — Usar campos descriptivos pero cortos. Preferir IDs numéricos sobre strings largos cuando sea posible.

10. **Logging en desarrollo** — Mostrar los eventos en consola durante desarrollo para validar que los datos son correctos antes de llegar a producción.

---

## 12. Configuración

### Variables de entorno

```env
# Endpoint de la API de métricas (obligatorio)
ANALYTICS_LOG_URL=https://landingmetrics.tech555.dev/log

# URL base del sitio (usado para construir URLs completas)
SITE_URL=https://tu-dominio.com
```

Si `ANALYTICS_LOG_URL` no está configurado, los eventos deben ignorarse silenciosamente.

### Ambientes

| Ambiente | Comportamiento recomendado |
|----------|---------------------------|
| Desarrollo | Log en consola (console.table), no enviar al endpoint |
| Staging | Enviar a endpoint de prueba o al mismo con tag en metadata |
| Producción | Envío normal al endpoint |

---

## 13. Resumen de Campos por Evento

| Evento | Campos en metadata | Obligatorios | Ejemplo |
|--------|-------------------|--------------|---------|
| `view` | Identificadores de la página/recurso | Ninguno | `{"product_id":123,"category":"shoes"}` |
| `click` | `offer_slug` + `action` + contexto | **`offer_slug`** | `{"offer_slug":"zapatillas-x100","action":"add_to_cart"}` |
| `event` | `offer_slug` + contexto de la acción | **`offer_slug`** (recomendado) | `{"offer_slug":"message_sent","model":"Modelo123"}` |
| `view_time` | `seconds` / `view_time_seconds` + contexto | Ninguno | `{"seconds":185,"category":"seo"}` |
| `scroll_depth` | `scroll_depth_percent` | Ninguno | `{"scroll_depth_percent":75}` |

### Campos del evento raíz

| Campo | Obligatorio | Todos los eventos | Descripción |
|-------|-------------|-------------------|-------------|
| `type` | Si | Si | Tipo del evento |
| `page` | Recomendado | Si | URL de la página actual |
| `uuid` | Recomendado | Si | ID único del visitante |
| `metadata` | Opcional | Si | JSON con datos de contexto |
| `country` | Opcional | Si | Código ISO del país |
| `device` | Opcional | Si | mobile / desktop / tablet |
| `utm_source` | Opcional | Si | Origen de campaña |
| `utm_medium` | Opcional | Si | Medio de campaña |
| `utm_campaign` | Opcional | Si | Nombre de campaña |
| `utm_content` | Opcional | Si | Variante del creativo |
| `utm_term` | Opcional | Si | Término de búsqueda |
| `a` | Opcional | Si | Parámetro personalizado |
