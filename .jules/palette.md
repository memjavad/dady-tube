## 2024-05-18 - Missing ARIA/Semantic labels on icon-only buttons
**Learning:** Icon-only buttons (like `IconButton` without a tooltip or custom interactive widgets wrapping only an icon) provide no context to screen reader users, making the app inaccessible.
**Action:** Always provide a `tooltip` for `IconButton`s and use the `semanticLabel` property for custom widgets like `TactileButton` when they only contain an icon.
