-- The three statements below are the exact SQL GORM generated for each variant.
-- This file runs them with parallel workers switched off, so each query uses one CPU core.

SET max_parallel_workers_per_gather = 0;

\echo Parallel workers are OFF for this run.
\echo
\echo ==================================================================
\echo 1. Association joins: Joins("User").Joins("User.Address")
\echo ==================================================================
EXPLAIN (ANALYZE, BUFFERS)
SELECT "orders"."id","orders"."user_id","orders"."total","orders"."created_at","User"."id" AS "User__id","User"."name" AS "User__name","User__Address"."id" AS "User__Address__id","User__Address"."user_id" AS "User__Address__user_id","User__Address"."city" AS "User__Address__city" FROM "orders" LEFT JOIN "users" "User" ON "orders"."user_id" = "User"."id" LEFT JOIN "addresses" "User__Address" ON "User"."id" = "User__Address"."user_id" WHERE "User__Address"."city" = 'Pune';

\echo ==================================================================
\echo 2. Hand-written join string
\echo ==================================================================
EXPLAIN (ANALYZE, BUFFERS)
SELECT "orders"."id","orders"."user_id","orders"."total","orders"."created_at" FROM "orders" JOIN addresses ON addresses.user_id = orders.user_id WHERE addresses.city = 'Pune';

\echo ==================================================================
\echo 3. Subquery: user_id IN (SELECT ...)
\echo ==================================================================
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM "orders" WHERE user_id IN (SELECT "user_id" FROM "addresses" WHERE city = 'Pune');
