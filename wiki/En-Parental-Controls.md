# Parental Controls

The Parental Control suite ensures that DadyTube remains a safe, isolated "Digital Sandbox" customized to your family's needs.

## For Parents/Users

### The Parental Gate
To access the settings menu where changes can be made, a parent must pass the **Parental Gate**.
* When you tap the Settings gear icon, a dynamic mathematical puzzle will appear (e.g., "What is 8 x 4?").
* You must enter the correct answer to unlock the configuration screen. This ensures toddlers cannot accidentally alter restrictions.

### Daily Time Limits
You can enforce how long your child is permitted to use the app each day.
* In the **Experience** tab under Settings, you can configure the daily playtime from **5 minutes up to 120 minutes**.
* When the limit is reached, DadyTube will politely notify the child that playtime is over and lock further viewing for the day.

### World Discovery (Channel Management)
As a parent, you have the final say on what your child views.
* Use the **World Discovery** feature to curate content.
* You can easily add new, trusted YouTube channels or remove existing ones, ensuring that the app's library perfectly matches your child's age and interests.

---

## For Developers

### Technical Implementation

#### Dynamic Security Constraints
**Do not hardcode static PINs or passwords.** The Parental Gate operates by dynamically generating basic arithmetic problems (`ParentalGateService`). The logic compares the user's input against the mathematical solution to grant access.

#### Enforcing Time Limits
* `TimerService` coordinates with `SharedPreferences` to log the child's daily active usage.
* To avoid the UI freezing, time limit checks are usually executed efficiently via `Provider` listeners which trigger a lockdown overlay when the limit is reached.
* **Important Design Note:** Ensure that time calculations and rewards logic are protected against device clock manipulation where feasible.

#### World Discovery Management
* Channel URLs or IDs are managed via an internal Provider state list.
* To ensure data stability during discovery and loading, DadyTube validates RSS feeds from YouTube via `test_rss_audit.dart` or similar internal checks to guarantee the channels added are active, safe, and retrievable.
* Large lists of channels should not be evaluated via `O(N)` or `O(N log N)` sorts directly in the `build()` method to preserve the high 60fps frame rate constraint; instead, use memoization.
