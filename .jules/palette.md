## 2026-04-05 - Custom Gesture Buttons Missing Accessibility
**Learning:** Custom interactive widgets (like `TactileButton` wrapping `GestureDetector`) acting as icon-only buttons do not have inherent semantic descriptions. Screen readers will focus them (if wrapped in `Semantics(button: true)`) but won't know what action they perform without a `semanticLabel` or `tooltip`.
**Action:** Always verify that icon-only instances of custom gesture buttons have a localized `semanticLabel` applied to their root `Semantics` node.
