# Ella Gardens — time-of-day palette (Figma spec)

One system, six stops on a single day arc: **Dawn → Morning → Midday → Golden → Twilight → Starlight**. Each garden = a 3-stop sky gradient (linear, 180°, top→bottom over the top ~42% of the screen) + a 3-stop hill/field gradient (same angle, remaining ~58%) + one celestial body + an optional ground-glow accent.

For each: create a Figma linear gradient fill, angle 180°, with color stops at 0% / 55% / 100%.

## 1. Dawn Garden — sunrise
- Sky gradient: `#FFE3D0` (0%) → `#F6C9E0` (55%) → `#E4E8FA` (100%)
- Hill gradient: `#E8F0B8` (0%) → `#A8D888` (55%) → `#5C9A48` (100%)
- Sun: core `#FFF3DE`, mid `#FFD9A8`, radial glow `rgba(255,214,168,0.38)` → `rgba(255,197,148,0.16)`. Small (40px), low in frame (rising).
- Ground glow accent: `rgba(255,224,196,0.35)`

## 2. Morning Meadow — early morning
- Sky: `#EAFDFF` → `#D9FAFF` → `#F1FFF8`
- Hill: `#D7F2C4` → `#8DD67C` → `#4E9A45` *(= existing `--gradient-garden-field` token — reuse directly)*
- Sun: core `#FFFBEA`, mid `#FFE066`, glow `rgba(255,224,102,0.32)` → `rgba(255,184,77,0.14)`. 44px, upper-right.
- Ground glow accent: `rgba(215,242,196,0.5)`

## 3. Midday Grove — high noon
- Sky: `#B8E4F8` → `#D9FAFF` → `#EAFDFF`
- Hill: `#C5E8A0` → `#6BC85E` → `#3D8438` (richest, most saturated green — "grove" density)
- Sun: core `#FFFDF0`, mid `#FFD666`, glow `rgba(255,224,102,0.4)` → `rgba(255,184,77,0.18)`. Largest (48px), brightest.
- Ground glow accent: `rgba(197,232,160,0.55)`

## 4. Golden Orchard — late afternoon
- Sky: `#FFF3D4` → `#FFD9A0` → `#F9E8B8`
- Hill: `#E8DE9C` → `#B8C468` → `#7A8A3A` (warm olive-gold)
- Sun: core `#FFEAC2`, mid `#FFC15E`, glow `rgba(255,193,94,0.42)` → `rgba(255,170,0,0.16)`. 52px, low + large (golden-hour glow).
- Ground glow accent: `rgba(255,214,140,0.4)`

## 5. Twilight Valley — dusk
- Sky: `#9B8AC4` → `#D9A8C0` → `#FFCFAE` (violet → mauve → warm horizon band)
- Hill: `#A8C488` → `#5C8A5C` → `#2F4A38` (cooled, deepened green)
- Moon (replaces sun): core `#F8F4FF`, mid `#E4D8F5`, glow `rgba(216,204,240,0.4)` → `rgba(155,138,196,0.16)`. 38px.
- Stars: 4, white `#FFFFFF` @ 85% opacity, 1.5–3px dots, scattered upper third only.
- Ground glow accent: `rgba(155,138,196,0.22)`

## 6. Starlight Summit — night
- Sky: `#1A1F3D` → `#3D3468` → `#6B5A94` (deep navy → indigo → violet horizon glow)
- Hill: `#4A6250` → `#26362E` → `#141F1A` (darkest, coolest — near the `--ink` token)
- Moon: core `#F7F5FF`, mid `#DCD4F0`, glow `rgba(247,245,255,0.45)` → `rgba(180,200,255,0.15)`. 40px.
- Stars: 14, scattered across full sky band.
- Ground glow accent: `rgba(180,200,255,0.14)`

## Notes for Figma
- Fence, signs, planter beds, path stay the same warm-wood palette across all six — only sky + hill + celestial body change. Keeps the chrome legible and the day-cycle read purely through atmosphere.
- Morning Meadow and Midday Grove's hill/sky pairs are the two already living in `tokens/colors.css` / `gradients.css` (`--field-*`, `--environment-*`) — build those as styles first, then the other four as siblings in the same "Garden Skies" and "Garden Hills" style groups.
- Dusk/night ground-glow accents are cooler and lower-opacity than the daytime ones — they're moonlight, not sun-warmed grass.
