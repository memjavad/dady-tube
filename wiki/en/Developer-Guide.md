# Developer Guide

Welcome to the DadyTube Developer Guide. This document provides an overview of the architecture, coding standards, and testing strategies required to contribute to the project.

## Architecture & Tech Stack

DadyTube is built using **Flutter** and **Dart**. The project follows a strict architectural pattern separating UI, State Management, and Business Logic.

### Key Technologies
* **Framework:** Flutter (Android & iOS). Target Dart SDK `3.11.0`.
* **State Management:** Provider (`lib/providers/`).
* **Business Logic:** Services (`lib/services/`).
* **Storage:** `SharedPreferences` for local persistence.
* **Video/Networking:** `youtube_player_flutter`, `video_player`, and `youtube_explode_dart`.
* **AI/ML:** Google ML Kit for on-device face detection.

## Directory Structure
* `lib/providers/` - Contains state management classes extending `ChangeNotifier`.
* `lib/services/` - Contains singleton business logic classes (e.g., `VideoCacheService`, `DistanceProtectionService`).
* `lib/ui/` or `lib/widgets/` - Contains the "Digital Sandbox" UI components (e.g., `TactileWidget`).

## Coding Standards & Performance

### The "Digital Sandbox" Rules
Every UI element in DadyTube must feel soft and tactile:
1. **No harsh lines:** Never use `Border.all`. Use `BoxShadow` to create depth.
2. **Soft corners:** `BorderRadius` must generally be > `32.0`.
3. **Tactility:** Tappable elements must scale to `0.95` on tap.
4. **Colors:** Use tonal, soft palettes (e.g., `#FFF5F7` for backgrounds).

### Performance Optimization
* **Caching:** Heavy computations (like sorting large video arrays) must be memoized in Providers to avoid `O(N log N)` execution on every build cycle.
* **SharedPreferences:** Cache the instance as a private member (e.g., `_prefs`) after the first retrieval to prevent redundant asynchronous calls and event-loop yields.
* **Lists:** Never use `ListView.builder` with `shrinkWrap: true` inside a `SingleChildScrollView`. Always use `CustomScrollView` with `SliverList` for large lists to maintain 60fps.
* **Logging:** Use `debugPrint` from `package:flutter/foundation.dart` instead of standard `print()`.

<<<<<<< HEAD
### Performance & Stability Patterns

1. **Mounted Guard Policy**: All asynchronous callbacks that use `setState()` must be guarded by an `if (mounted)` check at the earliest possible entry point to prevent "defunct" state access crashes and memory leaks.
2. **Background Task Latching**: When performing resource-intensive operations like video playback, call `_cacheService.pauseBackgroundOperations()` to yield device resources. Ensure these are resumed in `dispose()` or after a successful initialization.
3. **Synchronization Limits**: To maintain sub-200ms startup times, keep the local video metadata library lean. Enforce hard limits (e.g., 100 most recent videos per channel) in synchronization loops.

=======
>>>>>>> origin/wiki-documentation-14288008560723314119
### Security
* **Sanitization:** Always sanitize external inputs, especially YouTube video IDs, using an allowlist approach (e.g., `id.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '')`) before using them to construct local file paths to prevent path traversal vulnerabilities.
* **Image Paths:** Avoid absolute system file paths for local assets; always use `Image.asset` with relative paths defined in `pubspec.yaml` (e.g., `- assets/images/`).

## Testing Strategies

DadyTube uses `mocktail` for mocking dependencies. Run tests using `flutter test`.

### Dependency Injection
When building Services or Providers, use optional parameters in the constructor to allow injecting mocks during testing without breaking backward compatibility.
```dart
class MyService {
  final ApiClient _apiClient;
  MyService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();
}
```

### Mocking Specifics
* **Platform Channels:** To natively mock platform channels (`EventChannel` or `MethodChannel`), use `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler` with `MockStreamHandler.inline`.
* **Private Methods:** Use `@visibleForTesting` to expose internal logic (like image processing) in Singleton services so they can be unit-tested without instantiating the full service lifecycle.
* **Build Runner:** After adding `@GenerateMocks`, remember to run:
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```

## Working as "Bolt"
If you are performing performance optimization under the "Bolt" persona:
1. Document the optimization impact with inline comments.
2. Run `flutter analyze` and `flutter test` before submitting a PR.
3. Log critical architectural learnings in `.jules/bolt.md` using the format:
   ```markdown
   ## YYYY-MM-DD - [Title]
   **Learning:** [Insight]
   **Action:** [How to apply next time]
   ```