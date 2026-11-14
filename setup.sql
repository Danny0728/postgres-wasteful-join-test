-- Schema: users, one address per user, many orders per user
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

-- Seed: 50,000 users, 50,000 addresses across 5 cities, 500,000 orders
INSERT INTO users (name)
SELECT 'user ' || g FROM generate_series(1, 5000000) AS g;

INSERT INTO addresses (user_id, city)
SELECT id, (ARRAY['Mumbai','Pune','Delhi','Bengaluru','Chennai'])[1 + (id % 5)::int]
FROM users;

INSERT INTO orders (user_id, total)
SELECT 1 + floor(random() * 5000000)::bigint, round((random() * 5000)::numeric, 2)
FROM generate_series(1, 5000000);

CREATE INDEX orders_user_id_idx ON orders (user_id);
CREATE INDEX addresses_city_idx ON addresses (city);

ANALYZE;
