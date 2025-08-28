FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production --omit=dev || true
COPY . .
EXPOSE 4000
CMD ["npm","start"]
