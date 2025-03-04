# ---- Base Node for client build ----
FROM node:22 AS client-builder
WORKDIR /app
COPY client/ ./client/
WORKDIR /app/client
RUN npm ci && npm run build

# ---- Base Node ----
FROM node:22 AS base
ENV PATH="/usr/local/bin:/usr/local:$PATH"
WORKDIR /app
COPY package*.json ./

RUN npm ci && \
    apt-get update && \
    apt-get install -y ffmpeg && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux -O /usr/local/bin/yt-dlp && \
    chmod +x /usr/local/bin/yt-dlp

COPY server/ ./server/

# Copy client build from builder stage
COPY --from=client-builder /app/client/build/ ./client/build/

# Expose port for the application
EXPOSE 3011

# Start the server
CMD ["sh", "-c", "node ./server/server.js"]
