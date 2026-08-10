# Ella Components — Botanical Berry
**NavGurukul · Voice-first English Learning**
*Per-component style specs. Foundations (colour, type, spacing): [`docs/ella-design-system.md`](./ella-design-system.md).*

All components live under `ella_app/lib/`. Reusable widgets are in `screens/child_view/widgets/`; some (chat bubbles, home cards) sit in `screens/child_view/`; shared primitives (toast, offline popup) in `core/`. Specs below are the current code — token names refer to `EllaColors` (see foundations §1).

---

## Buttons

### `EllaPrimaryButton` — [`widgets/ella_primary_button.dart`](../ella_app/lib/screens/child_view/widgets/ella_primary_button.dart)

Flat-fill button. No gradient, no gloss. Three variants via `EllaButtonVariant`.

| | Fill | Edge | Label |
|---|---|---|---|
| `primary` | `berryMain` | `berryDeep` 3px | `onPrimary` |
| `secondary` | `greenMain` | `greenDark` 2px | `ink` |
| `outline` | `surface` | `berryDeep` 3px | `berryDark` |

- **Height** 52 (default) · **radius** pill `999` · **horizontal padding** 18 · label `EllaTextStyles.button` (18 / Synonym 700), `height 1.15`, max 2 lines.
- **Shape:** `ellaSmoothDecoration` (superellipse). Disabled = fill at 50% alpha.
- **Shadow (stamp):** single `BoxShadow(color: edge, offset (0,3), blurRadius 0)` — hard, no blur. Empty when pressed or disabled.
- **Press mechanic:** `AnimatedContainer` **80 ms `Curves.ease`** — on press the button drops `translateY(3)` **and** the stamp collapses to `[]` (they always move together). `playTapClick()` fires on tap-up.

### `EllaIconButton` — same file

Round variant of the flat button. Default **size 60**, `BoxShape.circle`, **2px** edge. Berry: fill `berryMain` / edge `berryDark` / icon `onPrimary`. Green (`secondary: true`): fill `greenMain` / edge `greenDark` / icon `ink` (onPrimary fails AA on green). Icon size = `size × 0.5`. Same stamp shadow + 80 ms press-translate as the primary button. Used at **size 72** as the chat composer's send button.

---

## Mic & voice dock — [`widgets/conversation_view.dart`](../ella_app/lib/screens/child_view/widgets/conversation_view.dart)

The real mic is **not** `EllaIconButton` — it's the private `_MicButton` in the voice dock.

### `_MicButton` (size 100)

- Circle, **3px** edge. **Fill by state:** idle `berryMain` · listening `berryDark` · busy `textDisabled`. Edge: busy `textTertiary`, else `berryDeep`.
- Stamp shadow `berryDeep` `offset (0,3) blur 0`; none when busy. Cross-fades over **180 ms** (`AnimatedContainer`) — **no** translate on press (unlike the flat buttons).
- Glyph: `assets/send-button.svg` when listening, else `Icons.mic_rounded`, sized `size × 0.44`, tinted `onPrimary`.

### `_DockCircle` (side controls, size 58)

Circle, 2px ring, stamp shadow `offset (0,3) blur 0`. Keyboard toggle = `greenLight` fill / `greenDeep` ring; end-call = `errorLight` fill / `errorDark` ring.

### `_ProgressBar`

Height 12, track `greenLight` (radius 999), fill = `LinearGradient([greenMain, greenDeep])` (radius 999, min 12px), animates **320 ms easeOut**.

---

## Chat bubbles — [`child_view/chat_bubble.dart`](../ella_app/lib/screens/child_view/chat_bubble.dart)

### Zoe bubble

Fill `surface`; radius **TL18 / TR18 / BL4 / BR18** (tail bottom-left, toward the avatar); padding H14 / V10; soft shadow `black @8% blur 4 offset (0,2)`. Text via `TypewriterText` (word-by-word reveal + karaoke highlight). `_ZoeAvatar` = 32×32 `greenDark` circle with a 🎒 emoji at 16px.

### User bubble

A `DottedBorder` (color `#E91E63`, strokeWidth **2.5**, dash `[8,4]`, radius 18) around a `#FCE4EC` fill; text `bodyBase` in `#880E4F`, w700, +1px, height 1.4.

> ⚠️ **Known drift.** The user bubble hardcodes pink hexes (`#E91E63` / `#FCE4EC` / `#880E4F`) instead of the berry tokens. The karaoke highlight in the Zoe bubble also uses `#E91E63` directly.

### Latest-turn bubbles (conversation view)

`conversation_view.dart` renders the *current* turn with its own bubble styling: the Zoe bubble there uses an **`info` (`#5898E0`) 2.5px border**, radius TL4 / others 18; the user bubble likewise uses a dotted border. Two bubble implementations coexist — keep them in sync when editing.

---

## Chips & cards

| Component | Source | Spec |
|---|---|---|
| **Home topic chip** (`_ChipShell` / `_TopicChip`) | `home_screen.dart` | Radius **16**. Selected: fill `berryLight`, outline `berryDark` 2.5px, label `berryDark`. Unselected: fill `surface`, outline `ink @20%` 1.5px, label `ink`. Icon 56px. |
| **All-topics card** (`_TopicCard`) | `all_topics_screen.dart` | `ellaSmoothDecoration`, radius **18**, side `ink @15%` 1.5px, fill `surface`. |
| **Garden header chip** ("Sunrise Seedbed") | `placement_garden_header.dart` | Fill `surface`, radius **11.16**, border `EllaColors.border` 2.79px, soft shadow `black @10% blur 6 offset (0,2)`, height 48. |
| **Last-time card** | `home_screen.dart` | `ellaSmoothDecoration`, radius 16, side `info` 2px, fill `surface`, padding H16 / V14. |
| **Spotlight callout bubble** | `widgets/spotlight_callout_bubble.dart` | `ellaSmoothDecoration`, radius **TL4 / others 20**, side `info` (`#5898E0`) 3px, fill `surface`. Title/body `bodySemiboldLarge` in `greenDeep`, 32px sprout icon. |
| **Evidence / strand chips** | `widgets/garden_dialogs.dart` | Strand chip radius 6; evidence box radius 12, `track.border` 2px. |
| **"Zoe's Pick" chip** | `widgets/topic_carousel.dart` | Pill, radius **999**, fill `berryLight`, border `berryDark` 1.5px, label in `berryDark`. Shown on the carousel's designated pick topic (defaults to the first topic), with a visibility-driven fade. |

---

## Navigation

### `HomeShortcutHeader` — [`widgets/home_shortcut_header.dart`](../ella_app/lib/screens/child_view/widgets/home_shortcut_header.dart)

Shared Garden / Profile shortcut row used by both home experiences, via two `EllaCircleIconButton`s (diameter **72**) with a labelled chip below each:

| | Fill | Ring | Label / chip |
|---|---|---|---|
| Garden shortcut | `greenLight` | `greenDark` | `greenDeep` text, chip fill `greenLight` / border `greenDark` |
| Profile shortcut | `surfaceVariant` | `info` | `infoDark` text, chip fill `surfaceVariant` / border `info` |

Glyph SVGs (`nav-garden.svg` / `nav-profile.svg`, 56px) sway ±0.06 rad over a 2600ms loop (`_SwayingGlyph`, pivoted at the bottom center); disabled when `MediaQuery.disableAnimations` is set. Label style `buttonSmall`.

---

## Transitions

### `TopicHandoff` — [`widgets/topic_handoff.dart`](../ella_app/lib/screens/child_view/widgets/topic_handoff.dart)

Hero-animated flight from a topic card (home/carousel) into the conversation screen. Hero tag: `topic-handoff:<topic.name>:<topic.icon>`.

- **Flight** `kTopicHandoffFlightDuration` = 650ms, then **settle** `kTopicHandoffSettleDuration` = 360ms.
- Spins a full turn during flight: `rotation = -2π × forwardProgress`.
- Flutter's Hero shuttle applies `Curves.fastOutSlowIn`, which would otherwise bunch the spin into the middle of the flight — `topicHandoffLinearFlightProgress()` recovers linear progress via a 16-step binary search against the curve so the rotation reads as constant-speed.

---

## Level pill — `_LevelSelectorPill` — [`garden_screen.dart`](../ella_app/lib/screens/child_view/garden_screen.dart)

The current "level badge" is the garden's level switcher: height **48**, fill `surface`, radius **11**, border `EllaColors.border` 2.8px, padding H12 / V8, trailing 24px `greenDeep` chevron circle. Label 16.7 / w600 / `ink`. No stamp shadow.

---

## Dialogs, sheets & toast

| Component | Source | Spec |
|---|---|---|
| **OfflineAlertPopup** | `core/offline_alert_popup.dart` | `Dialog`, fill `surface`, `RoundedRectangleBorder` radius 24, padding 24, `wifi_off` icon 64px `berryMain`, then an `EllaPrimaryButton`. |
| **EditProfileDialog** | `widgets/edit_profile_dialog.dart` | Max width 387, backdrop blur σ8. **Wood banner** 5-stop gradient `#C49050 → #9B6828 → #B08040 → #966828 → #8A5712`, radius 8, shadow `0x33000000 offset (0,4) blur 4`. Fields height 72, radius 20, `border`. |
| **NeedToGoSheet** | `widgets/need_to_go_sheet.dart` | `showModalBottomSheet`, barrier `black @45%`, fill `surface`, top radius 24; 40×4 drag handle; two `EllaPrimaryButton`s (primary + outline) at height 56. |
| **Garden signpost sheets** | `widgets/garden_dialogs.dart` | `ellaSmoothDecoration` radius 20 with a wood signpost header board (radius 8, layered shadows). |
| **`_GardenMilestoneLayer`** ("2nd conversation" milestone) | `garden_screen.dart` | One-time full-screen overlay after the student's 2nd conversation. `black @58%` scrim, centered `ZoeMascot` (idle, 96px) above an `ellaSmoothDecoration` card (radius 20, fill `surface`, shadow `black @18% offset (0,8) blur 18`) with `bodySemiboldLarge`/`ink` copy and a single `_GardenIntroButton` CTA. Reuses the same shape as `_CompletedPreviousGardenIntroLayer` — no new tokens. |
| **App toast** | `core/app_toast.dart` | Floating `SnackBar`, elevation 3, radius 16, margin LTRB(16,0,16,20), 3 s. Error = `ink` bg / `onDark` fg; neutral = `surface` / `ink`. |

---

## Celebration / spot-access components

### `SpotAccessScreen` — [`spot_access_screen.dart`](../ella_app/lib/screens/child_view/spot_access_screen.dart)

One-time "you've got a spot" welcome screen shown to NavGurukul early-access students before onboarding. Uses existing tokens only: `borderStrong` dividers, `berryDark` accent/icon, `onPrimary` text on filled surfaces. No new colours introduced.

### `MascotGlow` / `FloatingLeaf`

See [`ella-design-system.md` §5](./ella-design-system.md#5-celebration--ambient-effects) for full specs — `MascotGlow` (radial pulse glow behind Zoe, ⚠️ inline hex, see Known drift below) and `FloatingLeaf` (drifting ambient leaf SVGs) are both used together on `SpotAccessScreen` and other celebration moments.

---

## Small round controls

| Component | Source | Size | Spec |
|---|---|---|---|
| **SpeakerDotButton** | `widgets/speaker_dot_button.dart` | 32 | Circle, fill `berryMain` (idle) / `berryDark` (active), edge `berryDeep` 2px, icon `onPrimary` at size×0.55. No shadow. |
| **GardenSoundButton** | `widgets/garden_sound_button.dart` | 40 | Circle, fill `surface`, border 2px (`berryDark` on / `textTertiary` off), soft shadow `black @10% blur 6 offset (0,2)`. |
| **EllaCircleIconButton** | `widgets/circle_icon_button.dart` | 64 | Circle, caller-supplied fill + 3px ring, optional caption (gap 4, `caption` style). No shadow. |
| **Placement header `_CircleControl`** | `widgets/placement_garden_header.dart` | 32 | Circle, 2.4px border, stamp shadow `greenDeep offset (0,3) blur 0`. Back = green family; sound = `berryMain`. |

---

## Mascot — `ZoeMascot` — [`widgets/zoe_mascot.dart`](../ella_app/lib/screens/child_view/widgets/zoe_mascot.dart)

Zoe is a **native vector sprout drawn by a `CustomPainter`** — not an image, not a styled circle. (This fully replaces the earlier ".webp mascot in a zoe-mint circle".)

- ViewBox 563 × 667; default `size 200` (clamped 32–320); optional `clipToCircle` wraps it in a `ClipOval`.
- Body fill `#98F8E9`, stroke `#4B978F` 14px; leaves fill `#72A562`, stroke `#3D8449`.
- **Modes:** `speaking`, `listening`, `thinking`, `idle`, `sleep`, `paused` — each layer (body, eyes, cheeks, mouth, leaves, stems, thinking droplets) animates independently off a free-running ticker clock (breath, leaf sway, blink, pseudo-viseme mouth). `reducedMotion` freezes to a calm closed-mouth pose.

---

## CEFR level → garden

Students never see CEFR codes. They see the **garden name** (from `_GardenLevelVisualSpec.label`) and unit names (from `curriculum_display_copy.dart`).

| CEFR | Garden (student-facing name) |
|---|---|
| A0 | Dawn Glade |
| A1 | Morning Meadow |
| A2 | Midday Grove |
| B1 | Golden Orchard |
| B2 | Twilight Valley |
| C1 | Starlight Summit |

(The engine's `kCefrLevels` in `constants.dart` is `A1…C2`; the six *visual* gardens span A0–C1, with unknown levels falling back to Midday Grove. See foundations §4 for each garden's colours.)

---

## Known drift / deviations

Documentation of where the code currently departs from the tokens/ideal — noted so future edits don't mistake these for intentional patterns. (Docs-only; no code change is implied here.)

- **User chat bubble** hardcodes `#E91E63` / `#FCE4EC` / `#880E4F` instead of berry tokens; the karaoke highlight also hardcodes `#E91E63`.
- **`berryMain`** is flagged decorative / AA-failing in `theme_colors.dart`, yet is the live fill on the primary button, the idle mic, and the speaker dot. Acceptable per the reference design; switch to `berryDark` if flagged on-device.
- **`EditProfileDialog._updateButton`** and the **`conversation_view` latest-turn bubbles** re-implement button/bubble styling inline instead of reusing `EllaPrimaryButton` / `ChatBubble` — a drift risk if the shared components change.
- The retired Vivid Gouache system's **locked `4/20/4/20` diagonal button corners** were dropped for uniform pills; the 4px-tail idea survives only on the spotlight callout bubble and the chat-bubble tails.
- **`MascotGlow`** (`widgets/mascot_glow.dart`) hardcodes its radial gradient (`0xCCFFE066 / 0x70FFD24D / 0x00FFB84D`) instead of referencing an `EllaColors` token, despite its own code comment claiming it follows the A1 Morning Meadow palette. Same category of drift as the chat bubble's hardcoded pink.

---

*Ella Components · Botanical Berry · NavGurukul. Foundations: [`ella-design-system.md`](./ella-design-system.md).*
