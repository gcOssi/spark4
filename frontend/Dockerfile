FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production --omit=dev || true
COPY . .
EXPOSE 3000
CMD ["npm","start"]
