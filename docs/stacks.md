# Stacks base

Punto de partida para proyectos nuevos, no una obligación. Evita que el agente
invente un stack distinto en cada proyecto y me deja revisar lo que construye.
Si un proyecto no encaja, el agente propone dos opciones cerradas, cada una con
su motivo, y elijo yo.

**Regla:** ninguna herramienta que no conozca entra sin que el agente me
explique antes, en pocas líneas, qué es, por qué esa y no otra, y dónde mirar
su código en el proyecto.

Criterios: herramientas populares (buena documentación, y el modelo las
conoce), tipos donde el lenguaje los permita, y las mismas piezas entre
proyectos.

## Qué base uso según el proyecto

| Tipo | Base | Se publica en |
|---|---|---|
| Landing, portfolio, sitio sin datos | HTML, CSS y JavaScript, sin framework ni paso de build | Cloudflare Pages o Vercel |
| App con datos o login | Python con FastAPI, Postgres en Docker, SQLAlchemy y Alembic, plantillas Jinja2 con CSS propio | Servidor de la empresa con Docker si es laboral; si es personal, se define al llegar el caso |
| Scripts, automatización, pipelines | Python con entorno virtual, lock commiteado, ruff y pytest | Jenkins o GitLab |

Es un borrador: cada fila se confirma con el primer proyecto real que la use.

## Librerías: cuándo sí

No se evitan: se justifican. Antes de sumar una, el agente me dice en dos líneas
qué resuelve, qué alternativa hay sin ella y cuánto pesa o cuánto hay que
mantenerla.

- **Sí:** lo difícil de hacer bien a mano (calendarios, mapas, gráficos,
  accesibilidad de ventanas y menús, autenticación), con una librería mantenida
  y más chica que escribirlo uno mismo.
- **No:** lo que el navegador ya hace (diseño, animaciones, formularios), o lo
  que obliga a sumar un paso de compilación a una página simple.
- **Íconos y logos:** nunca dibujados a mano. Se copian al proyecto solo los SVG
  que se usan, de una librería de íconos cuya licencia lo permita, en
  `img/iconos/` y con su archivo de licencia al lado: sin dependencia ni
  compilación. Los logos de marcas (WhatsApp, Instagram) son los oficiales.
  Antes de fijar una librería de íconos se verifica su licencia y que esté
  mantenida.

## Landing o portfolio

- Base: `index.html`, `css/` y `js/` (si hace falta). Sin `package.json`.
- CSS moderno nativo: variables, anidado, container queries.
- Seguridad mínima: sin scripts de terceros que no hagan falta; cabeceras
  (CSP, `X-Content-Type-Options`, `Referrer-Policy`) configuradas en la
  plataforma (`_headers` en Cloudflare Pages, `vercel.json` en Vercel).
- Un formulario de contacto necesita un backend aparte: se decide cuando haga falta.
- **Pruebas:** una landing sin lógica propia no lleva pruebas ni scripts de
  verificación: se revisa en el navegador, en celular y en compu. El CI es solo
  el trabajo `secretos` de la plantilla. Si hay un comportamiento que no se
  puede revisar a ojo (un formulario, un cálculo), una prueba chica de
  Playwright, y solo si la pido.

### Carpetas y material

```
proyecto/
├── material-cliente/   originales que manda el cliente, tal cual; git los
│   ├── logo/           ignora (pesan y tienen derechos de uso)
│   ├── fotos/
│   └── videos/
├── img/                versiones listas para la web; estas sí se commitean
│   ├── marca/          logo y favicon
│   ├── iconos/         SVG con su licencia
│   └── fotos/
├── video/              MP4 H.264 listos para la web
├── css/
├── js/
└── index.html
```

El agente deja en `img/` y `video/` las versiones optimizadas y no toca los
originales. Los videos se piden en MP4 H.264.

### Secciones y comportamientos por defecto (negocio local)

Borrador: sale de la primera landing hecha con este flujo y se ajusta con cada una.

- Secciones: portada con una frase y un botón de contacto, servicios o clases
  con precios, "sobre mí", horarios y ubicación con mapa, preguntas
  frecuentes, contacto y pie de página.
- Comportamientos: pensada primero para el celular, botón flotante de
  WhatsApp con mensaje prefijado, imágenes con texto alternativo y respeto de
  "reducir movimiento" en las animaciones.

## App con datos

- **Postgres siempre**, aunque el proyecto sea chico, para no migrar después.
  SQLite queda para scripts y herramientas locales.
- **Migraciones con Alembic** desde la primera tabla: el esquema vive en el
  código, no solo en la base.
- **Docker Compose** para correr la app y Postgres igual en mi máquina, en pre y
  en producción (ver el playbook).
- **Python** porque es donde mejor me manejo, ya lo uso en el trabajo y
  Pydantic da los tipos.
- **Node.js** lo estoy aprendiendo: entra a esta tabla cuando haga un proyecto
  personal con él, eligiendo el framework a conciencia en vez de dejar que lo
  elija el agente.

## Login

En la entrevista se pregunta quién va a entrar: gente de la empresa o personas
ajenas. De eso depende:

- **Laboral:** el inicio de sesión de la empresa (LDAP o SSO). La app no guarda
  contraseñas ni crea usuarios propios. Qué proveedor usan lo confirmo con la
  empresa; el agente no lo supone.
- **Personal o externo:** una librería o servicio ya hecho y mantenido (login
  con Google o GitHub, o usuario y contraseña con una librería). Nunca un
  sistema escrito a mano. El agente propone dos opciones con su motivo.
- **Siempre:** contraseñas con hash lento (argon2 o bcrypt) mediante librería,
  cookies de sesión `HttpOnly`, `Secure` y `SameSite`, límite de intentos y
  secretos en variables de entorno.

## Scripts

Un entorno virtual por proyecto, dependencias con lock, ruff y pytest. Es lo
que ya tienen los proyectos del trabajo.

## Fuera por ahora

Frameworks de frontend, Tailwind y TypeScript en el navegador: se evalúan si un
proyecto los pide, con el criterio de "Librerías: cuándo sí".
