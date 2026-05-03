## 2024-05-24 - N+1 Query in Channel Migration Optimization
**Learning:** Replaced a loop of N sequential `db.insert()` operations with a single batched `db.batch()` insertion to eliminate SQLite connection and transaction overhead. The benchmark demonstrated an 83% performance improvement for bulk inserts.
**Action:** Always utilize `db.batch()` when performing multiple insert or update operations on an SQLite database sequentially in a loop.
