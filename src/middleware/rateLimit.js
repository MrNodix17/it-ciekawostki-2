const rateLimit=require('express-rate-limit');
const loginLimiter=rateLimit({windowMs:15*60*1000,max:10,message:{error:'Za dużo prób. Spróbuj za 15 minut.'},standardHeaders:true,legacyHeaders:false});
const apiLimiter=rateLimit({windowMs:60*1000,max:120});
module.exports={loginLimiter,apiLimiter};
