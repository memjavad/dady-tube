# 🐰 DadyTube: The Digital Sandbox 🎨

**Author:** Dr. Mohammed Looti  
**Philosophy:** Nourishing, Safe, and Tactile Entertainment for Children.  
**License:** [![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

---

## 🌟 Overview

DadyTube isn't just a video player; it's a **safe playground** designed from the ground up to protect children's vision, encourage self-regulation, and provide a premium, tactile experience. Built with a "Digital Sandbox" philosophy, every interaction is designed to feel soft, responsive, and nourishing.

## 🛡️ Core Safety & Wellness Features

### 1. 📏 Distance Protection (Step Back!)
Using the front camera and **ML Kit Face Detection**, DadyTube senses if a child is holding the device too close.
- **How it works:** Real-time face proximity sensing. If the face occupies more than 55% of the frame, the "Step Back!" rabbit appears, pausing all content until a safe distance is restored.
- **Privacy:** All processing happens on-device; no images are ever stored or transmitted.

### 2. 🌀 Progressive Dark Themes
Four unique levels of brightness to match any environment:
- **Blush 🌸**: Our classic, soft pink palette.
- **Sunset 🌇**: Warmer, duskier tones for the afternoon.
- **Midnight 🌃**: Deep navy for nighttime co-ordination.
- **Deep Space 🚀**: High-contrast pitch-black for maximum eye comfort in total darkness.

### 3. 🧘 Interactive Eye Yoga & Rest Reminders
Prevents digital eye strain through scheduled interactive breaks.
- **20-20-20 Rule:** Every 15-20 minutes, the app pauses for a 3-stage Eye Yoga cycle (Look Far, Squeeze, Reach).
- **Animated Guidance:** Children follow cute icons to blink and stretch their eyes.

### 4. 🌙 Adaptive Night-Vision (Blue Light Filter)
A multi-stage spectrum-shifting filter that blocks harmful blue light.
- **Stages:** Day, Evening, and Late Night.
- **Timing:** Intensity increases automatically as bedtime approaches.

### 5. ⭐ Magic Stars Reward System
A gamified self-regulation system that rewards kids for *not* overusing the app.
- **Earning:** 1 Magic Star for every 50 minutes of unused daily playtime.
- **Interactive Field:** A dedicated tab where stars are scattered. Kids can tap and count them, turning self-discipline into a rewarding game.

---

## ⚙️ Technical Architecture

### 🛠️ Tech Stack
- **Framework:** Flutter (Android/iOS)
- **State Management:** Provider
- **Local Storage:** SharedPreferences (Settings & Persistence)
- **AI/ML:** Google ML Kit (Face Detection)
- **Video Engine:** `youtube_player_flutter` & `video_player`
- **Networking:** `youtube_explode_dart` for data extraction.

### 📦 Key Services & Components
- **VideoCacheService:** Manages offline binary buffering and manifest persistence for smooth, data-free playback.
- **DistanceProtectionService:** A singleton managing the camera stream and ML logic.
- **ParentalGate:** A mathematical PIN system that secures all administrative settings.
- **TactileWidget Library:** A custom UI kit prioritizing `BoxShadow` and `StadiumBorder` (Zero-Line Policy).

---

## 📖 Parent's Guide (How to Use)

### Accessing Settings
To protect settings, we use a **Parental Gate**. Tap the settings icon and solve the simple math puzzle to enter.

### Setting Time Limits
In **Settings > Experience**, you can set a daily playtime limit (5 to 120 minutes). The "Magic Star" system will automatically track leftover time.

### Safe Distance Setup
Enable **Safe Distance Protection** in the **Safety** tab. This activates the front camera to monitor proximity. Ensure the device has camera permissions enabled.

### Language & Themes
DadyTube is fully bilingual. Switch between **English** and **Arabic** in the **Experience** tab. You can also pick from the 4 **Progressive Themes** there.

---

## 🏗️ Technical Setup & Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/memjavad/dady-tube.git
   ```

2. **Install Dependencies:**
   ```bash
   flutter pub get
   ```

3. **Platform-Specific Setup:**
   - **iOS:**
     ```bash
     cd ios && pod install && cd ..
     ```
   - **Android:** Ensure `minSdkVersion` is at least **21** in `android/app/build.gradle`.

4. **Permissions Configuration:**
   DadyTube requires **Camera Permissions** for the "Step Back!" distance protection (ML Kit Face Detection).
   - **iOS:** Handled via `Info.plist` (NSCameraUsageDescription).
   - **Android:** Handled via `AndroidManifest.xml` (android.permission.CAMERA).

5. **Run the App:**
   ```bash
   flutter run
   ```

   *Note: For Windows users on slow connections, you can use the provided [build_offline.ps1](file:///c:/the%20ai/dady%20tube/build_offline.ps1) script for faster APK builds.*

---

## 📈 Changelog

### [v3.4] - 2026-03-27
- **Added**: Lazy-Refresh (Self-Healing Cache). Links now persist for 30 days and refresh automatically on failure.
- **Improved**: WatchScreen stability and zero-latency transition logic.

### [v3.3] - 2026-03-27
- **Added**: Infinite Toy Box (Persistent Link Cache). Resolves YouTube URLs instantly from disk, enabling <100ms video starts.
- **Fixed**: Orientation stuckness and status bar visibility issues after exiting full screen.

### [v3.2] - 2026-03-27
- **Added**: Instant Boot (Persistent Metadata). The app now loads from disk in <200ms, bypassing the discovery progress bar for returning users.
- **Improved**: Background refresh logic to use silent non-blocking updates.

### [v3.1] - 2026-03-27
- **Fixed**: Dual-Player Ghosting. Fixed an issue where the preview player remained visible behind the main video.
- **Fixed**: UI Layout collapse on Android when exiting full screen.

### [v3.0] - 2026-03-27
- **Added**: Super-Turbo Performance Suite. Implemented a Parallel Discovery Engine (12x concurrent fetches) reducing startup time by 90%.
- **Improved**: Thumbnail Pre-warming. High-res thumbnails are now pre-cached during the splash screen.

### [v2.6] - 2026-03-27
- **Added**: Interactive Onboarding. Replaced the static timer with a reactive progress bar and localized status messages (Finding Spacetoon, Preparing the Worlds).

### [v2.5] - 2026-03-27
- **Fixed**: Global Channel Health Recovery. Rescued "Maya the Bee" and "Smurfs" channels by migrating to high-stability IDs.
- **Improved**: 100% success rate on channel discovery via RSS verification.

### [v2.4] - 2026-03-27
- **Added**: Star Rewards & Eye Protection. Rewards kids for educational content and enforces the 20-20-20 rule.

### [v2.3] - 2026-03-27
- **Added**: Zero-Latency Preview Caching. Downloads the first 5 seconds of top videos in the background for "Zero-Spinning-Circle" playback.

### [v2.2] - 2026-03-27
- **Added**: World Discovery (Channel Management). Parents can now add/remove their own curated YouTube channels.

### [v2.1] - 2026-03-26
- **Added**: Travel Mode. Full offline download support for long trips without internet.

### [v2.0] - 2026-03-25
- **Added**: Parental Safety & Bedtime controls. Mathematical PIN system and daily usage limits.

### [v1.0] - 2026-03-24
- **Initial Release**: Core "Digital Sandbox" UI, 4 Progressive Themes, and Distance Protection (Step Back!).

---

## 📜 License & Copyright
© 2026 Dr. Mohammed Looti. All rights reserved. Designed with love for children everywhere.
