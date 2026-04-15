## 2024-04-15 - Parallelize Channel Avatar Caching
**Learning:** Sequential async operations over large lists (like `await`ing HTTP requests inside a loop) are a common source of performance bottlenecks during app initialization or caching processes.
**Action:** When executing independent async operations in a loop, collect the futures in a list and execute them concurrently using `Future.wait(futures)` to significantly reduce wait times.
