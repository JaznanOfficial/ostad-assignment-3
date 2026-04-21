# 1. Base image
FROM node:20-alpine AS base

# 2. Set working directory
WORKDIR /app

# 3. Copy package files
COPY package.json package-lock.json ./

# 4. Install dependencies
RUN npm ci

# 5. Copy the rest of the application
COPY . .

# 6. Build the Next.js app
RUN npm run build

# 7. Start the production server using a smaller image
FROM node:20-alpine AS runner

# Create app directory
WORKDIR /app

# Copy only necessary files
COPY --from=base /app/package.json ./
COPY --from=base /app/.next ./.next
COPY --from=base /app/public ./public
COPY --from=base /app/node_modules ./node_modules
COPY --from=base /app/next.config.mjs ./next.config.mjs

# If using App Router and output is 'standalone'
# COPY --from=base /app/.next/standalone ./
# COPY --from=base /app/.next/static ./.next/static

# Expose port
EXPOSE 3000

# Start the Next.js app
CMD ["npm", "start"]
