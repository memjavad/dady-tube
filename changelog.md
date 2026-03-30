# DadyTube Changelog

## [v1.0.1] - 2026-03-31
- `Added`: SQLite Database support via `sqflite` and `DatabaseService` to manage active channels and persist the full video library locally.
- `Added`: Migration path to move off legacy SharedPreferences JSON-blob storage for better performance.
- `Improved`: Restructured `ChannelProvider` to rely on the background SQLite sync to solve app freezing issues during startup.
- `Improved`: Moved the Gentle Transition ('Breathe in') overlay from obstructing the entire screen down to just the 16:9 video player area on the Watch Screen to unblock user interaction with metadata and suggested videos immediately.
