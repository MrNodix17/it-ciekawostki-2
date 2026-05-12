FROM node:20-alpine
WORKDIR /app
RUN apk add --no-cache curl

# Unset NODE_ENV during install so npm installs all dependencies
ARG NODE_ENV
ENV NODE_ENV=development

COPY package*.json ./
RUN npm install && npm cache clean --force

# Set production after install
ENV NODE_ENV=production

COPY . .
EXPOSE 7125
CMD ["node", "src/app.js"]
