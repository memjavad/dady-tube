## 2026-04-15 - Optimize ChannelProvider.getVideoById
**Learning:** O(N*M) lookups inside getter methods (`getVideoById`) traversing large collections like `_channelVideos` can be heavily optimized using a lazily-evaluated flattened Map cache, turning lookups into O(1).
**Action:** Always maintain or lazily compute Map representations for collections that are queried by ID frequently, and invalidate them properly alongside other caches.
