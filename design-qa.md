# Topic card design QA

- Source: `/private/tmp/ella-topic-grid-current.png`
- Implementation: `ella_app/lib/screens/child_view/all_topics_screen.dart` and `ella_app/lib/screens/child_view/widgets/topic_icon.dart`
- Viewport: connected Android phone, 1080 × 2340 physical pixels
- State: See More topic grid with four backend-provided topics
- Comparison: `/private/tmp/ella-topic-grid-comparison.png`

## Result

Passed on 2026-07-10. The updated cards are visibly shorter, retain the three-column layout, and keep the icon/label stack centered. The previous split label and `BOTTOM OVERFLOWED BY 3.0 PIXELS` indicators are absent. The home-screen semantics tree also confirms the revised prompt: “Not this topic. Pick your own.”
