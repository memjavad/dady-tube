## 2024-06-18 - Prevent URL Injection in YouTube Service
**Vulnerability:** Found multiple instances where dynamic unvalidated `id` and `channelId` variables were directly interpolated into string URLs inside `youtube_service.dart`. Malformed IDs could potentially manipulate URL paths or inject parameters.
**Learning:** External variables originating from user input or database records should not be blindly trusted and directly interpolated into base URLs.
**Prevention:** Always wrap variables that act as URL parameters or path segments with `Uri.encodeComponent(variable)` to properly encode special characters (e.g., `?`, `&`, `/`) and neutralize potential URL injection attacks.
