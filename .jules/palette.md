## 2024-04-03 - Tooltips on Icon-Only Buttons for A11y
**Learning:** Icon-only buttons (like `IconButton`) in Flutter are inaccessible to screen readers without explicitly providing a `tooltip` parameter. They default to being unannounced, leaving visually impaired users guessing their function.
**Action:** Always provide localized `tooltip` strings (or `semanticLabel`s for custom widgets) for any `IconButton` or purely visual interactive elements across the application to ensure they are read out by accessibility services and present hover text for mouse users.
