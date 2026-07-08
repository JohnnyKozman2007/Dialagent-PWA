const { Client } = require('pg');
const password = encodeURIComponent('password1234567890-+J??&&');
const client = new Client({
  connectionString: `postgresql://postgres.tjtjxhxesyhjozpetyqw:${password}@aws-0-eu-west-1.pooler.supabase.com:6543/postgres`,
  ssl: {
    rejectUnauthorized: false
  }
});
client.connect()
  .then(() => client.query('SELECT * FROM vault.decrypted_secrets LIMIT 10;'))
  .then(res => {
    console.log('SECRETS_RESULT:');
    console.log(JSON.stringify(res.rows, null, 2));
    client.end();
  })
  .catch(err => {
    console.error('QUERY_ERROR:', err);
    client.end();
  });
