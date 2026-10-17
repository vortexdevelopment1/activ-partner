CREATE TABLE IF NOT EXISTS partner_amenity_catalog (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  type TEXT NOT NULL UNIQUE,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INTEGER NOT NULL
);

INSERT INTO partner_amenity_catalog (id, title, type, sort_order) VALUES
  ('1', 'Free Parking', 'parking', 1),
  ('2', 'First Aid Kit', 'health', 2),
  ('3', 'WiFi', 'wifi', 3),
  ('4', 'Air Conditioned', 'ac', 4),
  ('5', 'Locker Room', 'locker', 5),
  ('6', 'Lounge Room', 'lounge', 6),
  ('7', 'Personal Training', 'trainer', 7),
  ('8', 'Fencing', 'fencing', 8),
  ('9', 'Proper Lighting', 'lighting', 9),
  ('10', 'Shower Room', 'shower', 10),
  ('11', 'Sound System', 'sound', 11),
  ('12', 'Childcare', 'childcare', 12),
  ('13', 'Surveillance cameras', 'security', 13),
  ('14', 'Rental Equipments', 'rental', 14),
  ('15', 'Monitored Parking', 'monitored_parking', 15),
  ('16', 'Drinking Water', 'water', 16),
  ('17', 'Changing Rooms', 'changing', 17),
  ('18', 'Restrooms', 'restrooms', 18),
  ('19', 'Seating Area', 'seating', 19),
  ('20', 'Charging Stations', 'charging', 20),
  ('21', 'Café', 'cafe', 21),
  ('22', 'Wheelchair Support', 'wheelchair', 22),
  ('23', 'Fire Safety', 'fire_safety', 23),
  ('24', 'Waiting Area', 'waiting', 24)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title, type = EXCLUDED.type, sort_order = EXCLUDED.sort_order;
