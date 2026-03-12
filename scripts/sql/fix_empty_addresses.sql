UPDATE drives d
SET start_address_id = NULL
FROM addresses a
WHERE d.start_address_id = a.id
  AND (
    COALESCE(TRIM(a.display_name), '') = ''
    OR a.osm_id IS NULL
    OR a.osm_type IS NULL
  );

UPDATE drives d
SET end_address_id = NULL
FROM addresses a
WHERE d.end_address_id = a.id
  AND (
    COALESCE(TRIM(a.display_name), '') = ''
    OR a.osm_id IS NULL
    OR a.osm_type IS NULL
  );

UPDATE charging_processes c
SET address_id = NULL
FROM addresses a
WHERE c.address_id = a.id
  AND (
    COALESCE(TRIM(a.display_name), '') = ''
    OR a.osm_id IS NULL
    OR a.osm_type IS NULL
  );

DELETE FROM addresses a
WHERE COALESCE(TRIM(a.display_name), '') = ''
  AND NOT EXISTS (SELECT 1 FROM drives d WHERE d.start_address_id = a.id OR d.end_address_id = a.id)
  AND NOT EXISTS (SELECT 1 FROM charging_processes c WHERE c.address_id = a.id)
  AND NOT EXISTS (SELECT 1 FROM geofences g WHERE g.address_id = a.id);

