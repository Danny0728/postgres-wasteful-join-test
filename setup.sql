-- Dataset size. Defaults give the small dataset.
-- Override from the command line for the large one:
--   psql -v users=5000000 -v orders=5000000 -f setup.sql
\if :{?users}
\else
  \set users 50000
\endif
\if :{?orders}
\else
  \set orders 500000
\endif

-- Schema: users, one address per user, orders spread across all users
CREATE TABLE users (
  id   bigserial PRIMARY KEY,
  name text NOT NULL
);

CREATE TABLE addresses (
  id      bigserial PRIMARY KEY,
  user_id bigint NOT NULL UNIQUE REFERENCES users(id),
  city    text NOT NULL
);

CREATE TABLE orders (
  id         bigserial PRIMARY KEY,
  user_id    bigint NOT NULL REFERENCES users(id),
  total      numeric(10,2) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Seed: one address per user across 5 cities, orders assigned to random users
INSERT INTO users (name)
SELECT 'user ' || g FROM generate_series(1, :users) AS g;

INSERT INTO addresses (user_id, city)
SELECT id, (ARRAY['Mumbai','Pune','Delhi','Bengaluru','Chennai'])[1 + (id % 5)::int]
FROM users;

INSERT INTO orders (user_id, total)
SELECT 1 + floor(random() * :users)::bigint, round((random() * 5000)::numeric, 2)
FROM generate_series(1, :orders);

CREATE INDEX orders_user_id_idx ON orders (user_id);
CREATE INDEX addresses_city_idx ON addresses (city);

ANALYZE;
