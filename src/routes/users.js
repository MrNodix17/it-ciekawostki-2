const express = require('express');
const { pool } = require('../config/db');
const { requireAuth } = require('../middleware/auth');
const router = express.Router();

router.get('/szukaj', async (req, res) => {
  const { q } = req.query;
  let users = [];
  try {
    if (q && q.length >= 2) {
      const uid = req.session.user ? req.session.user.id : null;
      const r = await pool.query(
        'SELECT id,username,display_name FROM users WHERE (username ILIKE $1 OR display_name ILIKE $1) AND is_active=true' + (uid ? ' AND id<>$2' : '') + ' LIMIT 20',
        uid ? [`%${q}%`, uid] : [`%${q}%`]
      );
      users = r.rows;
    }
    res.render('users/search', { title: 'Szukaj użytkowników', users, query: q || '' });
  } catch (err) {
    console.error(err);
    res.render('users/search', { title: 'Szukaj użytkowników', users: [], query: '' });
  }
});

router.get('/:username', async (req, res) => {
  try {
    const r = await pool.query(
      'SELECT id,username,display_name,created_at FROM users WHERE username=$1 AND is_active=true',
      [req.params.username]
    );
    if (!r.rows[0]) return res.status(404).render('error', { code: 404, message: 'Użytkownik nie istnieje' });
    const profileUser = r.rows[0];
    let friendshipStatus = null;
    if (req.session.user && req.session.user.id !== profileUser.id) {
      const fs = await pool.query(
        'SELECT status FROM friendships WHERE (requester_id=$1 AND receiver_id=$2) OR (requester_id=$2 AND receiver_id=$1)',
        [req.session.user.id, profileUser.id]
      );
      friendshipStatus = fs.rows[0] ? fs.rows[0].status : null;
    }
    const fc = await pool.query(
      "SELECT COUNT(*) FROM friendships WHERE (requester_id=$1 OR receiver_id=$1) AND status='accepted'",
      [profileUser.id]
    );
    const nl = await pool.query(
      "SELECT status FROM newsletter_subscriptions WHERE user_id=$1", [profileUser.id]
    );
    res.render('users/profile', {
      title: '@' + profileUser.username,
      profileUser,
      friendshipStatus,
      friendsCount: parseInt(fc.rows[0].count),
      newsletterStatus: nl.rows[0] && nl.rows[0].status === 'active'
    });
  } catch (err) {
    console.error(err);
    res.status(500).render('error', { code: 500, message: 'Błąd serwera' });
  }
});

router.post('/znajomy/dodaj', requireAuth, async (req, res) => {
  const { targetId } = req.body;
  try {
    await pool.query(
      'INSERT INTO friendships(requester_id,receiver_id) VALUES($1,$2) ON CONFLICT DO NOTHING',
      [req.session.user.id, targetId]
    );
    req.session.flash = { success: 'Zaproszenie wysłane!' };
  } catch (err) {
    console.error(err);
    req.session.flash = { error: 'Błąd wysyłania zaproszenia.' };
  }
  res.redirect('back');
});

router.post('/znajomy/akceptuj', requireAuth, async (req, res) => {
  const { requesterId } = req.body;
  try {
    await pool.query(
      "UPDATE friendships SET status='accepted' WHERE requester_id=$1 AND receiver_id=$2",
      [requesterId, req.session.user.id]
    );
    req.session.flash = { success: 'Zaproszenie zaakceptowane!' };
  } catch (err) {
    console.error(err);
  }
  res.redirect('/dashboard');
});

router.post('/znajomy/odrzuc', requireAuth, async (req, res) => {
  const { requesterId } = req.body;
  try {
    await pool.query(
      "UPDATE friendships SET status='declined' WHERE requester_id=$1 AND receiver_id=$2",
      [requesterId, req.session.user.id]
    );
    req.session.flash = { info: 'Zaproszenie odrzucone.' };
  } catch (err) {
    console.error(err);
  }
  res.redirect('/dashboard');
});

module.exports = router;
