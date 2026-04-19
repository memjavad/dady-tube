## $(date +%Y-%m-%d) - Optimize Database Initialization Query

**Learning:** When performing database migrations or bulk insertions on initialization, executing `db.insert()` within a standard `for` loop produces an N+1 query problem, creating a separate database transaction for every item inserted. This causes significant sequential I/O overhead and performance degradation, especially during the app startup sequence when the database is being populated.
**Action:** When inserting or updating multiple records simultaneously, always use a `Batch` transaction (`db.batch()`). Batch transactions execute all pending operations concurrently and safely commit them as a single atomic operation, substantially reducing I/O friction and database locks, drastically improving loop times.
