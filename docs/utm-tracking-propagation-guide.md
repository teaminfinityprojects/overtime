# UTM & Tracking Params Propagation

Guia reutilizable para implementar propagacion de parametros UTM y tracking en cualquier proyecto web.

## Concepto

Cuando un usuario llega al sitio con parametros UTM (o el parametro `a=`), estos se guardan en `sessionStorage` y se propagan automaticamente a todos los links de salida durante la sesion del usuario.

## Parametros soportados

| Parametro      | Ejemplo                        | Descripcion                      | Obligatorio |
| -------------- | ------------------------------ | -------------------------------- | ----------- |
| `utm_medium`   | `?utm_medium=freetokens`       | Identificador de la landing      | ✅ SI       |
| `a`            | `?a=DKEPRJDCSSI`               | ID de afiliado / tracking        | ✅ SI       |
| `utm_campaign` | `?utm_campaign=exoclick-marzo` | Nombre de la campana publicitaria | ✅ SI      |
| `utm_source`   | `?utm_source=google`           | Origen del trafico               | Opcional    |
| `utm_content`  | `?utm_content=banner_top`      | Variante del contenido           | Opcional    |
| `utm_term`     | `?utm_term=shoes`              | Termino de busqueda              | Opcional    |
| `gclid`        | `?gclid=...`                   | Google Click ID (auto-tagging)   | Auto        |
| `fbclid`       | `?fbclid=...`                  | Facebook Click ID                | Auto        |

> **Regla critica**: TODOS los parametros que lleguen en la URL inicial deben propagarse a traves de toda la navegacion, sin importar cuales sean o que valores tengan. Los parametros `a` y `utm_campaign` son dinamicos y definidos por el equipo de publicidad — no validar contra listas fijas.

## Arquitectura

```
URL con params → useUtmParams() → sessionStorage → appendTrackingParams(url)
                     ↑                                      ↓
              sync on navigation                    links de salida con params
```

### 1. Storage

El sistema requiere **tres capas de almacenamiento** para garantizar persistencia:

| Capa | Duracion | Proposito |
|---|---|---|
| **Cookies** (primaria) | 30 dias | Persistencia cross-session — sobrevive al cerrar el navegador |
| **localStorage** (respaldo) | Permanente | Backup si cookies no disponibles |
| **sessionStorage** (cache rapido) | Sesion activa | Acceso rapido en la sesion actual |

- **Key**: `myapp_utm_params` (cambiar por proyecto, ej: `freetokens_utm_params`)
- **Formato**: JSON con los parametros presentes
- **Merge**: nuevos params del URL sobreescriben los guardados, los no presentes se preservan
- **Prioridad de lectura**: sessionStorage → localStorage → cookies

> La implementacion minima usando solo `sessionStorage` es valida para sitios de sesion unica, pero no cumple el requisito de persistencia de 30 dias para tracking de afiliados.

### 2. Sync Hook (`useUtmParams`)

```tsx
"use client";

import { useEffect, useState } from "react";
import { usePathname, useSearchParams } from "next/navigation";

const STORAGE_KEY = "myapp_utm_params";
const UTM_KEYS = ["utm_source", "utm_medium", "utm_campaign", "utm_content", "utm_term"];
const EXTRA_KEYS = ["a", "gclid", "fbclid"]; // gclid y fbclid son automaticos de Google/Facebook Ads

function parseSearchParams(search: string) {
  const params = new URLSearchParams(search);
  const result: Record<string, string> = {};
  for (const key of [...UTM_KEYS, ...EXTRA_KEYS]) {
    const value = params.get(key);
    if (value) result[key] = value;
  }
  return result;
}

function readFromStorage(): Record<string, string> {
  try {
    const raw = sessionStorage.getItem(STORAGE_KEY);
    return raw ? JSON.parse(raw) : {};
  } catch {
    return {};
  }
}

function writeToStorage(params: Record<string, string>) {
  try {
    if (Object.keys(params).length === 0) {
      sessionStorage.removeItem(STORAGE_KEY);
    } else {
      sessionStorage.setItem(STORAGE_KEY, JSON.stringify(params));
    }
  } catch {}
}

function syncFromUrl(): Record<string, string> {
  if (typeof window === "undefined") return readFromStorage();
  const fromUrl = parseSearchParams(window.location.search);
  if (Object.keys(fromUrl).length > 0) {
    const merged = { ...readFromStorage(), ...fromUrl };
    writeToStorage(merged);
    return merged;
  }
  return readFromStorage();
}

export function useUtmParams() {
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const [params, setParams] = useState(() =>
    typeof window !== "undefined" ? syncFromUrl() : {}
  );

  useEffect(() => {
    setParams(syncFromUrl());
  }, [pathname, searchParams]);

  return params;
}
```

### 3. Componente de Sync (root layout)

```tsx
"use client";
import { useUtmParams } from "../hooks/use-utm-params";

export function UtmSync() {
  useUtmParams();
  return null;
}
```

Incluir en el layout raiz envuelto en `<Suspense>`:

```tsx
<Suspense fallback={null}>
  <UtmSync />
</Suspense>
```

### 4. Funcion de propagacion (`appendTrackingParams`)

```tsx
export function appendTrackingParams(url: string): string {
  const params = readFromStorage();
  if (Object.keys(params).length === 0) return url;

  try {
    const parsed = new URL(url, "https://placeholder.invalid");
    const isAbsolute = /^https?:\/\//.test(url);

    for (const [key, value] of Object.entries(params)) {
      if (value && !parsed.searchParams.has(key)) {
        parsed.searchParams.set(key, value);
      }
    }

    return isAbsolute
      ? parsed.toString()
      : `${parsed.pathname}${parsed.search}${parsed.hash}`;
  } catch {
    return url;
  }
}
```

### 5. Uso en componentes

#### Links con `<a>` o `<Link>`

```tsx
import { appendTrackingParams } from "@/features/analytics";

// Next.js Link
<Link href={appendTrackingParams(externalUrl)} target="_blank">...</Link>

// Anchor HTML
<a href={appendTrackingParams(externalUrl)} target="_blank">...</a>
```

#### `window.open`

```tsx
window.open(appendTrackingParams(url), "_blank");
```

#### Fuera de React (sin hooks)

```tsx
import { getStoredTrackingParams } from "@/features/analytics";

const params = getStoredTrackingParams();
```

### 6. Propagacion en Formularios

Todos los formularios deben incluir campos ocultos con los parametros de tracking para que lleguen al backend en el submit.

```tsx
import { readFromStorage } from "@/features/analytics";

export function TrackingHiddenFields() {
  const params = readFromStorage();
  return (
    <>
      {Object.entries(params).map(([key, value]) => (
        <input key={key} type="hidden" name={key} value={value} />
      ))}
    </>
  );
}

// Uso en cualquier formulario:
<form action="/api/register" method="POST">
  <TrackingHiddenFields />
  {/* resto del formulario */}
</form>
```

### 7. Propagacion en Redirecciones

Cualquier redireccion debe mantener los parametros:

```tsx
// Redireccion JavaScript
import { appendTrackingParams } from "@/features/analytics";

// window.location
window.location.href = appendTrackingParams("/nueva-pagina");

// router.push (Next.js)
router.push(appendTrackingParams("/nueva-pagina"));

// window.open
window.open(appendTrackingParams(externalUrl), "_blank");
```

Para redirecciones del servidor (Next.js middleware o API routes), recuperar los params de la cookie/query string y añadirlos al destino.

### 8. Integracion GTM / DataLayer

Enviar los parametros al dataLayer en cada pagina para que Google Tag Manager pueda usarlos en triggers y variables:

```tsx
"use client";
import { useEffect } from "react";
import { readFromStorage } from "@/features/analytics";

export function GtmTrackingPush() {
  useEffect(() => {
    const params = readFromStorage();
    if (Object.keys(params).length > 0 && window.dataLayer) {
      window.dataLayer.push({
        event: "tracking_params_ready",
        affiliate_id: params.a || null,
        utm_medium: params.utm_medium || null,
        utm_campaign: params.utm_campaign || null,
        utm_source: params.utm_source || null,
      });
    }
  }, []);
  return null;
}
```

En GTM configurar:
- Variables que lean `a`, `utm_medium`, `utm_campaign` del dataLayer
- Trigger en `tracking_params_ready`
- Los eventos de conversion deben incluir el `affiliate_id`

## Comportamiento

| Escenario | Resultado |
|---|---|
| Usuario llega con `?utm_source=google&a=123` | Se guardan ambos en sessionStorage |
| Navega internamente con params | Params se mantienen en sessionStorage |
| Click en link externo | URL se envia con `?utm_source=google&a=123` |
| Llega nueva URL con `?utm_source=facebook` | `utm_source` se actualiza, `a=123` se preserva |
| Link externo ya tiene `?utm_source=bing` | No se sobreescribe (el param existente gana) |
| Cierra tab y abre nueva | sessionStorage se limpia, params se pierden |

## Checklist de implementacion para nuevo proyecto

### Captura y Storage
1. Crear el tipo `UtmParams` con los campos UTM + extras (`a`, `gclid`, `fbclid`)
2. Crear el hook `useUtmParams` con sync a sessionStorage (+ cookies 30 dias + localStorage si se requiere persistencia cross-session)
3. Crear el componente `UtmSync` y agregarlo al root layout (dentro de `<Suspense>`)
4. Cambiar el `STORAGE_KEY` al nombre del proyecto (`[proyecto]_utm_params`)

### Propagacion
5. Crear la funcion `appendTrackingParams`
6. Envolver todos los links externos con `appendTrackingParams(url)`
7. Envolver todas las llamadas `window.open` con `appendTrackingParams(url)`
8. Anadir `<TrackingHiddenFields />` en TODOS los formularios
9. Usar `appendTrackingParams` en todas las redirecciones JavaScript
10. Verificar que redirecciones del servidor preservan params

### GTM / Analytics
11. Implementar `GtmTrackingPush` en el layout si se usa GTM
12. Configurar variables en GTM para `a`, `utm_medium`, `utm_campaign`
13. Eventos de conversion deben incluir `affiliate_id`

### Testing obligatorio

| Test | Pasos | Resultado esperado |
|---|---|---|
| Propagacion basica | Entrar con URL completa → navegar a otra pagina | URL o storage mantienen todos los params |
| Valores dinamicos | Entrar con `a=PRUEBA123` → navegar | `a=PRUEBA123` se mantiene exacto |
| Links externos | Entrar con params → hacer click en link externo | URL externa incluye todos los params |
| Formularios | Entrar con params → inspeccionar formulario | Campos hidden presentes con valores correctos |
| Persistencia | Entrar con params → cerrar tab → abrir nueva (si usa cookies) | Params disponibles en nueva sesion |
| gclid | Entrar con `?gclid=abc123` → navegar | gclid se propaga correctamente |

## Agregar nuevos parametros custom

Agregar el nombre del parametro al array `EXTRA_KEYS` y al tipo `UtmParams`:

```tsx
const EXTRA_KEYS = ["a", "ref", "partner_id"]; // agregar aqui
```
