## 2026-03-27 - [Hardcoded PIN in Parental Gate]
**Vulnerability:** The parental gate used a hardcoded string ('1234') for verification, allowing any user (including children) to easily bypass the gate.
**Learning:** Hardcoded credentials on the client side are trivial to bypass and defeat the purpose of an authorization gate, especially for child-safety features.
**Prevention:** Implement dynamic challenges (e.g., randomized math problems) or secure, user-defined PINs stored securely to ensure the gate serves its intended protective function.
## 2024-05-24 - [Predictable Math Problem in Parental Gate]
**Vulnerability:** The parental gate used `Random()` to generate math problems, making the math problem answers predictable.
**Learning:** `Random()` in Dart generates a pseudo-random number sequence that is predictable, especially if the seed is known or can be guessed. This could allow a determined user to guess the answers to the math problems over time.
**Prevention:** Use `Random.secure()` when generating random numbers for security-sensitive operations like authentication challenges or parental gates to ensure unpredictability.
