-- How a person identifies and who they want to meet, for two-way matching.
-- show_me is sensitive (it can reveal orientation): it is never returned to
-- anyone else. gender is public only when show_gender is true.
ALTER TABLE profiles ADD COLUMN gender text
  CHECK (gender IS NULL OR gender IN ('woman','man','nonbinary'));
ALTER TABLE profiles ADD COLUMN show_me text[] NOT NULL DEFAULT '{}';  -- empty = everyone
ALTER TABLE profiles ADD COLUMN show_gender boolean NOT NULL DEFAULT false;
