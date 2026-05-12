require('dotenv').config();
const express = require('express');
const session = require('express-session');
const helmet = require('helmet');
const methodOverride = require('method-override');
const path = require('path');
const { redisClient } = require('./config/redis');
const { pool, migrate } = require('./config/db');
const RedisStore = require('connect-redis').default;

const app = express();
const PORT = process.env.PORT || 7125;

app.use(helmet({
  contentSecurityPolicy: false,
  crossOriginEmbedderPolicy: false,
  hsts: false,
}));

app.use(express.urlencoded({ extended: true }));
app.use(express.json());
app.use(methodOverride('_method'));
app.use(express.static(path.join(__dirname, '../public')));
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, '../views'));

app.use(session({
  store: new RedisStore({ client: redisClient }),
  secret: process.env.SESSION_SECRET || 'dev-secret-CHANGE-ME',
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: false,
    httpOnly: true,
    sameSite: 'lax',
    maxAge: 7 * 24 * 60 * 60 * 1000
  }
}));

app.use((req, res, next) => {
  res.locals.user = req.session.user || null;
  res.locals.flash = req.session.flash || {};
  delete req.session.flash;
  next();
});

app.use('/', require('./routes/portal'));
app.use('/auth', require('./routes/auth'));
app.use('/users', require('./routes/users'));
app.use('/newsletter', require('./routes/newsletter'));
app.use('/api', require('./routes/api'));

app.use((req, res) => res.status(404).render('error', { code: 404, message: 'Strona nie istnieje' }));
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).render('error', { code: 500, message: 'Błąd serwera' });
});

async function waitForDb(maxRetries = 30, delay = 3000) {
  for (let i = 1; i <= maxRetries; i++) {
    try {
      const client = await pool.connect();
      await client.query('SELECT NOW()');
      client.release();
      console.log('✅ PostgreSQL ready');
      return;
    } catch (e) {
      console.log(`⏳ PostgreSQL not ready (${i}/${maxRetries}) – ${e.message}`);
      await new Promise(r => setTimeout(r, delay));
    }
  }
  throw new Error('PostgreSQL unavailable after retries');
}

async function start() {
  await waitForDb();
  await migrate(); 
  const server = app.listen(PORT, '0.0.0.0', () =>
    console.log(`🚀 IT Ciekawostki → http://0.0.0.0:${PORT}`)
  );
  process.on('SIGTERM', () => {
    server.close(() => { pool.end(); redisClient.quit(); process.exit(0); });
  });
}

start().catch(e => { console.error('Fatal:', e.message); process.exit(1); });
