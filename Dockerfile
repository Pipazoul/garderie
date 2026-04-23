FROM debian:bookworm-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    unzip \
    wget \
    curl \
    nginx \
    supervisor \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Install shell2http
ARG SHELL2HTTP_VERSION=1.17.0
RUN wget -q "https://github.com/msoap/shell2http/releases/download/v${SHELL2HTTP_VERSION}/shell2http_${SHELL2HTTP_VERSION}_linux_amd64.tar.gz" \
    -O /tmp/shell2http.tar.gz \
    && tar -xzf /tmp/shell2http.tar.gz -C /usr/local/bin/ shell2http \
    && chmod +x /usr/local/bin/shell2http \
    && rm /tmp/shell2http.tar.gz

# Install PocketBase
ARG PB_VERSION=0.25.9
RUN wget -q "https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_amd64.zip" \
    -O /tmp/pocketbase.zip \
    && unzip /tmp/pocketbase.zip -d /usr/local/bin/ \
    && chmod +x /usr/local/bin/pocketbase \
    && rm /tmp/pocketbase.zip

# Create directories
RUN mkdir -p /sites /pb_data /var/log/supervisor

# Copy configs and entrypoint
COPY nginx.conf /etc/nginx/nginx.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Default site placeholder
RUN echo '<h1>Welcome</h1><p>Create folders in /sites to add new paths.</p>' > /sites/index.html

# Copy default PocketBase hooks
COPY pb_hooks /pb_hooks_default

# Copy LLM instructions
COPY llm.md /llm.txt

EXPOSE 80

CMD ["/entrypoint.sh"]
