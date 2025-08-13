FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production || npm ci
COPY . .
ENV NODE_ENV=production
ENV SERVER_PORT=8080
EXPOSE 8080
CMD ["node","server.js"]
