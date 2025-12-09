ARG BASE_IMAGE=public.ecr.aws/docker/library/node:22-slim

# Build stage
FROM ${BASE_IMAGE} AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# Production stage
FROM ${BASE_IMAGE}
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY --from=builder /app/dist ./dist
EXPOSE 8080
CMD ["node", "dist/server.js"]
