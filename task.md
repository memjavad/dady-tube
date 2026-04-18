# DadyTube Implementation Tasks

## 📽️ Playback Stability & Resilience
- [x] Catch `VideoUnplayableException` in `VideoCacheService`
- [x] Prevent `ENOENT` in `VideoCacheService` with stricter file verification
- [x] Filter out Live Streams and Upcoming videos in `YoutubeService`
- [x] Implement `_buildRecoveryUI` in `WatchScreen` to catch initialization errors
- [x] Implement "Try Next Toy" navigation logic in `WatchScreen`
- [x] Update `ChannelProvider` with `getNextVideo` helper

## 🎨 UI Polish (GEMINI.md Adherence)
### Core UI Atoms (`tactile_widgets.dart`)
- [x] Refactor `TactileButton` for 3D tilt
- [x] Add Aurora Sheen to `GlassContainer`

### Home Screen Staggered Entry (`home_screen.dart`, `shimmer_video_card.dart`)
- [x] Create `StaggeredEntryCard` wrapper
- [x] Update `HomeScreen` lists to use staggered entry
- [x] Update `ShimmerVideoCard` for Geometry Softness and glass look

### Playful Micro-Interactions
- [x] Enhance `particle_background.dart` to support color transitions
- [x] Connect `HomeScreen` world selection to `ParticleBackground` color
- [x] Add pulsing logic to `PlaytimeBucket` on low time

## 🕸️ Network Footprint Reduction
- [x] Halve Cache Limits & Sync Frequencies (`video_cache_service.dart`)
- [x] Reduce Fetch & Pre-warming Batch Sizes (`channel_provider.dart`)
- [x] Update background sync interval logic

## 🖼️ Permanent Channel Avatar Caching
- [/] Update `YoutubeChannel` model & DB schema Migration
- [ ] Implement Avatar Persistence logic in `ChannelProvider`
- [ ] Update UI widgets to use local avatar paths
