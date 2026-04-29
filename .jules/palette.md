## 2026-04-05 - Custom Gesture Buttons Missing Accessibility
**Learning:** Custom interactive widgets (like `TactileButton` wrapping `GestureDetector`) acting as icon-only buttons do not have inherent semantic descriptions. Screen readers will focus them (if wrapped in `Semantics(button: true)`) but won't know what action they perform without a `semanticLabel` or `tooltip`.
**Action:** Always verify that icon-only instances of custom gesture buttons have a localized `semanticLabel` applied to their root `Semantics` node.

## 2024-04-07 - Contextual CTAs in Empty States and Icon-Only Semantic Labels
**Learning:** Empty states without direct calls-to-action increase navigation friction for users. Even if the text says "Go to Settings to add channels," users still have to find the settings button. Additionally, custom tactile buttons that wrap icons need explicit `semanticLabel`s for screen readers to identify them correctly, since they lack built-in accessible tooltips or text.
**Action:** Always provide direct call-to-action buttons in empty states that route the user to the solution path (e.g., Settings), even if there is an authorization gate. Also, ensure all icon-only interactive elements pass a `semanticLabel` or use native `IconButton` with `tooltip`.

## 2024-05-18 - [Add Semantic properties to custom gestures]
**Learning:** Custom interactive widgets (like `TactileButton` wrapped in `GestureDetector`) need explicit semantic markup (`Semantics(button: true)`) because screen readers otherwise won't announce them as interactive buttons or identify when they are disabled.
**Action:** When building custom tactile/animated buttons in Flutter, always wrap the base gesture detector in a `Semantics` widget, passing through `button: true`, the `semanticLabel`, and the `enabled` state based on the callback's nullability.

## 2026-03-27 - [Helpful Call-to-Action in Gated Empty States]
**Learning:** Empty states that only describe a problem (e.g., "Ask a parent to add channels in Settings") cause unnecessary navigation friction because they lack a direct solution path. Adding a direct Call-to-Action button that leads to the required Settings, even if it requires passing an authorization gate first, significantly improves the user experience by reducing the steps to resolution.
**Action:** Always provide contextual call-to-action buttons in empty states that route users directly to the solution, instead of just displaying text instructions.

## 2026-04-03 - Added missing tooltips to icon-only buttons
**Learning:** Icon-only buttons (like `IconButton` without text) lack inherent descriptions for screen readers. Using `tooltip` property natively provides semantic labeling for accessibility and adds hover tooltips for desktop/web contexts.
**Action:** Always provide a localized descriptive string using the `tooltip` property whenever an `IconButton` or icon-only widget is used.

## 2023-10-27 - Add semantics to custom tactile buttons
**Learning:** Found that custom highly interactive widgets like `TactileButton` often miss native semantic bindings because they compose raw `GestureDetector` instances. Screen readers skip them unless manually wrapped with a `Semantics` widget providing explicit `semanticLabel`.
**Action:** Next time building custom interactive components with `GestureDetector`, always ensure a `Semantics` wrapper is included, and expose a `semanticLabel` parameter for consumers to implement accessible touch targets.
