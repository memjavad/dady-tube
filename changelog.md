# DadyTube Changelog

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
