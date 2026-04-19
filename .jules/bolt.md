## 2024-05-24 - Optimize channel database migration (N+1 query fix)
**Learning:** Performing `N` individual `INSERT` calls within an iteration structure in SQLite causes an "N+1" query pattern, multiplying overhead significantly due to individual disk IO per operation, even locally.
**Action:** Always utilize a SQLite `Batch` (`db.batch()`) operation when performing sequential inserts or updates over a large array or list collection to drastically reduce wait time and IO calls.
