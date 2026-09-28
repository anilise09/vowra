-- Local test data only: a bundled synthetic portrait for seeded demo members
-- (scripts/seed-demo.ts). Clients can never set it (the profile PATCH schema
-- is strict), and the seed script refuses a real database.
ALTER TABLE profiles ADD COLUMN demo_portrait text;
