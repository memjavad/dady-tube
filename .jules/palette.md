## 2026-04-03 - Added Accessibility Tooltips to Icon-Only Buttons
**Learning:** Icon-only buttons (like `IconButton`) in Flutter do not provide contextual meaning to screen readers or users on their own. Adding the `tooltip` parameter is essential for accessibility. The tooltip not only creates an on-hover label (where applicable) but is also read by screen readers (similar to a `semanticLabel`).
**Action:** Always add the `tooltip` property to any icon-only button like `IconButton` to improve app accessibility and overall UX.
