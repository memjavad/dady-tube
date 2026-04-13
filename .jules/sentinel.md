## 2026-03-27 - [Hardcoded PIN in Parental Gate]
**Vulnerability:** The parental gate used a hardcoded string ('1234') for verification, allowing any user (including children) to easily bypass the gate.
**Learning:** Hardcoded credentials on the client side are trivial to bypass and defeat the purpose of an authorization gate, especially for child-safety features.
**Prevention:** Implement dynamic challenges (e.g., randomized math problems) or secure, user-defined PINs stored securely to ensure the gate serves its intended protective function.

## 2024-04-09 - [URL Injection Vulnerability]
**Vulnerability:** URL injection vulnerability via unsanitized external IDs (e.g., `id` or `channelId`) when interpolating into URL strings for HTTP requests.
**Learning:** Even internal identifiers from third-party APIs can be manipulated if not explicitly encoded, potentially leading to malformed URLs or unintended request routing.
**Prevention:** Always wrap external or user-controlled input with `Uri.encodeComponent()` when constructing URLs via string interpolation to prevent injection attacks and ensure valid URI syntax.

## 2025-04-13 - [Insecure PRNG for Security Challenges]
**Vulnerability:** The application used `Random()`, a predictable pseudo-random number generator, for the `ParentalGate` math challenge generation.
**Learning:** `Random()` produces a predictable sequence of numbers, which could allow an attacker to bypass security challenges by predicting the next generated problem.
**Prevention:** Always use `Random.secure()` for security-sensitive operations, including client-side authorization gates, to ensure cryptographic unpredictability.
