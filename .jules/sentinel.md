## 2026-03-27 - [Hardcoded PIN in Parental Gate]
**Vulnerability:** The parental gate used a hardcoded string ('1234') for verification, allowing any user (including children) to easily bypass the gate.
**Learning:** Hardcoded credentials on the client side are trivial to bypass and defeat the purpose of an authorization gate, especially for child-safety features.
**Prevention:** Implement dynamic challenges (e.g., randomized math problems) or secure, user-defined PINs stored securely to ensure the gate serves its intended protective function.

## 2026-04-10 - [URL Injection via Unescaped Identifiers]
**Vulnerability:** In `youtube_service.dart`, external identifiers (like `id` and `channelId`) were directly interpolated into URL strings (e.g., `https://www.youtube.com/channel/$id`) without URI encoding.
**Learning:** Failing to sanitize or URL-encode dynamically injected strings can allow attackers to perform URL injection, potentially bypassing routing logic, altering query parameters, or enabling Server-Side Request Forgery (SSRF) and path traversal if the inputs are influenced by users.
**Prevention:** Always wrap dynamically injected strings that form parts of a URL (paths or query parameters) with `Uri.encodeComponent()` to ensure they are strictly interpreted as data.