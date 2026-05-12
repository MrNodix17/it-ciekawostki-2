const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000
});

async function migrate() {
  const client = await pool.connect();
  try {
    const check = await client.query(
      "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='users'"
    );
    if (parseInt(check.rows[0].count) > 0) {
      console.log('DB schema exists, skipping migration');
      return;
    }
    console.log('Running DB migration...');
    const sql = fs.readFileSync(path.join(__dirname, '../../db/schema.sql'), 'utf8');
    await client.query(sql);
    console.log('DB migration done');
  } finally {
    client.release();
  }
}

module.exports = { pool, migrate };
