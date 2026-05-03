🎯 **What:**
Removed unreachable dead code in `lib/screens/watch_screen.dart` checking if `streamInfo` is null. The type of `streamInfo` was also updated to be strictly non-nullable.

💡 **Why:**
The `withHighestBitrate()` extension method from `youtube_explode_dart` is guaranteed to return a non-nullable `StreamInfo` object (it internally throws a `StateError` if the iterable is empty). The nullable declaration and the `if (streamInfo == null)` condition were therefore unreachable and marked as dead code, creating unnecessary complexity. Removing this dead code improves readability and maintainability.

✅ **Verification:**
1. Ran `dart analyze lib/screens/watch_screen.dart` to verify no static analysis errors or warnings regarding `streamInfo` remained.
2. Verified the file diff to ensure no unexpected changes were included.
3. Ran the full Flutter test suite to confirm the changes did not break any existing functionality.

✨ **Result:**
The `streamInfo == null` check is completely removed, eliminating the dead code warning, simplifying the control flow, and keeping the codebase clean.
