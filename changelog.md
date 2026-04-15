# DadyTube Changelog

## [v3.6.0] - 2026-04-15
- `Added`: Full reconciliation and unification of over 40 feature, security, and performance branches into the main codebase.
- `Added`: Modernized GitHub Wiki with a flattened, language-aware navigation system (En/Ar supporting).
- `Improved`: **Dependency Overhaul**: 
    - Migrated Android camera layer to **CameraX** (via `camera` 0.12.x) for rock-solid stability in Distance Protection.
    - Upgraded core video engine to `youtube_explode_dart` 3.0.x for mission-critical metadata parsing.
    - Updated audio playback to `just_audio` 0.10.x with enhanced error-stream handling.
- `Improved`: **Accessibility (Palette)**: Standardized semantic labels, tooltips, and localized CTAs for Screen Reader compliance across all screens.
- `Improved`: **Security (Sentinel)**: Hardened the app against path traversal and URL injection in the `VideoCacheService`.
- `Improved`: **Performance (Bolt)**: Optimized `DatabaseService` with concurrent queries and implemented `IOSink.flush()` to prevent cache corruption during parallel downloads.
- `Fixed`: Resolved complex resource conflicts and premature class termination bugs during the master reconciliation.

## [v3.5] - 2026-04-01
- `Added`: Background Operation Latching system to prioritize 100% device resources for video playback.
- `Added`: Strict 100-video synchronization limit per channel to prevent database bloat and ensure fast boot.
- `Fixed`: Resolved critical memory leaks and `setState() after dispose` crashes in `WatchScreen` via standardized `mounted` guards.
- `Improved`: Optimized Eye Protection text and Statistics Tab layout for better premium experience on mixed device screen sizes.

## [v1.0.1] - 2026-03-31
- `Added`: SQLite Database support via `sqflite` and `DatabaseService` to manage active channels and persist the full video library locally.
- `Added`: Migration path to move off legacy SharedPreferences JSON-blob storage for better performance.
- `Improved`: Restructured `ChannelProvider` to rely on the background SQLite sync to solve app freezing issues during startup.
- `Improved`: Moved the Gentle Transition ('Breathe in') overlay from obstructing the entire screen down to just the 16:9 video player area on the Watch Screen to unblock user interaction with metadata and suggested videos immediately.
