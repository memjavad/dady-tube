## 2026-03-27 - [Hardcoded PIN in Parental Gate]
**Vulnerability:** The parental gate used a hardcoded string ('1234') for verification, allowing any user (including children) to easily bypass the gate.
**Learning:** Hardcoded credentials on the client side are trivial to bypass and defeat the purpose of an authorization gate, especially for child-safety features.
**Prevention:** Implement dynamic challenges (e.g., randomized math problems) or secure, user-defined PINs stored securely to ensure the gate serves its intended protective function.

## 2026-04-10 - [Predictable Math Problem in Parental Gate]
**Vulnerability:** The parental gate used a predictable random number generator (`Random()`), allowing potential predictability of math problems used for authorization.
**Learning:** `Random()` in Dart generates a predictable pseudo-random sequence. For security-sensitive features like authorization gates, even simple math challenges need to be unpredictable.
**Prevention:** Always use `Random.secure()` for generating numbers used in security challenges or authorization flows.
