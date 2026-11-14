-- Task: all orders placed by users who live in Pune

-- A) The wasteful path: goes through users, which the result doesn't need
EXPLAIN ANALYZE
SELECT o.id, o.user_id, o.total
FROM orders o
JOIN users u     ON u.id = o.user_id
JOIN addresses a ON a.user_id = u.id
WHERE a.city = 'Pune';

-- B) The lean path: orders straight to addresses
EXPLAIN ANALYZE
SELECT o.id, o.user_id, o.total
FROM orders o
JOIN addresses a ON a.user_id = o.user_id
WHERE a.city = 'Pune';
