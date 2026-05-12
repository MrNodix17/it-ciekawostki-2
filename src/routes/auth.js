const express = require('express');
const bcrypt = require('bcryptjs');
const { body, validationResult } = require('express-validator');
const { pool } = require('../config/db');
const { redirectIfAuth } = require('../middleware/auth');
const { loginLimiter } = require('../middleware/rateLimit');
const router = express.Router();

router.get('/login', redirectIfAuth, (req, res) =>
  res.render('auth/login', { title: 'Logowanie', errors: [] })
);

router.post('/login', loginLimiter, [
  body('email').isEmail().normalizeEmail(),
  body('password').notEmpty()
], async (req, res) => {
  const e = validationResult(req);
  if (!e.isEmpty()) return res.render('auth/login', { title: 'Logowanie', errors: e.array() });
  const { email, password } = req.body;
  try {
    const r = await pool.query('SELECT * FROM users WHERE email=$1 AND is_active=true', [email]);
    const u = r.rows[0];
    if (!u || !await bcrypt.compare(password, u.password_hash))
      return res.render('auth/login', { title: 'Logowanie', errors: [{ msg: 'Nieprawidłowy email lub hasło.' }] });
    req.session.user = { id: u.id, username: u.username, email: u.email, display_name: u.display_name, role: u.role };
    req.session.save(() => res.redirect('/dashboard'));
  } catch (err) {
    console.error(err);
    res.render('auth/login', { title: 'Logowanie', errors: [{ msg: 'Błąd serwera: ' + err.message }] });
  }
});

router.get('/register', redirectIfAuth, (req, res) =>
  res.render('auth/register', { title: 'Rejestracja', errors: [] })
);

router.post('/register', [
  body('username').trim().isLength({ min: 3, max: 30 }).matches(/^[a-zA-Z0-9_]+$/)
    .withMessage('Nazwa użytkownika: 3-30 znaków, tylko litery, cyfry i _'),
  body('email').isEmail().normalizeEmail().withMessage('Podaj prawidłowy email'),
  body('password').isLength({ min: 8 }).withMessage('Hasło musi mieć min. 8 znaków'),
  body('display_name').trim().optional({ checkFalsy: true }).isLength({ max: 60 })
], async (req, res) => {
  const e = validationResult(req);
  if (!e.isEmpty()) return res.render('auth/register', { title: 'Rejestracja', errors: e.array() });
  const { username, email, password, display_name } = req.body;
  try {
    const ex = await pool.query('SELECT id FROM users WHERE email=$1 OR username=$2', [email, username]);
    if (ex.rows.length > 0)
      return res.render('auth/register', { title: 'Rejestracja', errors: [{ msg: 'Email lub nazwa użytkownika jest już zajęta.' }] });
    const hash = await bcrypt.hash(password, 12);
    const r = await pool.query(
      'INSERT INTO users(username,email,password_hash,display_name) VALUES($1,$2,$3,$4) RETURNING *',
      [username, email, hash, display_name || null]
    );
    const u = r.rows[0];
    req.session.user = { id: u.id, username: u.username, email: u.email, display_name: u.display_name, role: u.role };
    req.session.save(() => res.redirect('/dashboard'));
  } catch (err) {
    console.error(err);
    res.render('auth/register', { title: 'Rejestracja', errors: [{ msg: 'Błąd serwera: ' + err.message }] });
  }
});

router.post('/logout', (req, res) =>
  req.session.destroy(() => res.redirect('/'))
);

module.exports = router;
