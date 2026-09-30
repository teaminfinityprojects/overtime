# Guía de Optimización: SEO, Accesibilidad y Performance para Next.js (App Router)

> Instrucciones paso a paso para que un agente AI o desarrollador audite y optimice cualquier proyecto Next.js. Seguir las fases en orden. Cada paso incluye qué buscar, cómo detectar problemas y cómo solucionarlos.

---

## Fase 0: Auditoría inicial

Antes de hacer cambios, analizar el estado actual del proyecto.

### Paso 0.1 — Identificar la estructura del proyecto

```
Buscar:
- Framework: verificar package.json (Next.js, Nuxt, etc.)
- Router: App Router (app/) o Pages Router (pages/)
- i18n: cómo se manejan los idiomas (archivos JSON, librería, etc.)
- Styling: Tailwind, CSS Modules, styled-components
- Config: next.config.ts o next.config.js
```

### Paso 0.2 — Correr Lighthouse

```
Ejecutar Lighthouse en modo móvil sobre la página principal.
Guardar el JSON del reporte para referencia.
Anotar los scores iniciales: Performance, Accessibility, SEO, Best Practices.
```

### Paso 0.3 — Identificar páginas existentes

```
Listar todas las rutas del proyecto:
- Páginas estáticas vs dinámicas
- Verificar si existen: /about, /contact, /privacy, /terms
- Verificar sitemap.ts y robots.ts
```

---

## Fase 1: Páginas de confianza (Impacto en Google Ads Quality Score)

Google Ads evalúa la "Landing Page Experience". Sin estas páginas, el Quality Score baja.

### Paso 1.1 — Crear las páginas faltantes

Verificar si existen y crear las que falten:

| Ruta | Contenido | Prioridad |
|------|-----------|-----------|
| `/about` | Quiénes somos, qué hacemos, transparencia | Alta |
| `/contact` | Email de contacto, partnerships | Alta |
| `/privacy` | Política de privacidad completa (cookies, datos, terceros) | Alta |
| `/terms` | Términos de servicio (responsabilidad, garantías, uso) | Media |

Cada página debe incluir:
- `generateMetadata()` con title, description, alternates, openGraph
- Breadcrumb navigation + JSON-LD BreadcrumbList
- Logo con link al home
- Footer con links a las demás páginas de confianza
- Soporte i18n si el proyecto es multi-idioma

### Paso 1.2 — Actualizar el Footer

```
Buscar: el componente Footer del proyecto.
Acción: añadir links de navegación a About, Privacy, Terms, Contact.
Si el proyecto es multi-idioma, los labels deben estar traducidos.
```

### Paso 1.3 — Actualizar el Sitemap

```
Buscar: app/sitemap.ts o pages/sitemap.xml
Acción: incluir las nuevas páginas con:
  - changeFrequency: 'monthly'
  - priority: 0.5
  - alternates por idioma si aplica
```

### Paso 1.4 — Pasar lang al Footer (si es multi-idioma)

```
Buscar: todas las invocaciones del Footer en el proyecto.
Acción: asegurarse de que recibe el idioma actual para renderizar
los links en el idioma correcto.
```

---

## Fase 2: SEO técnico

### Paso 2.1 — Verificar metadata única por página

```
Buscar: generateMetadata() en cada page.tsx
Problema: todas las páginas usan las mismas keywords/description genéricas.
Acción: personalizar por tipo de página:

- Home: keywords genéricas del negocio
- Listados: keywords con tipos de contenido + nombres de entidades
- Detalle: keywords con nombre específico + variaciones
  Ejemplo: "[nombre] free tokens, [nombre] promo code, [nombre] bonus"
- Categoría/Plataforma: "[categoría] + términos relevantes"
```

### Paso 2.1b — Verificar meta robots y lang

```
Buscar: <meta name="robots"> y atributo lang en <html>
Cada página debe tener:
  - <meta name="robots" content="index, follow"> (o las directivas correctas)
  - <html lang="xx"> con el código de idioma correcto (es, en, etc.)

En Next.js App Router, el lang se configura en el layout raíz:
  export default function RootLayout({ children, params }) {
    return <html lang={params.lang}>{children}</html>
  }

robots se configura en generateMetadata():
  robots: { index: true, follow: true }
```

### Paso 2.2 — Verificar URL canónica sin parámetros de tracking

```
Regla crítica: la URL canónica NUNCA debe incluir parámetros UTM, a=, gclid,
fbclid ni ningún parámetro de tracking. Estos parámetros son para analytics,
no deben indexarse.

Buscar: canonical en generateMetadata() y en <link rel="canonical">
Verificar:
  - canonical apunta a la URL limpia (solo dominio + ruta)
  - og:url también es la URL canónica limpia
  - NO incluir ?utm_source=, ?a=, ?gclid=, etc.

Correcto:   canonical: `${baseUrl}/${lang}/ruta`
Incorrecto: canonical: `${baseUrl}/${lang}/ruta?utm_medium=freetokens&a=XXX`

En Next.js, si la página recibe params de tracking via searchParams,
NO incluirlos en el canonical.
```

### Paso 2.4 — Verificar hreflang (proyectos multi-idioma)

```
Buscar: alternates.languages en generateMetadata()
Cada página debe tener:
  - Una entrada por cada idioma soportado
  - Una entrada x-default
  - canonical apuntando a la URL actual (SIN parámetros UTM)
```

### Paso 2.5 — Implementar JSON-LD schemas

```
Verificar qué schemas existen y añadir los faltantes.
Schemas recomendados por tipo de página:

| Tipo de página | Schemas |
|----------------|---------|
| Todas | BreadcrumbList |
| Home | WebSite, Organization, ItemList |
| Listado | CollectionPage, ItemList |
| Detalle | Product/Offer/Article (según el contenido) |
| FAQ | FAQPage |

Implementación:
<script type="application/ld+json"
  dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
/>
```

### Paso 2.6 — Verificar sitemap completo

```
Buscar: app/sitemap.ts
Verificar que incluye:
  - Todas las páginas estáticas
  - Todas las páginas dinámicas generadas
  - alternates por idioma
  - Prioridades correctas (home=1.0, contenido=0.8, legal=0.5)
  - Las URLs NO incluyen parámetros UTM
```

### Paso 2.7 — Verificar anchor text de links internos

```
Buscar: todos los <Link> y <a> que apuntan a páginas internas.
Problema: texto de enlace genérico ("haz clic aquí", "ver más", "aquí").
Acción: reemplazar con texto descriptivo que indique el destino:
  - Incorrecto: <Link href="/about">Haz clic aquí</Link>
  - Correcto:   <Link href="/about">Sobre nosotros</Link>
  - Incorrecto: <a href="/privacy">Ver política</a>
  - Correcto:   <a href="/privacy">Política de privacidad</a>
```

### Paso 2.8 — Señales de confianza adicionales

```
Buscar: oportunidades para añadir señales de confianza.
Acciones:
  - Mostrar fecha de actualización del contenido
  - Mostrar contadores ("X ofertas activas verificadas")
  - Incluir reviews/ratings con schema markup
```

---

## Fase 3: Accesibilidad

### Paso 3.1 — Auditar alt texts de imágenes

```
Buscar: todos los alt= en archivos .tsx
Problemas comunes:
  - alt="" vacío en imágenes con contenido
  - alt="Photo 1", alt="Image", alt="Hero" (genéricos)
  - alt con solo el slug (alt="sugarcams")

Acción: reemplazar con alts descriptivos:
  - Logos: "[nombre] logo"
  - Screenshots: "[nombre] platform interface screenshot [N]"
  - Hero: descripción del contenido visual
  - Decorativas: alt="" (solo si realmente son decorativas)
```

### Paso 3.2 — Verificar width/height en todas las imágenes

```
Buscar: <img sin width o height explícitos.
Problema: causa CLS (Cumulative Layout Shift) y falla en Lighthouse.
Acción: añadir width y height a TODAS las <img>, incluyendo SVGs.

Para next/image: width y height son obligatorios (ya los pide).
Para <img> nativas: añadirlos manualmente.
```

### Paso 3.3 — Auditar aria-labels (proyectos multi-idioma)

```
Buscar: aria-label=" en archivos .tsx
Problema: aria-labels hardcodeados en un solo idioma.
Acción: traducirlos con ternarios o sistema de traducciones.

Antes: aria-label="Anterior"
Después: aria-label={lang === "es" ? "Anterior" : "Previous"}
```

### Paso 3.4 — Buscar idiomas mixtos

```
Buscar: texto hardcodeado en .tsx que debería estar traducido.
Patrones a buscar:
  1. Strings en español sin ternario lang en archivos de páginas EN
  2. Strings en inglés que contienen palabras en español
  3. aria-labels en un solo idioma

Acción: usar traducciones del sistema i18n o ternarios lang.
```

### Paso 3.5 — Verificar semántica HTML

```
Verificar:
  - Solo un <h1> por página
  - Jerarquía de headings correcta (h1 > h2 > h3)
  - Breadcrumbs dentro de <nav>
  - Botones interactivos con aria-expanded, aria-controls
  - FAQ con itemScope/itemType/itemProp de schema.org
```

---

## Fase 4: Performance

### Paso 4.1 — Optimizar carga de fuentes

```
Buscar: import de fuentes en layout.tsx (Inter, Roboto, etc.)
Problema: cargar todos los pesos de fuente (~500KB).

Acción:
  1. Buscar qué font-weights se usan realmente:
     grep -r "font-thin|font-light|font-normal|font-medium|font-semibold|font-bold|font-extrabold|font-black"
  2. Mapear a pesos numéricos:
     thin=100, light=300, normal=400, medium=500, semibold=600, bold=700, extrabold=800, black=900
  3. Limitar el array weight a solo los usados.
```

### Paso 4.2 — Optimizar LCP image

```
Buscar: la imagen más grande visible en el viewport inicial (above-the-fold).
Esto es el LCP (Largest Contentful Paint).

Acción:
  - Usar <Image> de next/image (no <img>)
  - Añadir prop priority (NO fetchPriority="high")
  - Añadir sizes restrictivo: sizes="(max-width: 768px) [mobile]px, [desktop]px"
  - Formato WebP o AVIF
  - NO usar loading="lazy" en LCP (Next.js lo añade si no se pone priority)
```

### Paso 4.3 — Optimizar todas las imágenes

```
Buscar: todas las <Image> y <img> del proyecto.

Reglas:
  - Above-the-fold: priority, sin lazy
  - Below-the-fold: loading="lazy"
  - Logo con sizes="[tamaño-renderizado]px" (evita que Next.js pida 3840px)
  - SVGs: usar <img> con width/height, no next/image
  - Verificar que sizes coincida con el tamaño real renderizado
```

### Paso 4.4 — Diferir scripts de terceros

```
Buscar: <Script> o <script> en layout.tsx y páginas.
Clasificar cada script:

| Tipo | Strategy | Ejemplos |
|------|----------|----------|
| Analytics/Tracking | lazyOnload | GTM, Google Analytics, Contentsquare, Hotjar |
| Funcionalidad UI | afterInteractive | Chat widgets, A/B testing |
| Crítico | beforeInteractive | Polyfills (raro en Next.js moderno) |

Acción: cambiar strategy de scripts de analytics a "lazyOnload".
```

### Paso 4.5 — Tree-shaking de librerías de iconos

```
Buscar en package.json: @tabler/icons-react, lucide-react, react-icons, @heroicons/react
Problema: estas librerías exportan miles de iconos, webpack los incluye todos.

Acción: añadir a next.config.ts:
  experimental: {
    optimizePackageImports: ['@tabler/icons-react', 'lucide-react'],
  }
```

### Paso 4.6 — Revisar next.config.ts

```
Verificar que tenga estas opciones:

const nextConfig: NextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  experimental: {
    optimizePackageImports: ['[librerías de iconos usadas]'],
  },
};
```

### Paso 4.7 — Analizar reporte Lighthouse

```
Si se tiene un reporte Lighthouse JSON, extraer:

1. Scores generales: Performance, Accessibility, SEO
2. Métricas core: FCP, LCP, TBT, CLS, TTI, Speed Index
3. Auditorías fallidas (score < 0.9):
   - unsized-images: imágenes sin width/height
   - unused-javascript: JS no utilizado (terceros vs propio)
   - render-blocking-resources: recursos que bloquean render
   - image-delivery: imágenes que podrían ser más pequeñas
   - lcp-discovery: si el LCP element se descubre tarde
4. Identificar qué es controlable (código propio) vs no controlable (terceros)
```

---

## Fase 5: Verificación final

### Paso 5.1 — Build sin errores

```
Ejecutar: npx next build
Verificar: 0 errores, 0 warnings relevantes.
Verificar: las nuevas páginas aparecen en el output de rutas.
```

### Paso 5.2 — Checklist final

```
SEO:
  [ ] Cada página tiene title, description y keywords únicos
  [ ] <meta name="robots"> presente en todas las páginas
  [ ] <html lang="xx"> con el idioma correcto
  [ ] URL canónica SIN parámetros UTM/tracking (utm_*, a=, gclid, fbclid)
  [ ] og:url también es URL canónica sin UTMs
  [ ] Open Graph completo (og:title, og:description, og:image 1200x630, og:url, og:type)
  [ ] Hreflang configurado (si multi-idioma)
  [ ] JSON-LD schemas en todas las páginas
  [ ] Sitemap incluye todas las páginas (URLs sin UTMs)
  [ ] Páginas de confianza existen (about, privacy, terms, contact)
  [ ] Footer tiene links a páginas de confianza
  [ ] Links internos con anchor text descriptivo (no "clic aquí" ni "ver más")
  [ ] Fecha de actualización visible

Accesibilidad:
  [ ] Todas las imágenes tienen alt descriptivo
  [ ] Todas las imágenes tienen width y height
  [ ] Aria-labels traducidos (si multi-idioma)
  [ ] No hay idiomas mixtos en ninguna página
  [ ] Solo un h1 por página
  [ ] Jerarquía de headings correcta (h1 > h2 > h3)
  [ ] Breadcrumbs con <nav>

Performance:
  [ ] Font weights limitados a los usados
  [ ] LCP image usa priority + sizes
  [ ] Logo usa sizes restrictivo
  [ ] Imágenes below-the-fold usan loading="lazy"
  [ ] Scripts analytics usan strategy="lazyOnload"
  [ ] optimizePackageImports configurado para icon libraries
  [ ] poweredByHeader: false
```

### Paso 5.3 — Re-run Lighthouse

```
Ejecutar Lighthouse móvil de nuevo.
Comparar scores antes vs después.
Targets mínimos:
  - Performance: > 90
  - Accessibility: 100
  - SEO: 100
  - Best Practices: > 95

Si Performance < 90, revisar:
  1. TBT alto → scripts de terceros (no controlable) o JS propio pesado
  2. LCP alto → imagen principal no optimizada o descubierta tarde
  3. CLS alto → imágenes sin dimensiones o contenido que salta
```

---

## Referencia rápida de patrones

### Metadata por página (Next.js App Router)

```tsx
export async function generateMetadata({ params }): Promise<Metadata> {
  const { lang } = await params;
  const baseUrl = process.env.BASE_URL || "https://example.com";
  return {
    title: "Título único",
    description: "Descripción única",
    keywords: "keywords, específicas, de esta página",
    alternates: {
      canonical: `/${lang}/ruta`,
      languages: {
        es: `${baseUrl}/es/ruta`,
        en: `${baseUrl}/en/ruta`,
        "x-default": `${baseUrl}/${lang}/ruta`,
      },
    },
    openGraph: {
      title, description,
      type: "website",
      url: `${baseUrl}/${lang}/ruta`, // IMPORTANTE: URL canónica SIN parámetros UTM/tracking
      siteName: "Nombre del sitio",
      locale: lang === "es" ? "es_ES" : "en_US",
      images: [{ url: `${baseUrl}/og.jpg`, width: 1200, height: 630 }],
    },
    robots: { index: true, follow: true },
    twitter: {
      card: "summary_large_image",
      title, description,
      images: [{ url: `${baseUrl}/og.jpg`, width: 1200, height: 630 }],
    },
  };
}
```

### Imagen LCP optimizada

```tsx
<Image
  src="/hero.webp"
  alt="Descripción del contenido visual"
  width={400}
  height={250}
  priority
  sizes="(max-width: 768px) 100vw, 400px"
/>
```

### Imagen below-the-fold

```tsx
<img
  src="/icon.svg"
  alt="nombre logo"
  width={120}
  height={48}
  loading="lazy"
/>
```

### Script de terceros diferido

```tsx
<Script id="analytics" strategy="lazyOnload" src="https://..." />
```

### Página legal template

```tsx
export default async function LegalPage({ params }) {
  const { lang } = await params;
  const translations = await getTranslations(lang);
  const baseUrl = process.env.BASE_URL;

  const breadcrumbJsonLd = {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: [
      { "@type": "ListItem", position: 1, name: "Home", item: `${baseUrl}/${lang}` },
      { "@type": "ListItem", position: 2, name: translations.page.title, item: `${baseUrl}/${lang}/ruta` },
    ],
  };

  return (
    <>
      <script type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumbJsonLd) }} />
      <main>
        <nav> {/* Breadcrumb */} </nav>
        <h1>{translations.page.heading}</h1>
        <p>{translations.page.lastUpdated}</p>
        {translations.page.sections.map((section, i) => (
          <section key={i}>
            <h2>{section.title}</h2>
            <p>{section.content}</p>
          </section>
        ))}
      </main>
      <Footer {...translations.footer} lang={lang} />
    </>
  );
}
```
