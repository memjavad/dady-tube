# DadyTube: Developer's Guide (Gemini.md)

## 🛠️ Project Philosophy: The Digital Sandbox

DadyTube isn't just a video player; it's a **safe playground**. Developers must prioritize "Tactile Depth" and "Soft Interaction". 

### 🎨 Design Rules (Strict Adherence Required)
- **Zero-Line Policy**: Never use `Border.all`. Use `BoxShadow` with light tonal colors or background shifts for separation.
- **Geometric Softness**: All corners > `32.0`. Circle shapes for small buttons. Use `StadiumBorder` for medium buttons.
- **Interactive Squish**: Every tappable element must wrap in an animation that scales to `0.95` on tap.
- **Tonal Layering**: 
    - *Base*: `background` (Soft Blush #FFF5F7)
    - *Mid*: `surfaceContainerLow` (Subtle pinkish off-white)
    - *Top*: `surface` (Pure white) for active cards.
    - *Accent*: `primary` (Elegance Rose #E91E63)
- **Glassmorphism Spec**: Use `GlassContainer` with `blur: 16` and `opacity: 0.6` for bottom-nav and overlays.
- **Micro-Animations**: Use staggered entry animations for lists (`Interval(0.0, 0.5)`).
- **Typography**: 
    - *Friendly*: `Plus Jakarta Sans` for headers.
    - *Legible*: `Be Vietnam Pro` for body text.

## 👥 Core Roles

### 1. The Playground Architect (Frontend/UI)
- Responsible for the custom `ThemeData` and `TactileWidget` library.
- Ensures every screen matches the "Nourishing" color palette.
- Implementation of glassmorphism effects and tonal layering.

### 2. The Safety Warden (Backend/Logic)
- YouTube API integration and video data cleansing.
- Implementation of the Parental Gate (PIN system).
- Local storage management for customized channel lists.

### 3. The Sensory Tester (QA)
- Verifies touch target sizes (minimum 48x48, preferably 64x64 for kids).
- Checks that typography transitions smoothly between "Friendly Hero" and "Legible Body".

## 🚀 Technical Stack
- **Framework**: Flutter
- **State Management**: Provider (Simple for this scope)
- **Storage**: Shared Preferences
- **Video Player**: `youtube_player_flutter`

## 🤖 MCP Intelligence
Our AI-driven workflow leverages specialized **Model Context Protocol (MCP)** servers to maintain code quality and design fidelity:

- **Dart/Flutter Specialist (`dart-mcp-server`)**: 
    - Always run `dart analyze` via MCP before committing changes.
    - Utilize `rip_grep_packages` to understand internal dependencies like `youtube_explode_dart`.
    - Use `hot_reload` for instant visual feedback during UI tweaking.
- **Design Guardian (`StitchMCP`)**:
    - Use to verify and apply the DadyTube design system tokens across new screens.
- **The Knowledge Vault (`google-developer-knowledge`)**:
    - Treat as the primary source of truth for official Flutter/Android documentation.
- **Decision Engine (`sequential-thinking`)**:
    - Mandatory for complex architectural changes, ensuring all edge cases (like offline-mode race conditions) are considered.

## 📦 Contribution Workflow
1. **Component First**: Build atoms in `lib/core/tactile_widgets.dart` before screens.
2. **Style Check**: Use the `DadyTubeTheme` exclusively. No hardcoded hex values in screens.
3. **Safety First**: Any destructive action (deleting a channel) MUST trigger the `ParentalGate`.

## 📈 Project Evolution

### 1. Changelog Tracking
The AI and developers must maintain `changelog.md` to track every version. Use the following format:
- `[vX.X.X] - YYYY-MM-DD`
- `Added`: New features.
- `Fixed`: Bug fixes and compilation errors.
- `Improved`: UI/UX refinements.

### 2. Roadmap Planning
Future goals are tracked in `roadmap.md`. Categorize by:
- `Short-term`: Immediate UI/UX and stability fixes.
- `Mid-term`: Backend scaling and new "Worlds".
- `Dream Sandbox`: Radical new features like AI-curated playlists.
