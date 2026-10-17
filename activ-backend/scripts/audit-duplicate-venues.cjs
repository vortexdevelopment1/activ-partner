require('ts-node/register');
const { config } = require('dotenv');
const { Client } = require('pg');
const { getMigrationDatabaseUrlFromEnv } = require('../src/config/database.config');

const env = { ...process.env, ...config({ path: '.env', quiet: true }).parsed,
  ...config({ path: '.env.local', quiet: true }).parsed };
const client = new Client({ connectionString: getMigrationDatabaseUrlFromEnv(env), connectionTimeoutMillis: 15000 });

(async () => {
  try {
    await client.connect();
    await client.query('BEGIN READ ONLY');
    const result = await client.query(`
      SELECT v.partner_id, lower(trim(v.name)) AS name,
        count(*)::int AS count,
        json_agg(json_build_object('id', v.id, 'status', v.status,
          'address', p.address_line_1, 'city', p.city, 'submitted', v.submitted_at,
          'created', p.created_at,
          'images', (SELECT count(*) FROM partner_venue_images i WHERE i.venue_id = v.id),
          'answers', (SELECT count(*) FROM partner_venue_answers a WHERE a.venue_id = v.id),
          'activities', (SELECT count(*) FROM partner_venue_services s WHERE s.venue_id = v.id),
          'bookings', (SELECT count(*) FROM bookings b JOIN slots s ON s.id = b.slot_id
            JOIN facilities f ON f.id = s.facility_id WHERE f.venue_id = v.id),
          'walkIns', (SELECT count(*) FROM partner_walk_in_reservations w WHERE w.venue_id = v.id)
          ) ORDER BY p.created_at) AS records
      FROM venues v LEFT JOIN partner_venue_profiles p ON p.venue_id = v.id
      WHERE ($1::text IS NULL OR lower(trim(v.name)) = lower(trim($1)))
      GROUP BY v.partner_id, lower(trim(v.name)) HAVING count(*) > 1
      ORDER BY count(*) DESC LIMIT 20
    `, [process.argv[2] || null]);
    console.log(JSON.stringify(result.rows, null, 2));
    await client.query('COMMIT');
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  } finally {
    await client.end();
  }
})();
