import subprocess
import sys

title = "🧹 [code health] Remove unused key parameter in _PulseCloud"
description = """🎯 **What:** Removed the unused `key` parameter from the `_PulseCloud` private widget constructor in `lib/screens/watch_screen.dart`.

💡 **Why:** Standard codebase cleanup to remove unused dead code constructor parameters, improving overall readability and code health.

✅ **Verification:** Ran `flutter analyze` and `flutter test` to ensure no functionality is broken and that no new linting errors were introduced.

✨ **Result:** A slightly cleaner and more maintainable `watch_screen.dart` file without unused widget parameters."""

with open('pr_body.txt', 'w') as f:
    f.write(title + "\n\n" + description)
