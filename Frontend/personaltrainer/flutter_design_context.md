# Flutter Design Context — Personal TrAIner

Fuente de verdad del diseño visual para las pantallas Flutter nuevas.
Extraído de `Personal TrAIner/lovable proyect/src/styles.css` (tokens OKLCH en
`:root` y `.dark`) y reconciliado con el `DesignTokens` ya existente en
`lib/src/core/theme/design_tokens.dart`.

Commit fuente del prototipo React: `54c310b` ("Añadió rutas y mockups UI").

---

## 0. Nota de reconciliación (IMPORTANTE)

El prototipo React contiene **dos dialectos de paleta**:

1. **Sistema OKLCH global** (`styles.css` `:root`/`.dark`), consumido vía clases
   Tailwind (`bg-background`, `bg-card`, `bg-ai-gradient`, …) por `index.tsx` y
   `clinic.import.tsx`. La conversión OKLCH→sRGB del gradiente IA da
   **cian→azul→teal** (`#1BAFF6 / #00BCFE / #00DFDB`).

2. **Paleta "conceptual oscura"** definida inline como objeto `theme` local en
   `progress.tsx`, `recovery.tsx`, `devices.tsx` con hex fijos (p.ej.
   `#0B0D12`, `#161922`) y un gradiente IA **púrpura→índigo→sky**
   (`#B054F0 / #6A5CF0 / #46B5E8`).

El `DesignTokens` de Flutter ya existente adoptó el dialecto **2** (púrpura),
que es el que usan las 3 rutas que más se replican en este paso. Para no
duplicar sistemas ni romper las 7 pantallas protegidas, **este documento
canoniza el dialecto 2 como el sistema Flutter oficial** y deja el dialecto 1
(sólo OKLCH de `styles.css`) como tabla de referencia (sección 1). Los tokens
nuevos que necesitan las 5 pantallas (sección 3) se añaden **additivamente** a
`DesignTokens`, todos con nombre — nunca hex sueltos.

---

## 1. Tokens OKLCH globales de `styles.css` (referencia)

Conversión Oklab (Ottosson) → sRGB lineal → sRGB gamma → hex.

### Light (`:root`)

| Token | OKLCH | HEX | Color() |
|---|---|---|---|
| background | `oklch(1 0 0)` | `#FFFFFF` | `Color(0xFFFFFFFF)` |
| foreground | `oklch(0.18 0.01 260)` | `#0A1315` | `Color(0xFF0A1315)` |
| card / popover | `oklch(1 0 0)` | `#FFFFFF` | `Color(0xFFFFFFFF)` |
| primary | `oklch(0.18 0.01 260)` | `#0A1315` | `Color(0xFF0A1315)` |
| primary-foreground | `oklch(0.99 0 0)` | `#FCFCFC` | `Color(0xFFFCFCFC)` |
| secondary / muted / accent | `oklch(0.965–0.97 0.005 260)` | `#EFF5F6` / `#F0F6F8` | `Color(0xFFF0F6F8)` |
| muted-foreground | `oklch(0.55 0.02 260)` | `#60767B` | `Color(0xFF60767B)` |
| border / input | `oklch(0.93 0.005 260)` | `#E3E9EB` | `Color(0xFFE3E9EB)` |
| ring | `oklch(0.7 0.04 256)` | `#75A8B3` | `Color(0xFF75A8B3)` |
| surface-1 | `oklch(0.985 0.003 260)` | `#F7FBFC` | `Color(0xFFF7FBFC)` |
| surface-2 | `oklch(0.97 0.005 260)` | `#F0F6F8` | `Color(0xFFF0F6F8)` |
| destructive | `oklch(0.577 0.245 27.325)` | `#FF0030` | `Color(0xFFFF0030)` |
| ai-from | `oklch(0.72 0.18 295)` | `#1BAFF6` | `Color(0xFF1BAFF6)` |
| ai-via | `oklch(0.7 0.19 260)` | `#00BCFE` | `Color(0xFF00BCFE)` |
| ai-to | `oklch(0.78 0.17 200)` | `#00DFDB` | `Color(0xFF00DFDB)` |

### Dark (`.dark`)

| Token | OKLCH | HEX | Color() |
|---|---|---|---|
| background | `oklch(0.129 0.042 264.695)` | `#000A15` | `Color(0xFF000A15)` |
| foreground | `oklch(0.984 0.003 247.858)` | `#F7FBFB` | `Color(0xFFF7FBFB)` |
| card / popover | `oklch(0.208 0.042 265.755)` | `#001D28` | `Color(0xFF001D28)` |
| primary | `oklch(0.929 0.013 255.508)` | `#DAEBEF` | `Color(0xFFDAEBEF)` |
| secondary / muted / accent | `oklch(0.279 0.041 260.031)` | `#002F39` | `Color(0xFF002F39)` |
| muted-foreground | `oklch(0.704 0.04 256.788)` | `#76A9B4` | `Color(0xFF76A9B4)` |
| destructive | `oklch(0.704 0.191 22.216)` | `#FF3972` | `Color(0xFFFF3972)` |
| border | `oklch(1 0 0 / 0.1)` | `#FFFFFF@10%` | `Color(0x1AFFFFFF)` |
| input | `oklch(1 0 0 / 0.15)` | `#FFFFFF@15%` | `Color(0x26FFFFFF)` |
| ring | `oklch(0.551 0.027 264.364)` | `#5A777F` | `Color(0xFF5A777F)` |
| chart-1 | `oklch(0.488 0.243 264.376)` | `#0074CF` | `Color(0xFF0074CF)` |
| chart-2 | `oklch(0.696 0.17 162.48)` | `#4FB484` | `Color(0xFF4FB484)` |
| chart-3 | `oklch(0.769 0.188 70.08)` | `#FF4F33` | `Color(0xFFFF4F33)` |
| chart-4 | `oklch(0.627 0.265 303.9)` | `#0089EF` | `Color(0xFF0089EF)` |
| chart-5 | `oklch(0.645 0.246 16.439)` | `#FF0061` | `Color(0xFFFF0061)` |

> Los stops `ai-from/via/to` NO se redefinen en `.dark` (heredan los de `:root`).

---

## 2. Sistema Flutter canónico (`DesignTokens`, dialecto púrpura)

Valores ya presentes en `lib/src/core/theme/design_tokens.dart` — son los que
usarán las 5 pantallas nuevas y las existentes. Se muestran aquí como guía
rápida; el código es la fuente única.

| Token Flutter | HEX / ARGB | Mapea a (origen) |
|---|---|---|
| `lightBackground` | `#FFFFFF` | OKLCH background |
| `darkBackground` | `#111318` | recovery/devices `theme.bg` |
| `lightForeground` | `#1B1B20` | OKLCH foreground (approx) |
| `darkForeground` | `#F9F9FC` | `theme.fg` |
| `darkCard` | `#23262F` | recovery `theme.card` |
| `darkSurface1` | `#1B1D24` | `theme.surface1` |
| `darkSurface2` | `#1A1C22` | progress `theme.surface2` approx |
| `darkMutedForeground` | `#9DA0AE` | `theme.label` |
| `darkBorder` | `Color(0x1AFFFFFF)` | `theme.border = rgba(255,255,255,0.06)` (Flutter usa 10%) |
| `darkDestructive` | `#EF5A5F` | OKLCH destructive (approx) |
| `aiFrom` | `#B054F0` | recovery/devices aiFrom |
| `aiVia` | `#6A5CF0` | recovery/devices aiVia |
| `aiTo` | `#46B5E8` | recovery/devices aiTo |
| `aiGradient` | `from→via→to @ 0/0.55/1.0` | `linear-gradient(135deg,…)` |
| `aiGradientSoft` | `#EEDBFC → #DCEBFB` | recovery `glassFrom/To` |
| `warnSoft` | `#FBE8B0 → #F4D785` | styles.css `bg-warn-soft`, recovery alert |

`cardRadius = 28.0`, `radius2xl = 18.0`, `radius3xl = 22.0`, `radius4xl = 26.0`.

---

## 3. Tokens nuevos (añadidos additivamente a `DesignTokens` para las 5 pantallas)

Ninguno de estos debe usarse como hex suelto en las pantallas; se referencian
vía `DesignTokens.<nombre>`.

### Progress (`progress.tsx`)
| Token | HEX | Uso |
|---|---|---|
| `progressBlue` | `#3B82F6` | entrenos completados, anillos training |
| `progressBlueSoft` | `#60A5FA` | iconos training highlight |
| `progressGreen` | `#22C55E` | nutrición objetivo, % grasa, peak semana |
| `progressRed` | `#EF4444` | exceso calórico |
| `progressOrange` | `#F59E0B` | carbos / calorías diarias línea |
| `progressGray` | `#2A2F3C` | días futuros / descanso |

### Recovery (`recovery.tsx`)
| Token | HEX | Uso |
|---|---|---|
| `recoveryAiFrom / Via / To` | `#B054F0 / #6A5CF0 / #46B5E8` | = aiFrom/Via/To (alias) |
| `recoveryGlassFrom / To` | `#EEDBFC / #DCEBFB` | hero glass card (= aiGradientSoft) |
| `recoveryAlertFrom / To` | `#FBE8B0 / #F4D785` | alerta predictiva (= warnSoft) |
| `recoveryAlertText` | `#9A3412` | texto alerta |
| `recoveryAlertIcon` | `#C2410C` | icono alerta |
| `recoveryStageAwake` | `#3A3F4D` | fase "Despierto" en barra apilada |

### Devices (`devices.tsx`)
| Token | HEX | Uso |
|---|---|---|
| `deviceLive` | `#10B981` | pill "Syncing", estado online (= home_page live) |
| `deviceBadgeDot` | `#FF6900` | punto del badge "Device" (= badge Mi Fitness) |
| `deviceBadgeBg` | `#1E1E1E` | fondo del badge "Device" |

### Focus (`focus.tsx`)
| Token | HEX | Uso |
|---|---|---|
| `focusFgCyan` | `#22D3EE` | trazo del HR chart (cyan) |
| `focusFgCyan2` | `#06B6D4` | medio del gradiente HR |
| `focusFgTeal` | `#14B8A6` | fin del gradiente HR |
| `restGradFrom` | `#818CF8` | timer descanso (indigo-400) |
| `restGradTo` | `#C084FC` | timer descanso (purple-400) |
| `hrZoneRecovery / Cardio / High / Peak` | `#38BDF8 / #34D399 / #FBBF24 / #FB7185` | badge zona FC |

### Clinic import (`clinic.import.tsx`)
Usa los tokens globales (`background`, `card`, `surface1`, `surface2`,
`border`, `aiGradient`, `aiGradientSoft`) sin tokens nuevos. Sólo modos
`menu / pdf / image / manual`.

---

## 4. Tipografía

### Prototipo React (`__root.tsx`)
Único `<link>` de Google Fonts cargado:
`Inter:wght@400;500;600;700;800`. Outfit y Manrope NO están enlazadas →
el navegador cae a **Inter** en runtime.

### Código de las rutas (inline en `progress.tsx` / `recovery.tsx` / `devices.tsx`)
```ts
const titleFont = { fontFamily: "Outfit, Inter, sans-serif", fontWeight: 800, letterSpacing: "-0.5px" };
const bodyFont  = { fontFamily: "Manrope, Inter, sans-serif" };
```

### Flutter (canonizado en `app_theme.dart`)
- **Headers / títulos**: `GoogleFonts.outfit()`, `FontWeight.w800`,
  `letterSpacing: -0.5` (≈ `titleFont`). `app_theme.dart` ya lo define en
  `displaySmall/Medium`, `headlineMedium/Small`, `appBarTheme.titleTextStyle`.
- **Body**: `GoogleFonts.manrope()` (≈ `bodyFont`). `app_theme.dart` lo define
  en `titleLarge/Medium`, `bodyLarge/Medium/Small`, `labelMedium/Small`.

> Decisión Flutter: mantener `GoogleFonts.outfit / manrope` (consistencia con
> `home_page.dart` y `app_theme.dart`). El fallback Inter del prototipo se
> documenta aquí pero NO se aplica en Flutter (GoogleFonts resuelve Outfit/Manrope).

### Label style (consistente en progress/recovery/devices)
```
fontSize: 11, fontWeight: 600, letterSpacing: 1.4px,
textTransform: uppercase, color: muted-foreground
```
En Flutter → `DesignTokens.labelStyle` ya cubierto por `labelSmall` del
`TextTheme` (11px, w600, ls 1.4). Para textos ad-hoc usar el helper
`DesignTokens.labelSmall` (ver extensión).

---

## 5. Radios, espaciados y patrones

| Patrón | React (Tailwind / inline) | Flutter |
|---|---|---|
| Tarjeta grande / hero | `rounded-[28px]` o `radius: 28` | `DesignTokens.cardRadius` (28.0) |
| Tarjeta media / item | `rounded-2xl` (16) o `radius: 18` | `DesignTokens.radius2xl` (18.0) |
| Chip / pill | `rounded-full` (999) | `BorderRadius.circular(999)` |
| Chip métrico | `rounded-2xl` (16) | `16.0` |
| Padding página | `padding: "12px 20px 32px 20px"` | `EdgeInsets.fromLTRB(20,12,20,32)` |
| Gap sección | `gap: 20` | `SizedBox(height: 20)` |
| Ancho móvil | `max-w-[440px]` | `maxWidth: 440` en `Center`/`ConstrainedBox` |
| Stroke de anillo | `strokeWidth 3–6` | `strokeWidth` en `CustomPaint` |
| Borde input | `ring-1 ring-border` | `Border.all(color: DesignTokens.border(b))` |
| CTA principal | `bg-ai-gradient` + `shadow-card` | `BoxDecoration(gradient: DesignTokens.aiGradient, boxShadow: DesignTokens.shadowCard(b))` |

### Estilos de label por componente (sacado de las 3 rutas)
- Topbar: `labelStyle` (11/600/1.4/upper) — p.ej. "Progreso · Junio 2026".
- Header de sección: `labelStyle` + clave (p.ej. "Correlaciones IA").
- Métrica pequeña: `labelStyle` con `fontSize: 9` (override).
- Weekdays: `labelStyle` con `fontSize: 10`.
- Legend: `fontSize: 11`, `color: label`, sin uppercase.

---

## 6. Reglas de uso para las 5 pantallas nuevas

1. **Siempre** `DesignTokens.<token>`; nunca `Color(0xFF...)` literal nuevo.
   Los únicos hex sueltos permitidos son los que ya viven en `DesignTokens`.
2. Tipografía vía `Theme.of(context).textTheme` (`headlineSmall`, `bodyMedium`,
   `labelSmall`, …) o, si se necesita `titleFont` exacto, helper
   `DesignTokens.titleFont()` / `bodyFont()` (añadidos).
3. Cards: `Container` con `BoxDecoration(color: DesignTokens.card(b),
   borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
   boxShadow: DesignTokens.shadowCard(b))`.
4. Datos **inyectados** (constructor o provider); todo punto de integración
   backend marcado con `// TODO: conectar a GET /...`.
5. Modo oscuro supuesto (las 3 rutas conceptuales son dark-only); las pantallas
   respetan `Theme.brightness` para no romper light, pero optimizan para dark.