# DadyTube Changelog

## [v3.9.0] - 2026-06-02
- `Added`: **Smart Night Sync (3 AM background worker)**. Runs headlessly via WorkManager constrained to WiFi and Charging, fetching and caching the latest 2 videos per channel to ensure offline preparedness.
- `Added`: **Curated Channel Pruning**. Automatically enforces a maximum footprint of 10 cached videos per channel, grouping locally stored media via sidecar metadata and pruning oldest entries during nightly sync.
- `Added`: **Startup Playback Warming**. Resolves and caches stream URLs for top videos once during Splash loader, showing interactive Iraq-Arabic and English localization. Tapping a video starts playback instantly with zero programmatic delay.
- `Improved`: **Interactive Quiet Mode**. Completely silenced all network-heavy pre-warming lookups, scrolling pre-fetches, and watch-time downloads during active child play, minimizing API hits and eliminating YouTube bot detection triggers.

## [v3.8.0] - 2026-06-01
- `Fixed`: **Zero-Line Policy Compliance**. Removed all 6 remaining `Border.all` violations across `TactileCard`, `GlassContainer`, `HomeScreen` nav, `SplashScreen` logo/progress, and `WatchScreen` controls. All separation now uses tonal `BoxShadow` edge glow.
- `Added`: **Dynamic Aurora Glassmorphism**. Upgraded `GlassContainer` from a static gradient to a continuously sweeping animated sheen, simulating dynamic room-light reflection on glass surfaces.
- `Added`: **Parent Master PIN**. Parents can now set a custom numeric PIN as a fast alternative to math challenges in the Parental Gate. Toggle between math and PIN modes with a single tap. Localized in English and Arabic.
- `Improved`: **SQLite Query Performance**. Added composite index `idx_videos_channel_date` on `videos(channelId, publishedAt DESC)` with migration path (DB v2 → v3), eliminating O(N) full table scans during video list rendering.

## [v3.7.0] - 2026-04-20
- `Added`: **Mandatory Periodic Breaks (Eye Yoga)**. Implemented 30-second eye-health breaks every 15 minutes to encourage healthy viewing habits.
- `Added`: **Auto-Orientation Control**. The app now automatically enters full-screen mode when the device is rotated to landscape and exits when returned to portrait.
- `Improved`: **Interactive Posture Layering**. Re-engineered playback controls to ensure touch responsiveness while maintaining the tap-to-show/hide gesture system.
- `Improved`: **Visual Polish**. Refined typography tracking and button hit targets for better ergonomics in both landscape and portrait modes.
- `Fixed`: Resolved playback control conflict where the "auto-resume" feature for breaks was causing manual pauses to fail.

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
- `Fixed`: Corrected **Posture Protection** ("Sit up straight!") logic to eliminate false positives in Landscape mode and properly detect Text Neck using semantic head pitch.

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
