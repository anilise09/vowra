-- An optional approximate area: the centre of a grid cell about 2 km across,
-- sealed with the data key. The phone rounds to the cell before sending and
-- the server rounds again, so no exact location is ever stored. Only a coarse
-- distance band is ever shown to anyone else.
ALTER TABLE profiles ADD COLUMN location_sealed text;
ALTER TABLE profiles ADD COLUMN location_updated_at timestamptz;
