// Landing Metrics + UTMs para el export web (skill infinity:metrics, portado de tracking.ts y analytics.ts).
// Lo carga la pantalla de carga (web/shell.html) antes que el motor; si falta, lo inyecta
// scripts/autoload/metrics.gd con JavaScriptBridge. Expone window.overtimeMetrics.
// Todos los envíos son fire-and-forget: nunca bloquean ni rompen el juego.
(function () {
	if (window.overtimeMetrics) return;

	const PROJECT = 'overtime';
	const STORAGE_KEY = `${PROJECT}_utm_params`;
	const META_STORAGE_KEY = `${PROJECT}_log_meta`;
	const VISITOR_KEY = `${PROJECT}_visitor_id`;
	const COOKIE_DAYS = 30;
	// `a` es el id de afiliado; gclid/fbclid los añaden Google y Meta solos.
	const ALL_KEYS = ['utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'utm_term', 'a', 'gclid', 'fbclid', 'conversion'];
	// `cost` y `country` van aparte: viajan en el payload (cost solo en `view`), no en los enlaces.
	const META_KEYS = ['cost', 'country'];
	// El panel atribuye cada click de salida a su plataforma por este prefijo del offer_slug.
	const DESTINATION_PREFIX_RE = /^(amateur|sugarcams):/i;

	let logUrl = 'https://landingmetrics.tech555.app/log';
	// En local no se envía nada (solo consola), igual que en builds de depuración.
	let dev = ['localhost', '127.0.0.1', ''].includes(window.location.hostname);
	let started = false;
	let viewSent = false;

	// --- Tracking params (3 capas: sessionStorage → localStorage → cookie) ---------------

	function readCookie(key) {
		try {
			const match = document.cookie.split('; ').find((c) => c.startsWith(`${key}=`));
			return match ? JSON.parse(decodeURIComponent(match.slice(key.length + 1))) : {};
		} catch {
			return {};
		}
	}

	function writeCookie(key, params) {
		try {
			const expires = new Date(Date.now() + COOKIE_DAYS * 24 * 60 * 60 * 1000).toUTCString();
			document.cookie = `${key}=${encodeURIComponent(JSON.stringify(params))}; expires=${expires}; path=/; SameSite=Lax`;
		} catch {
			/* fire-and-forget */
		}
	}

	function readStore(store, key) {
		try {
			const raw = store.getItem(key);
			return raw ? JSON.parse(raw) : {};
		} catch {
			return {};
		}
	}

	function readAnyLayer(key) {
		const session = readStore(sessionStorage, key);
		if (Object.keys(session).length > 0) return session;
		const local = readStore(localStorage, key);
		if (Object.keys(local).length > 0) return local;
		return readCookie(key);
	}

	function persist(key, params) {
		const json = JSON.stringify(params);
		try {
			sessionStorage.setItem(key, json);
		} catch {
			/* storage bloqueado (modo privado): seguimos con las otras capas */
		}
		try {
			localStorage.setItem(key, json);
		} catch {
			/* idem */
		}
		writeCookie(key, params);
	}

	const getStoredTrackingParams = () => readAnyLayer(STORAGE_KEY);
	const getStoredLogMeta = () => readAnyLayer(META_STORAGE_KEY);

	/** Captura los params de la URL y los mezcla con los guardados (los nuevos ganan, los ausentes se conservan). */
	function syncTrackingParams() {
		const search = new URLSearchParams(window.location.search);
		const fromUrl = {};
		for (const key of ALL_KEYS) {
			const value = search.get(key);
			if (value) fromUrl[key] = value.slice(0, 200);
		}
		const metaFromUrl = {};
		for (const key of META_KEYS) {
			const value = search.get(key);
			if (value) metaFromUrl[key] = value.slice(0, 60);
		}
		if (Object.keys(metaFromUrl).length > 0) persist(META_STORAGE_KEY, { ...getStoredLogMeta(), ...metaFromUrl });
		if (Object.keys(fromUrl).length > 0) persist(STORAGE_KEY, { ...getStoredTrackingParams(), ...fromUrl });
	}

	/** Añade params a una URL sin sobrescribir los que ya trae. */
	function appendParams(url, params) {
		try {
			const parsed = new URL(url, 'https://placeholder.invalid');
			const isAbsolute = /^https?:\/\//.test(url);
			for (const [key, value] of Object.entries(params)) {
				if (value && !parsed.searchParams.has(key)) parsed.searchParams.set(key, value);
			}
			return isAbsolute ? parsed.toString() : `${parsed.pathname}${parsed.search}${parsed.hash}`;
		} catch {
			return url;
		}
	}

	/**
	 * Enlace de salida: primero los params del visitante (ganan siempre), luego los del juego
	 * (`defaults`, solo si faltan) y, sin utm_source, el dominio actual.
	 */
	function outboundUrl(url, defaults) {
		const params = { ...getStoredTrackingParams() };
		for (const [key, value] of Object.entries(defaults || {})) {
			if (value && !params[key]) params[key] = String(value);
		}
		if (!params.utm_source) params.utm_source = window.location.hostname;
		return appendParams(url, params);
	}

	// --- Landing Metrics ------------------------------------------------------------------

	function generateUUID() {
		if (typeof crypto !== 'undefined' && crypto.randomUUID) return crypto.randomUUID();
		return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
			const r = Math.trunc(Math.random() * 16);
			const v = c === 'x' ? r : (r & 0x3) | 0x8;
			return v.toString(16);
		});
	}

	function getOrCreateVisitorId() {
		try {
			const existing = localStorage.getItem(VISITOR_KEY);
			if (existing) return existing;
			const id = generateUUID();
			localStorage.setItem(VISITOR_KEY, id);
			return id;
		} catch {
			return generateUUID();
		}
	}

	function detectDevice() {
		const ua = navigator.userAgent;
		if (/iPad|tablet|playbook|silk/i.test(ua)) return 'tablet';
		if (/Android|iPhone|iPod|mobile|opera mini|iemobile/i.test(ua)) return 'mobile';
		return 'desktop';
	}

	/** Metadata ≤ 255 chars: strings a 50, sin caracteres de control; si aun así excede, {}. */
	function sanitizeMetadata(data) {
		const clean = {};
		for (const [key, value] of Object.entries(data)) {
			if (value === null || value === undefined) continue;
			if (typeof value === 'string') {
				// eslint-disable-next-line no-control-regex
				clean[key] = value.replace(/[\x00-\x1f]/g, '').substring(0, 50);
			} else if (typeof value === 'number' || typeof value === 'boolean') {
				clean[key] = value;
			}
		}
		const json = JSON.stringify(clean);
		return json.length <= 255 ? json : '{}';
	}

	function cleanPageUrl() {
		try {
			const url = new URL(window.location.href);
			return `${url.origin}${url.pathname}`.slice(0, 2000);
		} catch {
			return window.location.href.slice(0, 2000);
		}
	}

	function sendEvent(type, metadata) {
		const meta = getStoredLogMeta();
		const merged = { ...(metadata || {}) };
		const cost = meta.cost !== undefined ? Number(meta.cost) : undefined;
		if (type === 'view' && cost !== undefined && Number.isFinite(cost)) merged.cost = cost;
		if (meta.country) merged.country = meta.country;
		const payload = {
			type,
			page: cleanPageUrl(),
			uuid: getOrCreateVisitorId(),
			metadata: sanitizeMetadata(merged),
			device: detectDevice(),
			...(meta.country ? { country: meta.country } : {}),
			...getStoredTrackingParams(),
		};
		if (dev) {
			console.log('[analytics]', payload);
			return;
		}
		try {
			// No sendBeacon: manda cookies y el backend responde ACAO "*", que CORS prohíbe con credenciales.
			fetch(logUrl, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify(payload),
				credentials: 'omit',
				keepalive: true,
			}).catch(() => {});
		} catch {
			/* nunca interrumpir el juego por analytics */
		}
	}

	/** Tiempo de permanencia al ocultar/cerrar la pestaña, descontando el tiempo oculto. */
	function trackViewTime() {
		const startedAt = performance.timeOrigin || Date.now();
		let hiddenAt = 0;
		let hiddenTotal = 0;
		let sent = false;
		const send = () => {
			if (sent) return;
			sent = true;
			if (document.hidden && hiddenAt) hiddenTotal += Date.now() - hiddenAt;
			// El backend lee `view_time_seconds` (con `seconds` llega a 0).
			sendEvent('view_time', {
				view_time_seconds: Math.max(0, Math.round((Date.now() - startedAt - hiddenTotal) / 1000)),
			});
		};
		document.addEventListener('visibilitychange', () => {
			if (document.hidden) {
				hiddenAt = Date.now();
				send();
			} else if (hiddenAt) {
				hiddenTotal += Date.now() - hiddenAt;
				hiddenAt = 0;
			}
		});
		window.addEventListener('pagehide', send);
	}

	window.overtimeMetrics = {
		/**
		 * config: {log_url, dev}. La primera llamada (pantalla de carga) sincroniza UTMs y arranca view_time;
		 * las siguientes (el juego) solo ajustan la configuración.
		 */
		init(configJson) {
			const config = JSON.parse(configJson || '{}');
			if (config.log_url) logUrl = config.log_url;
			if (config.dev) dev = true;
			if (started) return;
			started = true;
			syncTrackingParams();
			trackViewTime();
		},
		/** La vista va una sola vez por carga de página (la manda quien llegue primero). */
		view(metadataJson) {
			if (viewSent) return;
			viewSent = true;
			this.send('view', metadataJson);
		},
		/** Click interno: offer_slug obligatorio. */
		click(offerSlug, metadataJson) {
			try {
				sendEvent('click', { offer_slug: offerSlug, ...JSON.parse(metadataJson || '{}') });
			} catch {
				/* idem */
			}
		},
		send(type, metadataJson) {
			try {
				sendEvent(type, JSON.parse(metadataJson || '{}'));
			} catch {
				/* idem */
			}
		},
		/** Click de salida: offer_slug con prefijo de destino (amateur: / sugarcams:). */
		outbound(destination, offerSlug, metadataJson) {
			const slug = DESTINATION_PREFIX_RE.test(offerSlug) ? offerSlug : `${destination}:${offerSlug}`;
			try {
				sendEvent('click', { offer_slug: slug, ...JSON.parse(metadataJson || '{}') });
			} catch {
				/* idem */
			}
		},
		outboundUrl(url, defaultsJson) {
			return outboundUrl(url, JSON.parse(defaultsJson || '{}'));
		},
		open(url) {
			window.open(url, '_blank', 'noopener');
		},
		visitorId: getOrCreateVisitorId,
	};
})();
