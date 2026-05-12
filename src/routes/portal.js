const express = require('express');
const { pool } = require('../config/db');
const { requireAuth } = require('../middleware/auth');
const router = express.Router();

router.get('/', async (req, res) => {
  try {
    const arts = await pool.query(
      'SELECT id,title,slug,excerpt,category,tags,cover_emoji,views FROM articles WHERE is_published=true ORDER BY created_at DESC LIMIT 9'
    );
    res.render('index', { title: 'IT Ciekawostki', articles: arts.rows });
  } catch (err) {
    console.error(err);
    res.render('index', { title: 'IT Ciekawostki', articles: [] });
  }
});

router.get('/artykuly', async (req, res) => {
  const { kategoria, strona = 1 } = req.query;
  const limit = 9, offset = (parseInt(strona) - 1) * limit;
  try {
    const params = [];
    const w = kategoria ? (params.push(kategoria), ' AND category=$1') : '';
    const sql = 'SELECT id,title,slug,excerpt,category,tags,cover_emoji,views FROM articles WHERE is_published=true' + w + ' ORDER BY created_at DESC LIMIT ' + limit + ' OFFSET ' + offset;
    const sqlCount = 'SELECT COUNT(*) FROM articles WHERE is_published=true' + w;
    const [arts, cnt] = await Promise.all([
      pool.query(sql, params),
      pool.query(sqlCount, params)
    ]);
    const totalPages = Math.ceil(parseInt(cnt.rows[0].count) / limit);
    res.render('articles/list', {
      title: 'Artykuly - IT Ciekawostki',
      articles: arts.rows,
      currentCategory: kategoria || null,
      currentPage: parseInt(strona),
      totalPages
    });
  } catch (err) {
    console.error(err);
    res.render('articles/list', { title: 'Artykuly', articles: [], currentCategory: null, currentPage: 1, totalPages: 1 });
  }
});

router.get('/artykuly/:slug', async (req, res) => {
  try {
    await pool.query('UPDATE articles SET views=views+1 WHERE slug=$1', [req.params.slug]);
    const r = await pool.query(
      'SELECT * FROM articles WHERE slug=$1 AND is_published=true', [req.params.slug]
    );
    if (!r.rows[0]) return res.status(404).render('error', { code: 404, message: 'Artykul nie istnieje' });
    const article = r.rows[0];
    const [comQ, lkQ] = await Promise.all([
      pool.query(
        'SELECT c.*,u.display_name,u.username FROM comments c JOIN users u ON c.user_id=u.id WHERE c.article_id=$1 ORDER BY c.created_at ASC',
        [article.id]
      ),
      pool.query('SELECT COUNT(*) FROM article_likes WHERE article_id=$1', [article.id])
    ]);
    let liked = false;
    if (req.session.user) {
      const lq = await pool.query(
        'SELECT 1 FROM article_likes WHERE user_id=$1 AND article_id=$2',
        [req.session.user.id, article.id]
      );
      liked = lq.rows.length > 0;
    }
    res.render('articles/single', {
      title: article.title,
      article,
      comments: comQ.rows,
      liked,
      likesCount: parseInt(lkQ.rows[0].count)
    });
  } catch (err) {
    console.error(err);
    res.status(500).render('error', { code: 500, message: 'Blad serwera' });
  }
});

router.get('/dashboard', requireAuth, async (req, res) => {
  const uid = req.session.user.id;
  try {
    const sqlFriends = "SELECT u.id,u.username,u.display_name FROM friendships f JOIN users u ON (CASE WHEN f.requester_id=$1 THEN f.receiver_id ELSE f.requester_id END)=u.id WHERE (f.requester_id=$1 OR f.receiver_id=$1) AND f.status='accepted' LIMIT 20";
    const sqlPending = "SELECT f.id,u.id as user_id,u.username,u.display_name FROM friendships f JOIN users u ON f.requester_id=u.id WHERE f.receiver_id=$1 AND f.status='pending'";
    const [nl, fr, pe] = await Promise.all([
      pool.query('SELECT * FROM newsletter_subscriptions WHERE user_id=$1', [uid]),
      pool.query(sqlFriends, [uid]),
      pool.query(sqlPending, [uid])
    ]);
    res.render('dashboard', {
      title: 'Dashboard',
      newsletterStatus: nl.rows[0] && nl.rows[0].status === 'active',
      friends: fr.rows,
      friendsCount: fr.rows.length,
      pendingRequests: pe.rows,
      pendingCount: pe.rows.length
    });
  } catch (err) {
    console.error(err);
    res.render('dashboard', {
      title: 'Dashboard',
      newsletterStatus: false,
      friends: [],
      friendsCount: 0,
      pendingRequests: [],
      pendingCount: 0
    });
  }
});

module.exports = router;
