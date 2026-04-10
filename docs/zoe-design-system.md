# Ella Design System — v3
**Vivid Gouache · NavGurukul · Voice-first English Learning · Android-first**
*Updated April 2026*

---

## Design DNA

Ella v3 is a full replacement of the earlier chalked/muted v2 palette. Direction is **Vivid Gouache** — the energy of Indian festival colours rendered through rounded, friendly geometry. Full-saturation colours are a functional decision: budget Android screens under outdoor ambient light wash out muted tones.

**Five principles:**

1. **Voice-first, screen-secondary.** Mic button is always dominant. No screen needs more than two taps to reach it.
2. **Bilingual always.** Every scaffold chip, Ella annotation, and key instruction must have a Hindi equivalent. Baloo 2 must always be in the font stack.
3. **Colour carries meaning.** Orange = action/speaking. Blue = academics/Ella. Lime = reward/growth. Rose = interests/energy. Grape = rare/bonus. Never break this mapping.
4. **Brand colours are not system colours.** Rose ≠ Error. Lime ≠ Warning. Grape is never used for feedback states.
5. **Stamp shadow = tactile.** The hard offset shadow on buttons makes them feel pressable. Maintain it consistently.

---

## 1. Colour Tokens

All tokens are defined in [`lib/theme/ella_theme.dart`](../lib/theme/ella_theme.dart) as `EllaColors` static constants.

### Stop Naming Convention

| Stop | Role |
|---|---|
| `lightest` | Screen backgrounds, hover fills |
| `light` | Chip backgrounds, bubble fills |
| `top` | Gradient top-stop (lighter than main) |
| `main` | Buttons, card fills, badges, active icons |
| `dark` | Pressed states, borders on coloured fills |
| `deepest` | Body text on light fills |

---

### Mango — CTAs · Mic · User speech bubbles

| Token | Hex | Flutter const |
|---|---|---|
| `mango-lightest` | `#FFF3E0` | `EllaColors.mangoLightest` |
| `mango-light` | `#FFD699` | `EllaColors.mangoLight` |
| `mango-top` | `#FFAA20` | `EllaColors.mangoTop` *(gradient top-stop)* |
| `mango-main` | `#FF9500` | `EllaColors.mangoMain` |
| `mango-dark` | `#C87000` | `EllaColors.mangoDark` |
| `mango-deepest` | `#7A4400` | `EllaColors.mangoDeepest` |

Mango owns the primary CTA button, the mic button, and all user-generated speech surfaces. Button gradient goes `mangoTop` → `mangoMain` (top to bottom).

---

### Sky — Ella's voice · Academics · Trust

| Token | Hex | Flutter const |
|---|---|---|
| `sky-lightest` | `#E8F4FF` | `EllaColors.skyLightest` |
| `sky-light` | `#B8DCFF` | `EllaColors.skyLight` |
| `sky-top` | `#55AEFF` | `EllaColors.skyTop` *(gradient top-stop)* |
| `sky-main` | `#3B9EFF` | `EllaColors.skyMain` |
| `sky-dark` | `#1A6CC8` | `EllaColors.skyDark` |
| `sky-deepest` | `#0A3870` | `EllaColors.skyDeepest` |

Ella's speech bubbles, conversation screen background, academic content cards.

---

### Lime — Rewards · Growth · Progress

| Token | Hex | Flutter const |
|---|---|---|
| `lime-lightest` | `#F0FBE8` | `EllaColors.limeLightest` |
| `lime-light` | `#C4F08A` | `EllaColors.limeLight` |
| `lime-main` | `#72CC14` | `EllaColors.limeMain` |
| `lime-dark` | `#4E9A00` | `EllaColors.limeDark` |
| `lime-deepest` | `#2A5800` | `EllaColors.limeDeepest` |

Progress bars, streak counts, level-up moments, completion badges.

---

### Rose — Interests · Energy · Topics

| Token | Hex | Flutter const |
|---|---|---|
| `rose-lightest` | `#FFF0F3` | `EllaColors.roseLightest` |
| `rose-light` | `#FFB8C8` | `EllaColors.roseLight` |
| `rose-main` | `#FF4878` | `EllaColors.roseMain` |
| `rose-dark` | `#C82050` | `EllaColors.roseDark` |

Topic selection, interest-path cards, celebratory energy. Do not use for error states.

---

### Grape — Rare rewards · Bonus · Premium milestones

| Token | Hex | Flutter const |
|---|---|---|
| `grape-lightest` | `#F5F0FF` | *(defined in design, not yet in code)* |
| `grape-main` | `#8B5CF6` | *(not yet implemented)* |
| `grape-dark` | `#6030C8` | *(not yet implemented)* |

Reserved for rare moments only. Scarcity is the signal — overuse destroys it.

---

### Zoe (Mascot)

| Token | Hex | Flutter const |
|---|---|---|
| `zoe-mint` | `#4CAF82` | `EllaColors.zoeMint` |
| `zoe-mint-light` | `#D4F0E4` | `EllaColors.zoeMintLight` |

Used exclusively for the Zoe/Ella mascot circle — `zoeMintLight` as the circle fill, `zoeMint` as the border accent.

---

### Neutral — Backgrounds · Text · Borders

| Token | Hex | Flutter const | Usage |
|---|---|---|---|
| `neutral-bg` | `#FFFDF8` | `EllaColors.neutralBg` | App default background (warm off-white) |
| `neutral-surface` | `#FFF7EC` | `EllaColors.neutralSurface` | Card surfaces, elevated panels, input fills |
| `neutral-border` | `#F0E4CC` | `EllaColors.neutralBorder` | Dividers, card strokes, inactive borders |
| `neutral-muted` | `#C0A880` | `EllaColors.neutralMuted` | Placeholder text, metadata, disabled labels |
| `neutral-secondary` | `#6B5740` | `EllaColors.neutralSecondary` | Secondary body text, captions |
| `neutral-primary` | `#2C1E0F` | `EllaColors.neutralPrimary` | Primary body text — all readable content |

`neutral-primary` is warm dark brown, not pure black — easier on the eye for the 10–18 age group.

---

### Special Tokens

| Token | Hex | Flutter const | Usage |
|---|---|---|---|
| `ink` | `#1A1220` | `EllaColors.ink` | **Reserved:** avatar border ring only. See shadow note below. |
| `sunny-yellow` | `#FFD600` | `EllaColors.sunnyYellow` | Welcome screen corner accent only |

**Ink usage note:** The design spec reserves `ink` for both the CTA stamp shadow and the avatar ring. The current `EllaPrimaryButton` implementation uses `mangoDark` as the stamp shadow colour (not `ink`). The avatar ring uses `ink`. This is an intentional implementation deviation — `mangoDark` was found to look better against the gradient fill in practice.

---

### Semantic Colours

| Token | Hex | Flutter const | Usage |
|---|---|---|---|
| `error` | `#E0103C` | `EllaColors.error` | Network failures, unrecognised speech |
| `warning` | `#FFAA00` | `EllaColors.warning` | Time limits, caution states |
| `success` | `#72CC14` | `EllaColors.success` | Correct answers, task completions (= limeMain) |

These are distinct from brand families. Error ≠ Rose. Warning ≠ Mango. Success = limeMain (same hex, different semantic role).

---

## 2. Typography

Four typefaces. Each has a fixed role — do not mix.

| Typeface | Role | Weights | Flutter |
|---|---|---|---|
| **Fredoka** (via Chillax asset) | Display, headings, app title | 400–700 | `fontFamily: 'Chillax'` |
| **Baloo 2** | Body text, buttons, Hindi (Devanagari) | 400–800 | `GoogleFonts.baloo2()` |
| **Kalam** | Ella's voice, handwritten annotations | 400, 700 | `GoogleFonts.kalam()` |
| **Inconsolata** | Eyebrows, spec labels, monospace | 400, 700 | `GoogleFonts.inconsolata()` |

**Critical:** Baloo 2 is the only font in the stack with quality Devanagari support. It must always be present on any surface that may display Hindi.

### Type Scale

| Role | Size | Typeface | Weight | Usage |
|---|---|---|---|---|
| Display XL | 64px | Fredoka | 700 | Celebration full-screen moments |
| Display L | 56px | Fredoka | 700 | Hero section titles, level-up |
| Display M | 42px | Fredoka | 600 | Screen titles |
| Display S | 32px | Fredoka | 600 | Card titles, modal headings |
| Title | 24px | Fredoka | 600 | Sub-section titles |
| Heading | 20px | Baloo 2 | 800 | Nav labels, bold UI headings |
| Body Large | 16px | Baloo 2 | 600 | Primary body, button labels |
| Body | 14px | Baloo 2 | 500 | Secondary body, supporting copy |
| Caption | 12px | Baloo 2 | 600 | Badge labels, timestamps |
| Ella voice large | 22px | Kalam | 700 | Speech bubble main text |
| Ella voice | 17px | Kalam | 400 | Inline hints, Hindi whisper-text |
| Eyebrow / label | 11px | Inconsolata | 700 | Section labels, CEFR spec labels |

Hindi text: same size as English equivalent, Baloo 2 at 600 (headings) or 500 (body). Always with a visual separator (dashed border-top) when following English in the same container.

---

## 3. Spacing Scale

Multiples of 4px. Use named tokens — don't hardcode px values.

| Token | Value | Usage |
|---|---|---|
| `space-1` | 4px | Icon-to-label gaps, micro badge padding |
| `space-2` | 8px | Internal chip padding (vertical) |
| `space-3` | 12px | Internal chip padding (horizontal) |
| `space-4` | 16px | Card internal padding, list item gaps |
| `space-5` | 20px | Section sub-heading margins |
| `space-6` | 24px | Card padding (standard), modal padding |
| `space-8` | 32px | Section gaps, margin above major headings |
| `space-12` | 48px | Screen-level separation, bottom nav clearance |

Screen gutters: 16px mobile, 24px tablet. Bottom nav clearance: 48px minimum.

---

## 4. Border Radius Scale

| Token | Value | Usage |
|---|---|---|
| `radius-sharp` | 0px | Structural dividers only — never interactive |
| `radius-badge` | 8px | Small status badges |
| `radius-card` | 20px | Cards, modals, speech bubbles, avatar containers |
| `radius-button` | 24px | Buttons (uniform-radius contexts) |
| `radius-chip` | 20px | All chips |
| `radius-full` | 9999px | Mic button circle, avatar ring, pill shapes |

**Diagonal corner pair (locked):** Primary/CTA buttons use `4px 20px 4px 20px` (TL sharp, TR round, BR sharp, BL round). Secondary buttons use the opposite: `20px 4px 20px 4px`. This creates intentional visual tension in paired layouts. Do not normalise to uniform radius.

In Flutter (`EllaPrimaryButton`):
```
topLeft: 4, topRight: 20, bottomRight: 4, bottomLeft: 20
```

---

## 5. Shadow System

| Token | Value | Context |
|---|---|---|
| `shadow-stamp` | `offset(0,5) mangoDark blurRadius:0` | Primary CTA / mic button — idle |
| `shadow-stamp-active` | `offset(0,1) mangoDark blurRadius:0` | Primary CTA / mic button — pressed |
| `shadow-soft` | `0 4px 16px rgba(0,0,0,0.08)` | Floating modals, toasts, overlay cards |
| `shadow-card` | `0 2px 8px rgba(0,0,0,0.06)` | Content cards on surface backgrounds |

**Press-depth mechanic (implemented in `EllaPrimaryButton`):** On press, shadow offset collapses `(0,5) → (0,1)` AND button translates `translateY(4px)`. Duration: 70ms ease. Shadow and translate must always change together — one without the other breaks the tactile illusion.

**Shadow colour:** The stamp shadow uses `mangoDark` (#C87000), not `ink`. This is an intentional deviation from the original spec — `mangoDark` integrates better with the Mango gradient fill. The `ink` token is reserved for the avatar ring border only.

---

## 6. Screen Backgrounds

| Screen | Background colour | Texture |
|---|---|---|
| Welcome / Home | `neutral-bg` #FFFDF8 | Multi-colour confetti dots (Mango, Sky, Lime, Rose) |
| Placement check | `neutral-bg` #FFFDF8 | Concentric circles in `neutral-border` at 80% opacity, centred on mascot |
| Result / Summary | `lime-lightest` #F0FBE8 | Confetti dots (Lime + Mango) |
| Conversation | `sky-lightest` #E8F4FF *(aspirational: EFF7FF)* | Ruled lines — not yet implemented |
| Interests | `rose-lightest` #FFF0F3 *(aspirational)* | Diagonal hatching — not yet implemented |

All textures are `CustomPaint` — no image assets for backgrounds.

---

## 7. Components — Quick Reference

| Component | Fill | Border | Shadow | Shape |
|---|---|---|---|---|
| Primary CTA | `mangoTop→mangoMain` gradient | none | stamp (`mangoDark`, offset 0 5) | `4 20 4 20` diagonal |
| Secondary button | white | `neutral-border` 2px | none | `20 4 20 4` opposite diagonal |
| Ghost button | transparent | `mango-main` 2px | none | same as primary |
| Mic button | `mango-main` | `ink` 2.5px | stamp (`mangoDark`) | circle `radius-full` |
| Scaffold chip | white | `neutral-border` | 2px bottom in border colour | pill `radius-chip` |
| Topic chip | brand-colour solid | `ink` 2px | stamp 2px 2px at `ink` | pill `radius-chip` |
| Ella bubble | `sky-lightest` | `sky-light` 2px | `shadow-card` | TL 4px, others 18px |
| User bubble | `mango-main` | `ink` 2px | stamp 2px 2px `ink` | TR 4px, others 18px |
| Mascot circle | `zoe-mint-light` | — | soft (`neutral-muted` 40%) | circle `radius-full` |
| Level badge | `{level}-lightest` | `{level}-light` 2px | none | pill `radius-badge` |
| Card / modal | white or `neutral-surface` | `neutral-border` | `shadow-card` | `radius-card` 20px |

**CEFR Level → student label → colour:**

| CEFR | Label | Colour |
|---|---|---|
| A1 | First Words | Sky |
| A2 | Finding My Voice | Mango |
| B1 | Speaking Freely | Lime |
| B2 | Almost Fluent | Rose |
| C1 | Fluent | Grape |

Never show CEFR codes (A1–C1) on student-facing surfaces.

---

## 8. Colour-Role Quick Lookup

| Context | Use |
|---|---|
| Primary CTA | `mango-main` gradient, `mangoDark` stamp shadow |
| Mic button | `mango-main`, `ink` border, `mangoDark` stamp shadow |
| User speech bubble | `mango-main`, `ink` border + shadow |
| Ella speech bubble | `sky-lightest` fill, `sky-light` border |
| Avatar ring border | `ink` — one of only two reserved uses |
| Academic content | Sky family |
| Topic / interest selection | Rose family |
| Rewards / progress | Lime family |
| Rare bonus moments | Grape family |
| Correct answer / completion | `success` (= `limeMain`) |
| Network error / unrecognised speech | `error` — not Rose |
| Time limits / caution | `warning` — not Mango |
| Body text | `neutral-primary` |
| Structural borders | `neutral-border` |

---

## 9. What Not To Do

- Do not use Rose, Lime, or Grape for success/error/warning states.
- Do not use `ink` on any element except the avatar border ring (CTA uses `mangoDark` for its stamp shadow).
- Do not remove Baloo 2 from any screen that may display Hindi.
- Do not use Caveat — no Devanagari support. Kalam replaces it.
- Do not show CEFR codes (A1–C1) on any student-facing surface.
- Do not normalise button corners to uniform radius — the diagonal pair is locked.
- Do not swap Mango and Sky between user channel and Ella's channel.

---

*Ella Design System v3 · NavGurukul · April 2026*
