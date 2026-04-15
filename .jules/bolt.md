## 2024-05-24 - Flutter ListView `shrinkWrap` Performance Bottleneck
**Learning:** In Flutter, using `ListView.builder` inside a `SingleChildScrollView` with `shrinkWrap: true` completely negates the lazy-rendering benefits of `ListView`. It forces Flutter to instantiate, layout, and render *all* children at once to determine the total size of the list. This leads to massive CPU spikes, memory consumption, and scroll jank, especially with heavy items (like Video Cards with network images).
**Action:** Always replace `SingleChildScrollView` containing `ListView(shrinkWrap: true)` with a `CustomScrollView` and `SliverList`. This restores lazy-rendering, keeping memory footprint low and scrolling smooth.

## 2025-02-15 - Flutter Provider Expensive Getter Memoization
**Learning:** In Flutter, `ChangeNotifier` providers with computed getters (like merging lists and sorting them) are re-evaluated *every single time* they are called during a UI `build()`. This means an O(N log N) sort operation inside a getter can execute dozens of times per frame, causing massive CPU spikes and jank.
**Action:** Always memoize expensive operations (e.g. sorting, filtering large lists) within Provider getters. Cache the result in a private field (`_cachedData`) and introduce a `_invalidateCache()` method to clear the cache whenever the underlying data mutates.

## 2026-03-27 - Dart Directory Stream Iteration Performance
**Learning:** In Dart, processing directory listing streams directly using an `await for` loop to populate a collection is significantly more efficient than chaining `.toList().map().toSet()`, which creates redundant intermediate allocations.
**Action:** Always use `await for` to iterate over streams (like `Directory.list()`) when you only need to process or calculate aggregate values (like file sizes or counting types) instead of creating expensive intermediate lists.

## 2025-02-15 - Dart Collection Partitioning Bottleneck
**Learning:** In Dart, partitioning a single list into two collections (e.g., separating videos by title content) using multiple `.where()` passes combined with `.contains()` creates an O(N²) execution pattern. This causes severe CPU spikes and blocks the main UI thread during build cycles, especially when called inside Provider getters or widget `build()` methods.
**Action:** Always use a single-pass O(N) `for` loop to iterate through the collection once and append items to their respective lists based on the condition.

## 2026-04-20 - Redundant String Transformation in Filtering
**Learning:** In Dart, calling `.toLowerCase()` or similar string transformations inside a `.where()` loop causes redundant memory allocations and CPU overhead for every item in the collection, leading to performance degradation, especially with large datasets inside a Provider's getter.
**Action:** Always extract and cache the string transformation (e.g., `final searchTerm = input.toLowerCase();`) outside the loop or filtering operation to ensure it is only computed once.

## 2026-04-20 - Inefficient Filename Extraction
**Learning:** In Dart, extracting a filename without its extension by chaining `.split(Platform.pathSeparator).last` and `.replaceAll('.mp4', '')` creates unnecessary intermediate `List` and `String` allocations, degrading performance when processing large numbers of files (like reading cache directory contents).
**Action:** Always use the `path` package's `basenameWithoutExtension` method (e.g., `path.basenameWithoutExtension(file.path)`), which is significantly more efficient and avoids redundant allocations.
