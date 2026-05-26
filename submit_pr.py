from default_api import submit

title = "🧹 Remove unused showImmersive variable"
description = """🎯 **What:** Removed the unused local variable `showImmersive` from the `build` method in `lib/screens/watch_screen.dart`.

💡 **Why:** The variable was declared but never used in the build method. Removing dead calculations slightly improves code readability and marginally benefits performance by skipping an unnecessary condition evaluation.

✅ **Verification:**
- Verified by running `flutter analyze lib/screens/watch_screen.dart`, ensuring no related errors exist.
- Executed `flutter test` to ensure overall app integrity is preserved.
- Code review was successfully requested and passed.

✨ **Result:** A cleaner `build` method with slightly reduced cognitive load and dead code eliminated.
"""

submit(branch_name="remove-unused-showimmersive", commit_message=title, pr_title=title, pr_body=description)
