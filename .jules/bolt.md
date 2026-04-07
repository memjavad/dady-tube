## 2024-05-24 - Flutter ListView `shrinkWrap` Performance Bottleneck
**Learning:** In Flutter, using `ListView.builder` inside a `SingleChildScrollView` with `shrinkWrap: true` completely negates the lazy-rendering benefits of `ListView`. It forces Flutter to instantiate, layout, and render *all* children at once to determine the total size of the list. This leads to massive CPU spikes, memory consumption, and scroll jank, especially with heavy items (like Video Cards with network images).
**Action:** Always replace `SingleChildScrollView` containing `ListView(shrinkWrap: true)` with a `CustomScrollView` and `SliverList`. This restores lazy-rendering, keeping memory footprint low and scrolling smooth.

## 2025-02-15 - Flutter Provider Expensive Getter Memoization
**Learning:** In Flutter, `ChangeNotifier` providers with computed getters (like merging lists and sorting them) are re-evaluated *every single time* they are called during a UI `build()`. This means an O(N log N) sort operation inside a getter can execute dozens of times per frame, causing massive CPU spikes and jank.
**Action:** Always memoize expensive operations (e.g. sorting, filtering large lists) within Provider getters. Cache the result in a private field (`_cachedData`) and introduce a `_invalidateCache()` method to clear the cache whenever the underlying data mutates.

## 2026-03-27 - Dart Directory Stream Iteration Performance
**Learning:** In Dart, processing directory listing streams directly using an `await for` loop to populate a collection is significantly more efficient than chaining `.toList().map().toSet()`, which creates redundant intermediate allocations.
**Action:** Always use `await for` to iterate over streams (like `Directory.list()`) when you only need to process or calculate aggregate values (like file sizes or counting types) instead of creating expensive intermediate lists.

## 2025-05-18 - Avoid List.sort() in Widget build()
**Learning:** In Flutter, executing expensive operations like `List.sort()` and `List.where()` directly inside a widget's `build()` method causes the computation to re-run on every single render cycle. For large lists, this incurs a severe O(N log N) performance penalty, leading to dropped frames and jank during animations or scrolling.
**Action:** Move expensive sorting and filtering logic out of the `build()` method. Instead, perform these operations in the state management layer (e.g., inside a Provider getter) and memoize the results to ensure they are only recomputed when the underlying data changes.
