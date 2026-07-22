# Use Bun image
FROM oven/bun:1 as base
WORKDIR /app

# Install dependencies
FROM base AS install
RUN mkdir -p /temp/dev
COPY package.json bun.lock /temp/dev/
RUN cd /temp/dev && bun install --frozen-lockfile

# Build the app
FROM base AS build
COPY --from=install /temp/dev/node_modules node_modules
COPY . .

# Set environment variable for production build
ENV NEXT_PUBLIC_API_URL=http://backend:8000/api/v1
RUN bun run build

# Production image
FROM base AS release
COPY --from=build /app/.next ./.next
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/package.json ./package.json
COPY --from=build /app/public ./public

# Expose port
EXPOSE 3000

# Start the app
CMD ["bun", "run", "start"]
