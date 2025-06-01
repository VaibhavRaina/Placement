# Use Node.js 18 Alpine for smaller image size
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including dev dependencies for building)
RUN npm ci --ignore-scripts

# Copy source code
COPY . .

# Build TypeScript
RUN npm run build

# Remove dev dependencies after build
RUN npm prune --production

# Expose port
EXPOSE 5000

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001
USER nodejs

# Start the application
CMD ["npm", "start"]