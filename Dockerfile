FROM debian:bookworm-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    unzip \
    wget \
    curl \
    nginx \
    supervisor \
    openssh-server \
    sslh \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Configure SSH
RUN mkdir -p /run/sshd \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

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
