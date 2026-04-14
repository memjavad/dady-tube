## 2026-03-27 - [Hardcoded PIN in Parental Gate]
**Vulnerability:** The parental gate used a hardcoded string ('1234') for verification, allowing any user (including children) to easily bypass the gate.
**Learning:** Hardcoded credentials on the client side are trivial to bypass and defeat the purpose of an authorization gate, especially for child-safety features.
**Prevention:** Implement dynamic challenges (e.g., randomized math problems) or secure, user-defined PINs stored securely to ensure the gate serves its intended protective function.

## 2024-04-09 - [URL Injection Vulnerability]
**Vulnerability:** URL injection vulnerability via unsanitized external IDs (e.g., `id` or `channelId`) when interpolating into URL strings for HTTP requests.
**Learning:** Even internal identifiers from third-party APIs can be manipulated if not explicitly encoded, potentially leading to malformed URLs or unintended request routing.
**Prevention:** Always wrap external or user-controlled input with `Uri.encodeComponent()` when constructing URLs via string interpolation to prevent injection attacks and ensure valid URI syntax.

## 2024-05-24 - [URL Injection Vulnerability]
**Vulnerability:** URL string interpolation used user-controlled parameters (`channelId` and `id`) to construct HTTP request URLs directly, potentially allowing URL injection.
**Learning:** String interpolation for URLs exposes services to injection vulnerabilities where crafted user input might add query parameters or manipulate URL paths to induce unintended requests (SSRF risk).
**Prevention:** Always use `Uri.encodeComponent()` when building URLs manually to sanitize any external input.

## 2026-04-10 - [Predictable Math Problem in Parental Gate]
**Vulnerability:** The parental gate used a predictable random number generator (`Random()`), allowing potential predictability of math problems used for authorization.
**Learning:** `Random()` in Dart generates a predictable pseudo-random sequence. For security-sensitive features like authorization gates, even simple math challenges need to be unpredictable.
**Prevention:** Always use `Random.secure()` for generating numbers used in security challenges or authorization flows.
