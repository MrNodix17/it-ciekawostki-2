const { createClient } = require('redis');

const redisClient = createClient({
  url: process.env.REDIS_URL || 'redis://redis:6379'
});

redisClient.on('error', (e) => console.error('Redis error:', e));
redisClient.on('connect', () => console.log('✅ Redis connected'));

redisClient.connect().catch(console.error);

module.exports = { redisClient };
