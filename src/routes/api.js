const express = require('express');
const { pool } = require('../config/db');
const { requireAuth } = require('../middleware/auth');
const { apiLimiter } = require('../middleware/rateLimit');
const router = express.Router();

router.use(apiLimiter);

router.post('/artykul/:id/like', requireAuth, async (req, res) => {
  const aid = req.params.id, uid = req.session.user.id;
  try {
    const ex = await pool.query('SELECT 1 FROM article_likes WHERE user_id=$1 AND article_id=$2', [uid, aid]);
    if (ex.rows.length > 0) {
      await pool.query('DELETE FROM article_likes WHERE user_id=$1 AND article_id=$2', [uid, aid]);
    } else {
      await pool.query('INSERT INTO article_likes(user_id,article_id) VALUES($1,$2)', [uid, aid]);
    }
    const c = await pool.query('SELECT COUNT(*) FROM article_likes WHERE article_id=$1', [aid]);
    res.json({ liked: ex.rows.length === 0, likes: parseInt(c.rows[0].count) });
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
});

router.post('/artykul/:id/komentarz', requireAuth, async (req, res) => {
  const { content } = req.body;
  if (!content || content.trim().length < 3) {
    req.session.flash = { error: 'Komentarz jest za krótki.' };
    return res.redirect('back');
  }
  try {
    await pool.query(
      'INSERT INTO comments(article_id,user_id,content) VALUES($1,$2,$3)',
      [req.params.id, req.session.user.id, content.trim().substring(0, 1000)]
    );
    req.session.flash = { success: 'Komentarz dodany!' };
  } catch (err) {
    console.error(err);
    req.session.flash = { error: 'Błąd dodawania komentarza.' };
  }
  res.redirect('back');
});

module.exports = router;
