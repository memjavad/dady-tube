# Eye Yoga & Rewards

DadyTube encourages healthy screen habits by turning self-regulation into an interactive, gamified experience. The application enforces the internationally recommended "20-20-20 rule" and rewards children for their discipline.

## For Parents/Users

### Eye Yoga (The 20-20-20 Rule)
Prolonged screen time can cause "digital eye strain." To counteract this, DadyTube features automated **Eye Yoga**.

**How it works:**
1. After every 15-20 minutes of continuous playback, DadyTube automatically pauses the current video.
2. The app introduces a 3-stage Eye Yoga cycle:
   * **Look Far:** Focus on something 20 feet away for 20 seconds.
   * **Squeeze:** Close the eyes tightly.
   * **Reach/Blink:** Interactive blinking and stretching exercises.
3. Children follow along with the cute, animated on-screen guides.
4. Playback resumes automatically once the exercises are completed.

### Magic Stars Reward System
To prevent tantrums and encourage kids to put the device down voluntarily, DadyTube offers a **Magic Stars** system.

**Earning Stars:**
* For every **50 minutes of unused daily playtime** (based on the limits set in Parental Controls), a child earns **1 Magic Star**.
* **Interactive Star Field:** Earned stars are deposited into a dedicated tab. This acts as a physical sandbox where kids can tap the stars, count them, and see them bounce.
* By gamifying self-discipline, children associate putting the tablet away with positive reinforcement.

---

## For Developers

### Technical Implementation

* **Time Tracking:**
  * **Provider:** `TimerService` or `RewardProvider` tracks accumulated playback time.
  * **Storage:** Accumulated time and earned stars are persisted via `SharedPreferences`.

* **The 20-20-20 Interrupt:**
  * This requires a persistent timer that functions even when transitioning between routes.
  * When the 15-20 minute threshold is hit, the application pauses the active video controller (e.g., `youtube_player_flutter` controller) and pushes an opaque, non-dismissible `PageRoute` (the Eye Yoga screen).

* **Reward Logic:**
  * Magic Stars calculation must handle daily resets securely. Avoid hardcoded time checks on the client side without storing a timestamp.
  * The physics for the Star Field (bouncing stars) is built using custom `AnimationController` setups or a physics engine package if included in `pubspec.yaml`, ensuring all interactions scale to `0.95` on tap.