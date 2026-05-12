const express=require('express'),{pool}=require('../config/db'),{emailQueue}=require('../config/queue'),{requireAuth}=require('../middleware/auth'),router=express.Router();
router.post('/zapisz',requireAuth,async(req,res)=>{
  try{await pool.query("INSERT INTO newsletter_subscriptions(user_id,email,status)VALUES($1,$2,'active') ON CONFLICT(user_id) DO UPDATE SET status='active'",[req.session.user.id,req.session.user.email]);
  await emailQueue.add({type:'welcome',data:{email:req.session.user.email,name:req.session.user.display_name}});
  req.session.flash={success:'Zapisano do newslettera! Sprawdź email.'};
  }catch(err){console.error(err);req.session.flash={error:'Błąd zapisu do newslettera.'};}
  res.redirect('/dashboard');
});
router.post('/wypisz',requireAuth,async(req,res)=>{
  try{await pool.query("UPDATE newsletter_subscriptions SET status='unsubscribed' WHERE user_id=$1",[req.session.user.id]);req.session.flash={success:'Wypisano z newslettera.'};}
  catch(err){req.session.flash={error:'Błąd wypisywania.'};}
  res.redirect('/dashboard');
});
module.exports=router;
