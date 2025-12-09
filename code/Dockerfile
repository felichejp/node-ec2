# Build stage
FROM public.ecr.aws/docker/library/node:22-slim AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Production stage
FROM public.ecr.aws/docker/library/node:22-slim
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY --from=builder /app/dist ./dist
# Change ownership of the app directory to the node user
RUN chown -R node:node /app
# Switch to non-root user
USER node
EXPOSE 8080
CMD [ "node", "dist/server.js" ]
