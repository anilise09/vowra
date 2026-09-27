-- Optional public profile details: habits (one answer per topic) and up to
-- two prompt answers. Validated against fixed lists in src/rules.ts.
ALTER TABLE profiles ADD COLUMN lifestyle jsonb NOT NULL DEFAULT '{}';
ALTER TABLE profiles ADD COLUMN prompts jsonb NOT NULL DEFAULT '[]';
