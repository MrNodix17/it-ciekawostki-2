const Bull=require('bull');
const emailQueue=new Bull('email-queue',{redis:process.env.REDIS_URL||'redis://localhost:6379',defaultJobOptions:{removeOnComplete:100,removeOnFail:50,attempts:3,backoff:{type:'exponential',delay:5000}}});
emailQueue.process(async(job)=>{const{type,data}=job.data;console.log(`[Queue] type=${type} to=${data.email||'N/A'}`);/* TODO: nodemailer/SendGrid */return{sent:true};});
emailQueue.on('completed',(j)=>console.log(`[Queue] Job ${j.id} done`));
emailQueue.on('failed',(j,e)=>console.error(`[Queue] Job ${j.id} failed:`,e.message));
module.exports={emailQueue};
