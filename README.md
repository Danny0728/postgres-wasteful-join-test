# postgres-wasteful-join-test

Measuring what an unnecessary `JOIN` costs in PostgreSQL, using `EXPLAIN ANALYZE`.

Two queries return exactly the same rows. One of them takes a detour through a table the result doesn't need. This repository has everything required to reproduce the comparison on your own machine in a few minutes.

Articles:

1. [I Wrote a Wasteful JOIN on Purpose. It Ran Faster, Until It Didn't.](https://dev.to/danny0728/i-wrote-a-wasteful-join-on-purpose-it-ran-faster-until-it-didnt-2ifj)
2. The Wasteful JOIN I Was Afraid to Write? GORM Wrote It for Me. _(add the link here once it is published)_

## The question

When you write SQL by hand, nothing stops you from joining through a table you don't need. The result is still correct, so the wasted work is easy to miss. How much does it cost, and how would you notice?

The schema has three tables:

- `users`
- `addresses`: one per user, with a `city`
- `orders`: many per user

The task is to fetch every order placed by a user who lives in Pune.

**Query A** goes through `users`, although the result needs nothing from it:

```sql
SELECT o.id, o.user_id, o.total
FROM orders o
JOIN users u     ON u.id = o.user_id
JOIN addresses a ON a.user_id = u.id
WHERE a.city = 'Pune';
```

**Query B** goes straight from `orders` to `addresses`:

```sql
SELECT o.id, o.user_id, o.total
FROM orders o
JOIN addresses a ON a.user_id = o.user_id
WHERE a.city = 'Pune';
```

## Results

| Scenario | Query A (through `users`) | Query B (direct) | What it looks like |
| --- | --- | --- | --- |
| Small data, median of 5 runs | 59.6 ms | 65.2 ms | No real difference |
| 5 million rows, default settings | 1,379 ms | 1,829 ms | A looks 25% faster |
| 5 million rows, single CPU core | 3,185 ms | 1,681 ms | A takes 1.9 times as long |

With default settings on the large dataset, PostgreSQL ran Query A on three CPU cores and Query B on one. That made the query with the unnecessary join finish first while doing more work. Limited to one core each, the direct query won clearly.

In all three cases the plan showed the extra scan of `users`. The run time never did.

These numbers come from one machine running PostgreSQL 16 in Docker Desktop. The large-data figures are single runs. Your numbers will differ, and on small data the order of the two queries can flip.

## Run it

You need Docker. Run the commands from the folder that contains the SQL files.

### Small dataset

50,000 users, 50,000 addresses, 500,000 orders.

```bash
docker run --name pgtest -e POSTGRES_PASSWORD=pass -d postgres:16
# wait about 10 seconds for the server to start

docker cp setup.sql pgtest:/setup.sql
docker cp queries.sql pgtest:/queries.sql

docker exec pgtest psql -U postgres -f /setup.sql
docker exec pgtest psql -U postgres -f /queries.sql
```

Run the last command three to five times. Timings vary from run to run.

### Large dataset

5,000,000 users, 5,000,000 addresses, 5,000,000 orders. Loading takes a minute or two and uses a few hundred MB of disk.

```bash
docker rm -f pgtest
docker run --name pgtest -e POSTGRES_PASSWORD=pass -d postgres:16
# wait about 10 seconds for the server to start

docker cp setup.sql pgtest:/setup.sql
docker cp queries.sql pgtest:/queries.sql

docker exec pgtest psql -U postgres -v users=5000000 -v orders=5000000 -f /setup.sql
docker exec pgtest psql -U postgres -f /queries.sql
```

The same `setup.sql` builds both sizes. It loads the small dataset by default, and `-v users=... -v orders=...` overrides the row counts.

### Large dataset, single CPU core

This switches parallel workers off for the session, so both queries run on one core:

```bash
docker exec pgtest psql -U postgres -c "SET max_parallel_workers_per_gather = 0;" -f /queries.sql
```

## What to look for in the plans

- **`Seq Scan on users`** in Query A's plan. This is the wasted work. Query B's plan has no such line.
- **`Gather` and `Workers Launched`** at the top of a plan. They mean the query ran on more than one CPU core, which can make a heavier plan finish sooner.
- **`Execution Time`** at the bottom of each plan.

## Part 2: the same task through GORM

The second article writes the same task three ways in GORM, prints the SQL GORM generates for each, and compares the plans. The Go program runs in a container, so Docker is still all you need.

If the `pgtest` container from Part 1 is still around, remove it first with `docker rm -f pgtest`.

```bash
# start PostgreSQL 16
docker compose up -d --wait db

# load 5 million users, addresses and orders
docker exec pgtest psql -U postgres -v users=5000000 -v orders=5000000 -f /setup.sql

# print GORM's SQL for each way, then its plan
docker compose run --rm gorm

# the same three statements, limited to one CPU core
docker exec pgtest psql -U postgres -f /gorm-single-core.sql
```

The three ways are association joins (`Joins("User").Joins("User.Address")`), a hand-written join string, and a subquery.

| | 1. Association joins | 2. Hand-written join | 3. Subquery |
| --- | --- | --- | --- |
| Default settings, median of 4 runs | 1,478 ms | 1,960 ms | 1,985 ms |
| Single CPU core, 1 run | 4,271 ms | 1,817 ms | 1,866 ms |
| Table pages read | About 102,400 | 70,504 | 70,504 |

Association joins go through `users`, just like Query A in Part 1, and select the user and address columns for every order.

To reset everything:

```bash
docker compose down -v
```

## Files

| File | What it does |
| --- | --- |
| `setup.sql` | Creates the tables and indexes and loads the data. Small by default; pass `-v users=... -v orders=...` for other sizes |
| `queries.sql` | Runs Query A and Query B with `EXPLAIN ANALYZE` |
| `docker-compose.yml` | Part 2: starts PostgreSQL and runs the Go program in a container |
| `main.go` | Part 2: three ways to write the task in GORM; prints the SQL and the plan for each |
| `gorm-single-core.sql` | Part 2: the three statements GORM generated, with parallel workers off |
| `go.mod`, `go.sum` | Part 2: the Go module files, including the GORM version used |

## Clean up

```bash
docker rm -f pgtest
```

## Limits

- One machine, PostgreSQL 16, default configuration.
- One query shape. A different join, filter or index could behave differently.
- The large dataset has about one order per user and the small one about ten, so the two differ in shape as well as size.
