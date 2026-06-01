# DadyTube Roadmap

## Short-term
- **Design System Polish**: Remove remaining `Border.all` occurrences to achieve 100% Zero-Line Policy compliance. Rely purely on tonal shifts and soft `BoxShadow` layering.
- **Dynamic Aurora Sheen**: Upgrade static glassmorphism in `GlassContainer` with a hardware-accelerated sweeping reflection gradient animation.
- **SQLite Performance**: Add composite indexes on `channelId` and `publishedAt` columns in the `videos` table to avoid linear full table scans on startup.
- **Profile-Level Safe Limits**: Separate bedtime, screen-time caps, and volume controls by kid-profile instead of global shared settings.

## Mid-term
- **Background Content Synchronization**: Throttled temporal background synchronizer using WorkManager/BackgroundFetch to update feeds without waking up CPU excessively.
- **Enhanced Proximity Detection**: Optimize Front-Facing Camera sensor processing in `DistanceProtectionService` to scale up frame duration dynamically when safe, saving battery.
- **Parent-facing Interactive Logs**: Render visual statistics showing distance violations, neck posture trends, and exact blocked-keyword attempts.

## Dream Sandbox
- **AI-Curated Safe Playlists**: Local semantic search mapping kid's cognitive progress to custom-generated YouTube video playlists.
- **Peer-to-Peer Safe Sharing**: Direct local-network sharing of parental configurations and custom channel lists via offline cryptographic handshake.
