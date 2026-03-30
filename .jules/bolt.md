## 2024-05-24 - Flutter ListView `shrinkWrap` Performance Bottleneck
**Learning:** In Flutter, using `ListView.builder` inside a `SingleChildScrollView` with `shrinkWrap: true` completely negates the lazy-rendering benefits of `ListView`. It forces Flutter to instantiate, layout, and render *all* children at once to determine the total size of the list. This leads to massive CPU spikes, memory consumption, and scroll jank, especially with heavy items (like Video Cards with network images).
**Action:** Always replace `SingleChildScrollView` containing `ListView(shrinkWrap: true)` with a `CustomScrollView` and `SliverList`. This restores lazy-rendering, keeping memory footprint low and scrolling smooth.

## 2025-02-15 - Flutter Provider Expensive Getter Memoization
**Learning:** In Flutter, `ChangeNotifier` providers with computed getters (like merging lists and sorting them) are re-evaluated *every single time* they are called during a UI `build()`. This means an O(N log N) sort operation inside a getter can execute dozens of times per frame, causing massive CPU spikes and jank.
**Action:** Always memoize expensive operations (e.g. sorting, filtering large lists) within Provider getters. Cache the result in a private field (`_cachedData`) and introduce a `_invalidateCache()` method to clear the cache whenever the underlying data mutates.
