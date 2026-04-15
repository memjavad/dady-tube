# Themes & Night Vision

DadyTube features **Progressive Dark Themes** and **Adaptive Night Vision** designed for any environment. The goal is to provide maximum eye comfort, whether it's daytime or late at night.

## For Parents/Users

### Progressive Dark Themes
DadyTube has four built-in, eye-soothing themes to choose from:
1. **Blush 🌸:** The classic, soft pink palette ideal for daytime use.
2. **Sunset 🌇:** Warmer, duskier tones perfect for the afternoon.
3. **Midnight 🌃:** Deep navy designed for nighttime co-ordination.
4. **Deep Space 🚀:** High-contrast pitch-black for total darkness.

**How to Change Themes:**
Navigate to **Settings > Experience** (after passing the Parental Gate) and select your preferred theme.

### Adaptive Night Vision (Blue Light Filter)
To prevent the disruption of sleep patterns, DadyTube employs a spectrum-shifting filter that actively blocks harmful blue light.

**How it works:**
* The filter automatically adjusts its intensity based on the time of day.
* As bedtime approaches, the screen will subtly shift to warmer colors (amber/red) to prepare children for sleep.
* The transition is multi-stage: Day, Evening, and Late Night.

---

## For Developers

### UI & UX Principles
DadyTube adheres strictly to a **"Digital Sandbox"** design philosophy.
* **Tonal Colors:** Use soft palettes (e.g., `#FFF5F7` for Blush backgrounds).
* **Zero-Line Policy:** Avoid harsh lines or borders (e.g., `Border.all`). Always use `BoxShadow` and `StadiumBorder`.
* **Soft Corners:** Corner radius should generally be > 32.0.
* **Tactility:** All tappable widgets (`TactileWidget` library) must scale to `0.95` on tap to feel responsive.

### Technical Implementation
* **State Management:** Themes and Night Vision settings are stored in `SharedPreferences` and managed via Provider (e.g., `ThemeService` or `ThemeSettingsProvider`).
* **Caching Settings:** When retrieving preferences from `SharedPreferences` inside providers, the instance should be cached as a private member (e.g., `_prefs`) to prevent repeated asynchronous calls.
* **Night Vision Rendering:** The Adaptive Blue Light filter is often implemented as an overlay widget (like an `IgnorePointer` with `ColorFiltered` or `BackdropFilter`) at the highest point of the widget tree (above `MaterialApp` or via an `OverlayEntry`).
