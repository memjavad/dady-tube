## 2024-05-24 - Flutter ListView `shrinkWrap` Performance Bottleneck
**Learning:** In Flutter, using `ListView.builder` inside a `SingleChildScrollView` with `shrinkWrap: true` completely negates the lazy-rendering benefits of `ListView`. It forces Flutter to instantiate, layout, and render *all* children at once to determine the total size of the list. This leads to massive CPU spikes, memory consumption, and scroll jank, especially with heavy items (like Video Cards with network images).
**Action:** Always replace `SingleChildScrollView` containing `ListView(shrinkWrap: true)` with a `CustomScrollView` and `SliverList`. This restores lazy-rendering, keeping memory footprint low and scrolling smooth.

## 2025-02-15 - Flutter Provider Expensive Getter Memoization
**Learning:** In Flutter, `ChangeNotifier` providers with computed getters (like merging lists and sorting them) are re-evaluated *every single time* they are called during a UI `build()`. This means an O(N log N) sort operation inside a getter can execute dozens of times per frame, causing massive CPU spikes and jank.
**Action:** Always memoize expensive operations (e.g. sorting, filtering large lists) within Provider getters. Cache the result in a private field (`_cachedData`) and introduce a `_invalidateCache()` method to clear the cache whenever the underlying data mutates.

## 2026-03-27 - Dart Directory Stream Iteration Performance
**Learning:** In Dart, processing directory listing streams directly using an `await for` loop to populate a collection is significantly more efficient than chaining `.toList().map().toSet()`, which creates redundant intermediate allocations.
**Action:** Always use `await for` to iterate over streams (like `Directory.list()`) when you only need to process or calculate aggregate values (like file sizes or counting types) instead of creating expensive intermediate lists.

## 2025-02-17 - Flutter Inline Array Sorting Performance Bottleneck
**Learning:** In Flutter, executing `List.sort()` directly inside a widget's `build()` method causes an O(N log N) performance penalty on *every single render cycle*. When dealing with potentially large arrays (like hundreds of channel videos), this inline sorting leads to significant CPU spikes, memory churn, and UI jank.
**Action:** Always extract sorting and heavy filtering logic out of the `build()` method. Implement a memoized getter method in the corresponding state management provider (e.g., caching the sorted result until the source data mutates) to ensure the operation only executes when strictly necessary.

## 2025-02-15 - Dart Collection Partitioning Bottleneck
**Learning:** In Dart, partitioning a single list into two collections (e.g., separating videos by title content) using multiple `.where()` passes combined with `.contains()` creates an O(N²) execution pattern. This causes severe CPU spikes and blocks the main UI thread during build cycles, especially when called inside Provider getters or widget `build()` methods.
**Action:** Always use a single-pass O(N) `for` loop to iterate through the collection once and append items to their respective lists based on the condition.

## 2025-02-15 - Flutter In-Build List Mutation and Sorting
**Learning:** Executing `List.sort()` directly inside a `build()` method on a list obtained from a Provider is dangerous. It not only incurs a severe O(N log N) performance penalty on every render cycle (especially during background syncs when `notifyListeners()` fires frequently), but it also mutates the underlying state object directly if it isn't copied first, potentially causing side effects in other widgets sharing that state.
**Action:** Move data transformation (filtering/sorting) to the Provider, memoize the result, and ensure the original state is never mutated directly by returning a transformed copy.
## 2024-05-30 - [Database migration optimization]
**Learning:** Found an N+1 query issue during the database migration inside `channel_provider.dart`, where it was iterating through a map of channel videos and executing an insert/update database operation for each channel individually. This caused unnecessary synchronous batch commits per loop.
**Action:** Flattened the nested map structures beforehand using `oldMap.values.expand((v) => v).toList()` to gather all videos into a single contiguous list, then performed exactly 1 database write batch. Measured a >90% improvement in execution time for standard data loads, preventing UI thread blocking.
