## 2025-05-18 - Tooltips for Icon-Only Buttons
**Learning:** Icon-only buttons (like `IconButton`) inherently lack text labels. Screen readers read nothing without a label. This application had several navigational and functional icon buttons without descriptive `tooltip`s.
**Action:** Always provide a localized `tooltip` value when using an `IconButton` to ensure full screen reader accessibility.