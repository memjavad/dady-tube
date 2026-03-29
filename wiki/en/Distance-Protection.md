# Distance Protection (Step Back!)

The **Distance Protection** feature (affectionately known as the "Step Back!" rabbit) is DadyTube's primary mechanism to prevent digital eye strain caused by children holding the device too close to their face.

## For Parents/Users

### How it Works
When enabled, DadyTube uses the device's front-facing camera to gauge the proximity of a child's face.
If the face occupies more than 55% of the frame (indicating the device is too close), the application will:
1. Immediately pause video playback.
2. Display a friendly, animated "Step Back!" rabbit on screen.
3. Keep the content paused until a safe viewing distance is restored.

### Privacy Guarantee
We understand that camera usage is sensitive. **All processing happens entirely on-device**. No images or video are ever stored on the device or transmitted over the internet.

### How to Enable
1. Tap the Settings icon and pass the Parental Gate (solve the math problem).
2. Navigate to the **Safety** tab.
3. Toggle on **Safe Distance Protection**.
4. You will be prompted to grant Camera Permissions. The feature requires this to function.

---

## For Developers

### Technical Implementation
Distance Protection relies on `Google ML Kit Face Detection`.

* **Service Location:** `lib/services/distance_protection_service.dart` (example path based on architecture rules).
* **Pattern:** The service runs as a Singleton that manages the camera stream and coordinates the ML logic.
* **Camera Handling:** The service subscribes to frames from the camera plugin and converts them to `InputImage` formats compatible with `google_mlkit_face_detection`.

### Testing & Mocking
Due to the dependency on the physical camera and ML Kit plugins, unit testing this service requires careful mocking.
* Use `mocktail` to mock `CameraImage` conversions to `InputImage`.
* **Crucial Tip:** When mocking `CameraImage` format properties, ensure `image.format.raw` is explicitly stubbed (e.g., `when(() => mockImageFormat.raw).thenReturn(35);`) to prevent crashes during test execution.
* For singleton testing, ensure that internal logic methods (like image processing) are annotated with `@visibleForTesting` so they can be tested independently of the live camera stream.

### Key Variables
* The threshold is currently set at **55%** of the frame bounding box. Adjustments to this value directly impact sensitivity.
