# Home carousel design QA

- Source visual truth: the first reference image attached in the user
  conversation, refined by the approved “Zoe Carousel Arc and Label Layout”
  specification.
- Source pixels: 852 × 1845; normalized target aspect ratio: 390 × 844.
- Implementation screenshot:
  `/private/tmp/ella-home-carousel-arc.png`.
- Implementation pixels/CSS viewport: 390 × 844 at device pixel ratio 1.
- Iteration comparison:
  `/private/tmp/ella-home-carousel-iteration-comparison.png`.
- State: “AI and work” selected, two immediate neighbours clear, two outer
  neighbours partially clipped and misted.

## Full-view comparison evidence

The revised capture moves the complete Zoe/recap/carousel group 16 px upward
while keeping the recap readable and the CTA 24 px above the bottom. Zoe has a
24 px visible gap to the recap bubble, and the carousel heading remains 32 px
below the recap group. Moving the terrain to a cumulative 96 px offset keeps the
hills, bush, flowers, and grass below the selection area.

The five carousel positions retain the intended full-width presentation. The
selected item is visibly dominant, the neighbouring circles form a symmetric
12/24 px descending arc, and the pale green connector reads behind the circles
without obscuring their artwork.

## Focused carousel comparison

- Typography: the heading is exactly “Zoe's Pick” at 14 px. Topic labels use
  the existing Synonym family and remain at the established 14/12 px hierarchy.
  “AI and work,” “Fake news,” and “Old vs new” remain single-line; genuinely
  long labels are capped at two lines.
- Spacing: selected circle/artwork sizes are 96/72 px; other circles/artwork
  remain 68/48 px. Page centres are 106 px apart, preserving 24 px between the
  enlarged selected circle and its immediate neighbours. Every label begins
  6 px below its own circle.
- Arc: immediate-neighbour centres are 12 px below the selected centre and
  outer-neighbour centres are 24 px below it. The same values interpolate
  continuously during a half-page drag.
- Color: the connector uses a low-opacity garden green, the selected outline
  remains Botanical Berry, and the existing 0.55 opacity/0.65 sigma edge
  treatment is unchanged.
- Image quality: bundled topic SVGs, Zoe, navigation art, and the botanical
  scene remain sharp at device density 1.
- Copy: server topic names, the recap, and CTA relabelling remain unchanged
  apart from the requested “Pick” capitalization.

## Comparison history

1. The previous capture showed a flat circle row, a two-line “AI and work”
   selected label, extra visual space before neighbouring labels, and terrain
   rising into the selection region.
2. The carousel was changed to 96/72 px selected sizing, 106 px page spacing,
   centre-based 12/24 px arc offsets, a green connector, top-aligned labels,
   and wider natural label constraints.
3. Zoe and the recap were moved up, their visible gap was set to 24 px, and the
   complete terrain group was moved down to a cumulative 96 px offset.
4. The post-fix 390 × 844 capture confirms the stronger arc, single-line
   selected label, consistent icon-to-label rhythm, clear carousel/terrain
   separation, and retained bottom CTA position.

## Findings

No actionable P0, P1, or P2 differences remain for the approved refinement.
The outer pair is intentionally only partially visible at 390 px, and the
320 px layout intentionally retains only the selected topic and two neighbours.

## Verification

- Focused widget tests: passed, including exact Zoe/bubble and bubble/heading
  gaps, selected/resting sizes, circle spacing, settled and interpolated arc
  geometry, five/three-item responsiveness, label wrapping, bidirectional
  swiping, reduced motion, text scaling, and short-phone scrolling.
- Flutter analysis: passed with no issues.
- Rendered 390 × 844 visual capture: passed.
- Android debug APK build: passed.

final result: passed
