🎯 **What:**
Added unit tests for the `YoutubeClientService` singleton to verify its core behaviors, addressing a testing gap.

📊 **Coverage:**
The new tests cover the following scenarios:
* Verify that multiple instantiations of `YoutubeClientService` return the exact same instance (singleton pattern).
* Verify that the internal clients (`client` and `httpClient`) are correctly exposed and have the expected types.
* Verify that calling the `dispose` method completes without throwing any exceptions.

✨ **Result:**
Test coverage for `lib/services/youtube_client_service.dart` is improved, ensuring the singleton pattern remains intact and the dispose behavior is safe, which improves the overall reliability of the codebase.
