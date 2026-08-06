# Ella Design System — Botanical Berry
**NavGurukul · Voice-first English Learning · Android-first**
*Foundations: colour, type, spacing, shadows, garden atmospheres*

> Component specs live in a separate file: [`docs/ella-components.md`](./ella-components.md).

---

## Naming — read this first

Three names appear in this codebase; they are **not** interchangeable:

| Name | What it is | Where it lives |
|---|---|---|
| **Botanical Berry** | The name of *this* design system | Code comments (`theme_colors.dart`, `text_styles.dart`, button headers) |
| **ZoSpeak** | The app's user-facing wordmark | `MaterialApp.title` (`ella_app/lib/app.dart`), login wordmark (`login_screen.dart`) |
| **Zoe** | The AI mascot / tutor the child talks to | `MessageSender.zoe`, `ChatStatus.zoeSpeaking`, `EllaTextStyles.zoeVoice` |
| **Ella** | Internal code namespace only (not user-facing) | `EllaColors`, `EllaFonts`, `EllaTextStyles`, `ella_api_service.dart` |

This document is titled "Ella Design System" to match the `Ella*` code namespace it documents. The active app is `ella_app/`; all tokens below are defined under `ella_app/lib/core/`.

---

## Design DNA

Botanical Berry is a full replacement of the earlier **Vivid Gouache** system (Mango / Sky / Lime / Rose / Grape). That palette, its gradient CTAs, and its Fredoka/Kalam fonts are **retired** — nothing in `ella_app/` uses them. See the migration table in §1.

The metaphor is a **garden that grows as the child speaks**. Colour carries three atmospheres:

1. **Berry = action.** CTAs, the mic, "speak now" energy. Pink family.
2. **Green = growth.** Progress, rewards, the child's own bloom. Green family.
3. **Environment = atmosphere.** Sky, air, the calm backdrop conversation happens against. Pale cyan family.

**Accessibility rule baked into the tokens** (`theme_colors.dart` header): `berryMain` and `greenDark` are **decorative only** — white text on `berryMain` is 3.55:1, which fails WCAG AA. The AA-safe interactive fill is **`berryDark`** (5.92:1 with `onPrimary`). Never place a label directly on `berryMain` or `greenDark`.

---

## 1. Colour tokens

Defined in [`ella_app/lib/core/theme_colors.dart`](../ella_app/lib/core/theme_colors.dart) as `EllaColors` static constants (`abstract final class`). Every token below is `EllaColors.<name>`.

### Neutrals / surface

| Token | Hex | Usage |
|---|---|---|
| `canvas` | `#F7FCFB` | App background, root scaffold |
| `surface` | `#FFFDF4` | Default cards, panels, composer, bubbles |
| `surfaceVariant` | `#F1FFF8` | Grouped / garden-adjacent surfaces |
| `surfaceElevated` | `#FFFAF0` | Dialogs, floating cards |
| `border` | `#D5E7DF` | Default borders / dividers |
| `borderStrong` | `#9DB8AE` | Focused inputs, selections |

### Text

| Token | Hex | Usage |
|---|---|---|
| `ink` | `#28362F` | Primary text on light surfaces (warm near-black) |
| `textSecondary` | `#5B7067` | Supporting copy |
| `textTertiary` | `#80948C` | Metadata, timestamps, inactive |
| `textDisabled` | `#B7C9C1` | Disabled controls |
| `onPrimary` | `#FFFCF7` | Text / icons on Berry / green fills |
| `onDark` | `#F7FCFB` | Text / icons on deep scrims |

### Berry — primary / action

| Token | Hex | Role |
|---|---|---|
| `berryLight` | `#FFD9E8` | Soft action surfaces, selected chips |
| `berryMain` | `#E84A8A` | **Decorative brand fill only** — never white text on it |
| `berryDark` | `#B92261` | **AA-safe interactive fill**, pressed / active states |
| `berryDeep` | `#7B163C` | Text on berry-tinted surfaces, button/mic edges |

### Green — accent / growth

| Token | Hex | Role |
|---|---|---|
| `greenLight` | `#DDF8E8` | Growth cards, garden hints |
| `greenMain` | `#71D99B` | Secondary button fill, greenhouse accent |
| `greenDark` | `#2F9A55` | Active garden action, leaves — **decorative, no white text** |
| `greenDeep` | `#185E35` | Dark green text, borders |

### Environment — sky / atmosphere

| Token | Hex | Usage |
|---|---|---|
| `environmentLight` | `#EAFDFF` | Sky tint, glass highlight |
| `environmentMain` | `#D9FAFF` | Screen air, chat backdrop |
| `environmentDark` | `#9CDCE8` | Sky shadows, glass edges |
| `environmentDeep` | `#4C8290` | Text on environment fills |

### Garden greens

| Token | Hex | Usage |
|---|---|---|
| `fieldLight` | `#D7F2C4` | Far field, grass planes |
| `fieldMain` | `#8DD67C` | Main ground plane |
| `fieldDark` | `#4E9A45` | Ground depth, hill shadow |
| `leaf` | `#4EB96E` | Leaves, small garden icons |
| `stem` | `#2F9A55` | Plant stems |
| `moss` | `#6EAE48` | Progress bars, utility actions |
| `soil` | `#9A6A44` | Soil, pot edges |

### Semantic colours

Each has Light / base / Dark stops. Distinct from brand families — do not substitute.

| Role | Light | Base | Dark |
|---|---|---|---|
| `error` | `#FFE8EE` | `#E0103C` | `#A50B2E` |
| `warning` | `#FFF3D4` | `#FFAA00` | `#B86D00` |
| `success` | `#E8F8EF` | `#2F9A55` | `#185E35` |
| `info` | `#E8F4FF` | `#5898E0` | `#1A3870` |

`success` shares its hex with `greenDark`/`stem`; `info` is used as the accent border on Zoe callout/latest-turn bubbles.

### Gradients — `BotanicalBerryGradients`

Stop lists (each documents a solid fallback). **Do not use gradients as default card backgrounds** — reserve them for highlights and scenes.

| Gradient | Stops | Fallback |
|---|---|---|
| `berry` | `#FF8EB8 → #E84A8A → #B92261` (stops `0 / .55 / 1`) | `berryDark` |
| `green` | `#A8F0C6 → #71D99B → #2F9A55` | `greenMain` |
| `environment` | `#F7FFFF → #D9FAFF → #F1FFF8` | `environmentMain` |
| `surface` | `#FFFFFF → #FFFDF4 → #F1FFF8` | `surface` |
| `gardenField` | `#D7F2C4 → #8DD67C → #4E9A45` | `fieldMain` |
| `celebration` | `#EAFDFF → #FFD9E8 → #DDF8E8` | `berryLight` |

### Skill-track colours — `TrackColors`

Role-aliased sets (`surface` / `border` / `main` / `text`) for the three learning tracks. `main` is for blooms / badges / accent bars; `text` is readable on `surface`.

| Track | Identity | surface | border | main | text |
|---|---|---|---|---|---|
| `vocabulary` | Rose | `#FFF0F3` | `#F0C0CC` | `#D4708A` | `#6E3040` |
| `fluency` | Violet | `#F5F0FF` | `#D8CCF0` | `#9478D0` | `#3E2870` |
| `grammar` | Blue | `#E8F4FF` | `#B8DCFF` | `#5898E0` | `#1A3870` |

### Back-compat aliases (legacy — prefer canonical)

`bg = canvas`, `muted = textTertiary`, `secondary = textSecondary`, `primary = ink`, `bubbleSurface = surface`. These exist only so unmigrated call sites compile; use the canonical tokens in new code.

### Migration — Vivid Gouache → Botanical Berry

| Old (retired) | Now |
|---|---|
| `mango*` | Removed. Action role → **Berry**. |
| `sky*` | Removed. → **`environment*`** ramp. |
| `lime*` | Removed. → **`green*`** / `success`. |
| `rose*` | Removed as a top-level ramp → **`TrackColors.vocabulary`**. |
| `grape*` | Removed → **`TrackColors.fluency`** (violet). |
| `zoe-mint*`, `sunny-yellow` | Removed. |
| `ink` | Redefined `#1A1220` → **`#28362F`**, and is now the primary text colour (not just a reserved ring/shadow). |
| `error` `#E0103C`, `warning` `#FFAA00` | Hex unchanged; Light/Dark stops added, plus a new `info` ramp. |

---

## 2. Typography

Defined in [`ella_app/lib/core/text_styles.dart`](../ella_app/lib/core/text_styles.dart). Two bundled families do all the work; Baloo 2 covers Hindi.

| Family | Role | Helper | Weights |
|---|---|---|---|
| **Amulya** (Fontshare) | Titles, UI, display | `EllaFonts.bricolage()` | 400, 700 |
| **Synonym** (Fontshare) | Body copy, button labels, Zoe's voice | `EllaFonts.body()` / `.zoe()` | 400, 500, 600, 700 |
| **Baloo 2** (google_fonts, runtime) | Hindi (Devanagari) fallback | `EllaFonts.hindi()` | — |

> ⚠️ **Known drift.** The helper method name `bricolage()` and several docstrings in `text_styles.dart` still say "Bricolage / Andika / Grandstander" — leftovers from earlier font trials. Every helper actually resolves to **Amulya** or **Synonym**. **Chillax** is still declared in `pubspec.yaml` but is no longer referenced by the type scale.

**Zoe's voice is Synonym w400 and is never bolded.**

### Type scale — `EllaTextStyles`

Base 16, minimum 12. Default colour `EllaColors.ink`, letter-spacing 0 unless noted.

| Style | Size | Family / weight | Usage |
|---|---|---|---|
| `caption` | 12 | Amulya 600 | Metadata, compact labels (minimum size) |
| `bodySmall` | 14 | Synonym 400 | Secondary / supporting copy |
| `bodyBase` | 16 | Synonym 400 | Default learner-facing text |
| `bodySemibold` | 16 | Synonym 600, h1.6 | Chat bubbles, home cards |
| `bodySemiboldLarge` | 18 | Synonym 600, h1.6 | Larger Zoe cards, garden reveal copy |
| `bodyLarge` | 18 | Synonym 400 | Important body, readable chat text |
| `titleSmall` | 20 | Amulya 700 | Card titles, section headings |
| `titleMedium` | 24 | Amulya 700 | Screen titles, modal titles |
| `headline` | 32 | Amulya 800 | Major screen heading, empty-state |
| `display` | 40 | Amulya 800 | Rare hero / celebration display |
| `authDisplay` | 40 | Amulya 700, h1.6 | Auth wordmark |
| `authTitle` | 20 | Amulya 700, h1.6 | Auth titles/subtitles |
| `authBody` | 18 | Synonym 400, h1.6 | Auth helper / privacy copy |
| `authBodySemibold` | 18 | Synonym 600, h1.6 | Auth confirmation copy |
| `button` | 18 | Synonym 700, h1.6 | Primary/secondary button labels |
| `buttonSmall` | 14 | Synonym 700, h1.6 | Compact CTA labels |
| `gardenHeaderChip` | 16 | Synonym 600, h1.6 | Placement garden header chip |
| `gardenHeaderTitle` | 20 | Amulya 700, h1.6 | Placement garden title |
| `zoeVoice` | 18 | Synonym 400 | Zoe bubbles & coaching prompts — **never bold** |

### Theme wiring

`ella_app/lib/app.dart` `_botanicalBerryTheme()` builds a Material 3 `ColorScheme` (`primary: berryDark`, `secondary: greenMain`, `surface: surface`, `scaffoldBackgroundColor: canvas`) and maps the `TextTheme` from these styles (`displayLarge→display`, `headlineLarge→headline`, `titleLarge→titleMedium`, `titleMedium→titleSmall`, `bodyLarge→bodyLarge`, `bodyMedium→bodyBase`, `bodySmall→bodySmall`, `labelLarge→button`, `labelSmall→caption`).

---

## 3. Spacing, radius & shadow

**There is no `EllaSpacing` / `EllaRadius` / `EllaShadow` token class.** `constants.dart` holds only engine/CEFR values. Spacing, radii, and shadows are applied inline at call sites. The conventions below are *de-facto*, observed across the widgets — follow them for consistency, but they are not enforced by a token.

**Spacing** — multiples of 4 (`4 / 8 / 12 / 16 / 20 / 24`). Screen gutters ~16–18px.

**Radius** — most-used values: `20` (cards, sheets, input fields), `18` (bubbles, topic cards), `16` (home cards/chips), `8` (small badges, wood banners), and full pills `999` / `100` (buttons, round controls). Structural corners like the garden header chip use bespoke values (`11`, `11.16`).

**Shape helper** — [`ella_app/lib/core/ella_smooth_shape.dart`](../ella_app/lib/core/ella_smooth_shape.dart): `ellaSmoothDecoration({color, borderRadius, side, shadows})` returns a `ShapeDecoration` backed by `RoundedSuperellipseBorder` (Figma-style corner smoothing). Use it for cards, bubbles, and pill CTAs — anything rounded-rectangular and expressive. Keep true circles as `BoxShape.circle`.

**Shadow** — two recurring idioms:
- **Stamp** (tactile): a hard offset with no blur, in the element's edge colour — `BoxShadow(color: edge, offset: Offset(0,3), blurRadius: 0)`. Used on buttons, the mic, dock circles. On press it collapses to `[]` (see button mechanics in the components doc).
- **Soft** (floating): `black @8–10% alpha, blurRadius 4–6, offset (0,2)`. Used on chat bubbles, cards, toasts.

---

## 4. Garden atmospheres

The garden is the app's signature scene. Each garden is a **one-off atmosphere** (sky + hill + celestial body + scatter), so these values are documented **separately** from the reusable palette above. Figma source of truth: [`docs/Garden Themes - Figma Values.md`](./Garden%20Themes%20-%20Figma%20Values.md).

### The six-level day-arc

One system, six stops along a single day. Each garden maps to a CEFR level and is selected by `_visualSpecFor(level)` in [`garden_screen.dart`](../ella_app/lib/screens/child_view/garden_screen.dart) (unknown levels fall back to Midday Grove). Sky and hill are both 3-stop linear gradients top→bottom, `stops [0, 0.55, 1]`; sky covers roughly the top ~42%, the hill the rest.

| Level | Garden | Sky (top → mid → bottom) | Hill (crest → mid → base) |
|---|---|---|---|
| A0 | **Dawn Glade** | `#FFE3D0` · `#F6C9E0` · `#E4E8FA` | `#E8F0B8` · `#A8D888` · `#5C9A48` |
| A1 | **Morning Meadow** | `#EAFDFF` · `#D9FAFF` · `#F1FFF8` | `#D7F2C4` · `#8DD67C` · `#4E9A45` |
| A2 | **Midday Grove** | `#B8E4F8` · `#D9FAFF` · `#EAFDFF` | `#C5E8A0` · `#6BC85E` · `#3D8438` |
| B1 | **Golden Orchard** | `#FFF3D4` · `#FFD9A0` · `#F9E8B8` | `#E8DE9C` · `#B8C468` · `#7A8A3A` |
| B2 | **Twilight Valley** | `#9B8AC4` · `#D9A8C0` · `#FFCFAE` | `#A8C488` · `#5C8A5C` · `#2F4A38` |
| C1 | **Starlight Summit** | `#1A1F3D` · `#3D3468` · `#6B5A94` | `#4A6250` · `#26362E` · `#141F1A` |

Morning Meadow's values equal the `environment*` / `field*` tokens (it is the "default" daytime garden). Twilight and Starlight are dark skies, so their title text switches to `onPrimary` for legibility.

### Per-garden scatter & celestial body

Each spec (`_GardenLevelVisualSpec`) also varies:

| Level | Celestial (radial, `[core, mid, glowInner, glowOuter]`) | Clouds | Stars | Bush tint | Ambient | Side prop | Fence |
|---|---|---|---|---|---|---|---|
| A0 Dawn | *(no sun)* | both | — | — | butterfly | grass tuft | 3 |
| A1 Morning | sun 56px @(360,160) — `#FFFBEA · #FFE066 · 0x52FFE066 · 0x24FFB84D` | both | — | — | bird | wildflowers | 4 |
| A2 Midday | sun 72px @(336,72) — `#FFFDF0 · #FFD666 · 0x66FFE066 · 0x2EFFB84D` | both | — | — | bee | wildflowers | 5 |
| B1 Golden | sun 72px @(336,104) — `#FFEAC2 · #FFC15E · 0x6BFFC15E · 0x29FFAA00` | left only | — | `#E2D37A` | golden butterfly | mushrooms | 6 |
| B2 Twilight | moon 48px @(27,89) — `#F8F4FF · #E4D8F5 · 0x66D8CCF0 · 0x299B8AC4` | none | — | `#86A16E` | firefly | mushrooms | 8 |
| C1 Starlight | moon 72px @(69,46) — `#F7F5FF · #DCD4F0 · 0x73F7F5FF · 0x26B4C8FF` | none | 9 (white @90%) | `#506858` | firefly | lantern | 10 |

Celestial gradient stops are `[0, 0.42, 0.72, 1]`. Each level also has its own plant icon SVG under `assets/garden/plants/`.

> ⚠️ **Known drift.** The six level specs re-declare their sky/hill hex as inline `const` lists in `garden_screen.dart:40-98` rather than referencing the `environment*` / `field*` / `BotanicalBerryGradients.gardenField` tokens — so A1's values are duplicated, not shared. If a token changes, the gardens won't follow.

### The two non-level gardens

**Home garden** — [`garden_sky_background.dart`](../ella_app/lib/screens/child_view/widgets/garden_sky_background.dart). The one **token-driven** garden. Sky `environmentLight → environmentMain → surfaceVariant` (stops `0/.55/1`); **two overlapping hill domes** (`#D7F2C4→#8DD67C` back, `#8DD67C→#4E9A45` front — the field ramp); a fixed warm sun top-left using `warning` (`#FFAA00`) with a `#FFF3D4` halo; two blurred white clouds.

**Placement garden** — "Sunrise Seedbed" ([`placement_garden_screen.dart`](../ella_app/lib/screens/child_view/placement_garden_screen.dart)). Reuses the **A1 Morning** palette (sky `#EAFDFF/#D9FAFF/#F1FFF8`, hill `#D7F2C4/#8DD67C/#4E9A45`), a single rounded hill mass, its own sun (`#FFF1C5 · #FFD77A · …` at upper-right), and scaffold background `#DDEFE4`. Like the level gardens, its hex is inline, not token-referenced.

---

## 5. What not to do

- Do not place white / `onPrimary` text on `berryMain` or `greenDark` (both fail AA) — use `berryDark` / `greenDeep`.
- Do not cross the atmosphere mapping: **berry = action, green = growth, environment = atmosphere.**
- Do not use `TrackColors` rose/violet/blue, or the semantic ramps, as general brand colours.
- Do not remove Baloo 2 from any surface that may show Hindi.
- Do not show CEFR codes (A0–C1) on student-facing surfaces — students see garden names (Dawn Glade …) and unit names, never the codes.
- Do not use gradients as default card fills — solid `surface` is the default; gradients are for scenes and highlights.

---

*Ella Design System · Botanical Berry · NavGurukul. Components: [`ella-components.md`](./ella-components.md).*
