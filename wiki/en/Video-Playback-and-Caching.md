# Video Playback & Caching

DadyTube delivers a premium viewing experience through custom caching systems that eliminate buffering, loading screens, and "spinning circles" often seen in standard apps.

## For Parents/Users

### Infinite Toy Box (Zero-Latency)
When a child taps a video, it plays **instantly**. DadyTube uses a background technology that pre-loads videos, allowing playback to begin in less than 100 milliseconds.
* There are no loading progress bars for returning users.
* High-resolution thumbnails are pre-warmed during the initial splash screen, so the app is immediately ready for interaction.

### Travel Mode (Offline Playback)
DadyTube is built to work anywhere, even without Wi-Fi.
* Parents can download content directly to the device for long car rides or flights.
* The system quietly handles updates and refreshes broken links automatically in the background, ensuring downloaded videos always work.

---

## For Developers

### Technical Architecture
The core video playback relies heavily on `youtube_player_flutter` and `video_player` packages, driven by data extracted via `youtube_explode_dart`.

### The Caching Engine
DadyTube utilizes a heavily optimized **VideoCacheService** to achieve its sub-100ms playback times.

1. **Persistent Metadata & Infinite Toy Box:**
   * The application aggressively caches YouTube URL resolutions (manifests) locally on disk. This enables instant boot times.
   * `youtube_explode_dart` is used to resolve URLs, but this expensive network call is bypassed if a valid cached link exists.

2. **Lazy-Refresh (Self-Healing Cache):**
   * Video stream links naturally expire. DadyTube's caching service caches these links for up to 30 days.
   * If a link fails (HTTP 403), the service automatically triggers a silent, non-blocking refresh to resolve a new stream URL without disrupting the UI.

3. **Zero-Latency Preview:**
   * The background service automatically buffers the first 5 seconds of the most popular videos on disk.

4. **Super-Turbo Performance Suite:**
   * During channel discovery, DadyTube utilizes a Parallel Discovery Engine (up to 12x concurrent fetches) to minimize startup times by 90%.

### Avoiding "Ghosting"
When integrating preview players with main video players, ensure that the preview controller is disposed of or paused correctly before transitioning to the `youtube_player_flutter` instance to prevent "Dual-Player Ghosting".