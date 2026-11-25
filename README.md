# SemanaLista

Planificador semanal de comidas para iPhone. Genera el menú de la semana, la lista de la compra organizada por pasillos del supermercado y el orden de cocina por lotes (*batch cooking*), todo en una sola app y sin cuentas ni servidores propios.

La app funciona **sin conexión y sin clave de IA** con un plan base local, y opcionalmente usa un modelo de lenguaje para crear menús personalizados según el número de comensales, dietas, alergias e ingredientes que no te gustan.

<details>
<summary>English summary</summary>

SemanaLista is a SwiftUI iPhone app that builds a weekly meal plan, a supermarket-aisle shopping list and a batch-cooking timeline. It works offline with a built-in local planner, and can optionally use any OpenAI-compatible Chat Completions endpoint (Groq, OpenAI, OpenRouter, OpenCode Go or a custom URL). API keys are stored in the iOS Keychain, never in the repository. iOS 18+, Xcode 27.2+.

</details>

---

## Funciones

- **Menú semanal** de 7 días con comida y cena, adaptado a 1–N comensales.
- **Generación con IA** (opcional) o **plan base local** generado en el dispositivo.
- **Dietas y exclusiones**: vegana, vegetariana, sin cerdo, sin lactosa, sin gluten, sin pescado, sin marisco, además de alergias y lista de ingredientes vetados.
- **Lista de la compra** agrupada por pasillo (frutería, carnicería, lácteos…), con sección de despensa, cantidades ya sumadas y casillas para ir tachando.
- **Cocina por lotes**: orden de preparaciones, tiempos, raciones y número de táperes, con progreso paso a paso.
- **PDF del menú** de varias páginas, numerado, listo para compartir o guardar en Fotos.
- **Compartir** la lista de la compra como texto.
- **Apariencia** automática, clara u oscura.
- **Español e inglés**: si cambias el idioma del sistema, el menú guardado se regenera para que interfaz, contenido y PDF coincidan.
- **Registro de errores** integrado, exportable, para reportar fallos.

## Requisitos

| | |
|---|---|
| Sistema | macOS con **Xcode 27.2 o superior** (el proyecto usa el formato nuevo `project.xcproj`) |
| Destino | **iOS 18.0+**, solo iPhone |
| Dependencias | Ninguna. Solo frameworks de Apple (SwiftUI, CoreGraphics/PDF, Security/Keychain). No hay CocoaPods, SPM ni Carthage |
| Lenguaje | Swift 5 |

## Cómo ejecutarlo

### 1. Clona el repositorio

```bash
git clone git@github.com:alexotalvaro/semanalista.git
cd semanalista
```

Si no tienes clave SSH configurada, usa HTTPS:

```bash
git clone https://github.com/alexotalvaro/semanalista.git
```

### 2. Abre el proyecto

```bash
open SemanaLista.xcodeproj
```

### 3. Ejecuta en el simulador

1. Arriba, selecciona el esquema **SemanaLista**.
2. Elige un simulador de iPhone (por ejemplo *iPhone 17*).
3. Pulsa **⌘R**.

También puedes compilar desde la terminal, sin firmar:

```bash
xcodebuild -project SemanaLista.xcodeproj -scheme SemanaLista \
  -destination 'generic/platform=iOS Simulator' build
```

### 4. Ejecutar en tu iPhone (opcional)

El proyecto trae un `DEVELOPMENT_TEAM` del autor, que no te servirá para firmar. Cámbialo por el tuyo:

1. Selecciona el proyecto **SemanaLista** en el navegador de la izquierda.
2. Pestaña **Signing & Capabilities**.
3. En **Team**, elige tu Apple ID (si no aparece, añádelo en *Xcode → Settings → Accounts*).
4. Si Xcode se queja del bundle identifier, cámbialo por uno tuyo, por ejemplo `com.tunombre.semanalista`.
5. Conecta el iPhone, selecciónalo como destino y pulsa **⌘R**.

> Para el simulador no hace falta firmar ni tener cuenta de desarrollador.

## Configurar la IA (opcional)

Sin clave, la app usa el **plan base local**: pulsa *Generar plan base* y ya tienes menú, compra y cocina. Si quieres menús generados por IA:

1. Abre la pestaña **Ajustes** (o el último paso del onboarding).
2. Elige **Proveedor**.
3. Pega tu **clave API**.
4. Ajusta el **modelo** si quieres (hay modelos sugeridos por proveedor).
5. Vuelve a **Semana** y pulsa **Generar nueva semana**.

| Proveedor | URL base | Modelo por defecto |
|---|---|---|
| Groq | `https://api.groq.com/openai/v1` | `llama-3.3-70b-versatile` |
| OpenAI | `https://api.openai.com/v1` | `gpt-4.1-mini` |
| OpenRouter | `https://openrouter.ai/api/v1` | `openai/gpt-4.1-mini` |
| OpenCode Go | `https://opencode.ai/inference/go/openai/v1` | `deepseek-v4.1-flash` |
| Personalizado | la que indiques | la que indiques |

Todos usan el formato **OpenAI Chat Completions** (`/chat/completions`). Si eliges *Personalizado*, escribe la URL base completa (la app añade `/chat/completions` si falta) y el nombre exacto del modelo.

**La clave nunca se guarda en el proyecto ni se sincroniza**: se almacena en el **Keychain** del dispositivo y solo se envía al proveedor que elijas. En el repositorio no hay claves, tokens ni archivos `.env`.

## Cómo se usa

| Pestaña | Qué hace |
|---|---|
| **Semana** | Menú de los 7 días. Toca un plato para ver ingredientes y detalles. Botón para regenerar el menú, exportar el PDF o guardarlo en Fotos. |
| **Compra** | Lista agrupada por pasillo + despensa. Tacha lo que ya tienes y comparte la lista como texto. |
| **Cocina** | Orden de preparaciones para cocinar la semana de una vez: tiempos, raciones, táperes y progreso. |
| **Ajustes** | Proveedor y clave de IA, modelo, comensales, dietas, alergias, apariencia, idioma del sistema y registro de errores. |

### Exportar el menú

- **PDF**: desde *Semana* → exportar. El documento se pagina y numera solo si ocupa más de una hoja.
- **Fotos**: la app pide permiso para *añadir* imágenes (no lee tu fototeca).

## Estructura del proyecto

```
semanalista/
├── SemanaLista.xcodeproj/
│   ├── project.xcproj                    # Configuración del proyecto (formato JSON nuevo)
│   └── xcshareddata/xcschemes/           # Esquema compartido "SemanaLista"
└── SemanaLista/
    ├── SemanaListaApp.swift              # Punto de entrada y pestañas
    ├── AppStore.swift                    # Estado observable: ajustes, plan, compra, clave
    ├── Models.swift                      # Modelos: platos, plan, dietas, proveedores
    ├── LocalPlan.swift / LocalPlanEnglish.swift  # Planificador local sin IA
    ├── AIPlanner.swift                   # Cliente Chat Completions + parseo del plan
    ├── Storage.swift                     # Persistencia local y Keychain
    ├── WeekView.swift                    # Pestaña Semana
    ├── ShoppingView.swift                # Pestaña Compra
    ├── CookView.swift                    # Pestaña Cocina
    ├── SettingsView.swift                # Pestaña Ajustes
    ├── OnboardingView.swift              # Primer arranque
    ├── MealDetailView.swift              # Detalle de un plato
    ├── MenuPDF.swift                     # Render del PDF y hoja de compartir
    ├── ErrorLog.swift / ErrorLogView.swift
    ├── Design.swift                      # Colores, tipografía y estilos
    ├── Localization.swift                # Utilidades de idioma
    ├── Exclusions.swift                  # Alergias, dietas e ingredientes vetados
    ├── en.lproj/ y es.lproj/             # Traducciones
    └── Assets.xcassets/                  # Icono y color de acento
```

## Desarrollo

El proyecto no tiene tests automatizados. Para probar pantallas concretas sin pasar por el onboarding, la app acepta argumentos de lanzamiento (en *Product → Scheme → Edit Scheme → Run → Arguments*):

| Argumento | Efecto |
|---|---|
| `-demo` | Salta el onboarding y carga un plan base local |
| `-onboarding` | Fuerza el onboarding (solo `DEBUG`) |
| `-diet vegan` | Carga un plan con una dieta concreta (`vegan`, `vegetarian`, `noPork`, `noLactose`, `noGluten`, `noFish`, `noSeafood`) |
| `-mock-ai http://localhost:8080/v1` | Apunta a un servidor local compatible con Chat Completions y regenera al arrancar |
| `-tab 2` | Abre directamente una pestaña (0 Semana, 1 Compra, 2 Cocina, 3 Ajustes) |
| `-appearance dark` | Fuerza la apariencia (`system`, `light`, `dark`) |

Los archivos de compilación (`build/`, `DerivedData/`, `xcuserdata/`) están excluidos en `.gitignore`.

## Privacidad

- El plan, la lista de la compra y los ajustes se guardan **solo en el dispositivo**.
- La clave de API se guarda en el **Keychain**.
- Si usas IA, se envían al proveedor elegido tus preferencias (comensales, dietas, alergias, ingredientes vetados) para generar el menú. No se envía nada a servidores del autor de la app.
- Los menús generados por IA pueden contener errores: **revisa siempre alérgenos, cocción y conservación** antes de comer.

## Problemas frecuentes

**«Signing for "SemanaLista" requires a development team»** → elige tu equipo en *Signing & Capabilities* (ver paso 4).

**«The bundle identifier is already in use»** → cambia `PRODUCT_BUNDLE_IDENTIFIER` por uno propio.

**No genera el menú con IA** → comprueba la clave, la URL base y que el modelo exista en ese proveedor. Si el modelo no soporta algún parámetro, la app reintenta sin él automáticamente. Mientras tanto puedes usar *Generar plan base*.

**El PDF sale en otro idioma** → el menú se guarda con el idioma en que se generó; al cambiar el idioma del sistema se regenera solo. También puedes regenerarlo a mano.

## Licencia

© 2026 alexotalvaro. **Todos los derechos reservados.**

Este repositorio es público para consulta y aprendizaje, pero **no es software de código abierto**: no se permite copiar, modificar, redistribuir ni usar el código (total o parcialmente) sin permiso expreso por escrito del autor. La licencia podrá cambiar en el futuro.
