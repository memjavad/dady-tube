# DadyTube UI Polish Implementation

This document outlines the technical plan for enhancing the UI polish of DadyTube, focusing on creating a more magical, tactical, and nourishing experience for kids.

## Goal Description

The goal is to elevate the existing UI by introducing high-end visual effects and playful micro-animations that align with the "Digital Sandbox" and "Nourishing" philosophies. We will implement 3D tactile buttons, an "Aurora Sheen" for glassmorphism, staggered entry animations for the feed, and playful context-aware micro-interactions, all while strictly adhering to the **Zero-Line Policy** and **Geometric Softness** (>32.0 border radius).

## User Review Required

> [!IMPORTANT]
> **Performance Considerations**: Adding continuous animations (like the Aurora Sheen and Pulsing Bucket) uses CPU/GPU. We will implement these using lightweight `AnimationController` and `ShaderMask`/`LinearGradient` techniques, but they should be tested on low-end devices to ensure 60fps scrolling is maintained.
> 
> Please review the specific animation approaches below before we proceed.

## Proposed Changes

---

### **Core UI Atoms (The Design System)**

These changes will apply globally to any screen using our core widgets.

#### [MODIFY] `tactile_widgets.dart`
Location: `lib/core/tactile_widgets.dart`

**1. 3D Tactile Response in `TactileButton`**:
- Instead of a simple `ScaleTransition`, we will use an `AnimatedBuilder` with `Transform`.
- On `_onTapDown`, the widget will scale down (to 0.95 as before) and apply a slight 3D rotation using `Matrix4.identity()..setEntry(3, 2, 0.001)..rotateX(...)`.
- *Details*: To keep it smooth and not overly complex, we will apply a fixed gentle tilt inwards to simulate a physical, squishy button being pressed down.

**2. Aurora Sheen in `GlassContainer`**:
- Convert `GlassContainer` into a `StatefulWidget` with a repeating `AnimationController`.
- Update the internal `BoxDecoration`. Instead of a solid `Colors.white.withOpacity(opacity)`, we will use a `LinearGradient` sweeping across the container.
- The gradient stops or alignment will be animated to create a very slow, subtle "sheen" passing over the frosted glass surface.

---

### **Home Screen Elements**

#### [MODIFY] `home_screen.dart`
Location: `lib/screens/home_screen.dart`

**1. Staggered Entry Animations**:
- In `_buildBigImmersiveList`, instead of returning a naked `VideoCard` inside the `SliverChildBuilderDelegate`, we will wrap each `VideoCard` in a new widget called `StaggeredEntryCard`.
- `StaggeredEntryCard` will use a `TweenAnimationBuilder` to animate opacity (0 -> 1) and translation Y (50 -> 0) based on its `index` to create a "wave" effect when the feed loads.

**2. World Switching Particles Integration**:
- Connect the `_selectedWorld` state to the `ParticleBackground`.
- Example: If a user selects "Animals" (Orange), the background particles should smoothly shift from the primary DadyTube pink to orange.

---

### **Playful Micro-Interactions**

#### [MODIFY] `particle_background.dart`
Location: `lib/widgets/particle_background.dart`

- Add a new parameter `Color? overrideColor`.
- Update the `build` method. Use an `AnimatedTheme` or `TweenAnimationBuilder<Color?>` to smoothly transition the `particleColor` when `overrideColor` changes.

#### [MODIFY] `playtime_bucket.dart`
Location: `lib/widgets/playtime_bucket.dart`

- **The Playtime Pulse**:
- Wrap the main container in an `AnimatedBuilder` driven by a repeating, reversed `AnimationController`.
- The animation will only be active when `activeBars <= 3`. 
- When pulsing, the entire bucket will gently scale (e.g., 1.0 to 1.05) and increase its shadow intensity, creating a "breathing" effect that subtly warns the playtime is almost up.

#### [MODIFY] `shimmer_video_card.dart`
Location: `lib/widgets/shimmer_video_card.dart`

- Update the internal placeholder blocks. Instead of sharp `Colors.white` boxes, use rounded rectangles (Radius 32 for the thumbnail place, Radius 8 for texts) to match the **Geometric Softness** rule.
- Enhance the `baseColor` and `highlightColor` of `Shimmer.fromColors` to look more like our frosted glass rather than standard grey/white.

## Open Questions

> [!WARNING]
> 1. **Aurora Sheen Speed**: Should the sheen on the bottom nav bar be constantly moving, or only appear when a user interaction happens? (Constant looks more magical, but uses slightly more GPU). My plan assumes a continuous, very slow movement.
> 2. **3D Tilt calculation**: Should the `TactileButton` tilt towards the exact point of the user's touch (requires tracking local touch position), or just do a generic "sink" effect on press? I propose the generic sink/squish globally, as touch-tracking every button can be overkill.

## Verification Plan

### Manual Verification
- **Visuals**: Review the `GlassContainer` bottom nav bar in `HomeScreen` to see the Aurora Sheen effect.
- **Interactions**: Tap any `TactileButton` (like category channels or video cards) to ensure the 3D squish feels natural and has no clipping issues. 
- **Staggered Load**: Pull to refresh the `HomeScreen` to verify the feed videos slide up dynamically.
- **Pulsing Bucket**: Play a video until the bucket is almost empty (or mock the `UsageProvider` progress) to see the breathing effect.
- **Colors**: Click a world in the carousel and watch the background particles shift color.
