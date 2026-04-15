## 2026-04-05 - Custom Gesture Buttons Missing Accessibility
**Learning:** Custom interactive widgets (like `TactileButton` wrapping `GestureDetector`) acting as icon-only buttons do not have inherent semantic descriptions. Screen readers will focus them (if wrapped in `Semantics(button: true)`) but won't know what action they perform without a `semanticLabel` or `tooltip`.
**Action:** Always verify that icon-only instances of custom gesture buttons have a localized `semanticLabel` applied to their root `Semantics` node.

## 2024-04-07 - Contextual CTAs in Empty States and Icon-Only Semantic Labels
**Learning:** Empty states without direct calls-to-action increase navigation friction for users. Even if the text says "Go to Settings to add channels," users still have to find the settings button. Additionally, custom tactile buttons that wrap icons need explicit `semanticLabel`s for screen readers to identify them correctly, since they lack built-in accessible tooltips or text.
**Action:** Always provide direct call-to-action buttons in empty states that route the user to the solution path (e.g., Settings), even if there is an authorization gate. Also, ensure all icon-only interactive elements pass a `semanticLabel` or use native `IconButton` with `tooltip`.

## 2024-05-18 - [Add Semantic properties to custom gestures]
**Learning:** Custom interactive widgets (like `TactileButton` wrapped in `GestureDetector`) need explicit semantic markup (`Semantics(button: true)`) because screen readers otherwise won't announce them as interactive buttons or identify when they are disabled.
**Action:** When building custom tactile/animated buttons in Flutter, always wrap the base gesture detector in a `Semantics` widget, passing through `button: true`, the `semanticLabel`, and the `enabled` state based on the callback's nullability.
