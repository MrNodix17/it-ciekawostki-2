function requireAuth(req,res,next){if(!req.session.user){req.session.flash={error:'Musisz być zalogowany.'};return res.redirect('/auth/login');}next();}
function requireAdmin(req,res,next){if(!req.session.user||req.session.user.role!=='admin')return res.status(403).render('error',{code:403,message:'Brak uprawnień'});next();}
function redirectIfAuth(req,res,next){if(req.session.user)return res.redirect('/dashboard');next();}
module.exports={requireAuth,requireAdmin,redirectIfAuth};
