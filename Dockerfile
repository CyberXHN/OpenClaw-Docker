# ====== Stage 1: Extract OpenClaw app from upstream image ======
# Extract /app directory from upstream image and package as compressed archive
# Content from this stage won't be in final image, avoiding size bloat from upstream /app layer
ARG UPSTREAM_VERSION
FROM ghcr.io/openclaw/openclaw:${UPSTREAM_VERSION} AS app-extract

# Switch to root to write archive to root-owned path
USER root

# Use xz -6 preset compression (dict ~256MB, decompression memory ~512MB, within 1GB limit)
RUN tar -I 'xz -6' -cf /openclaw-app.tar.xz -C / app

# ====== Stage 2: Build runtime image from slim base ======
# Start from node:24-bookworm-slim, without upstream /app layer
# Extract compressed tar.xz only via COPY --from (~150MB vs original ~500MB)
FROM node:24-bookworm-slim

USER root

# Install Fonts
RUN apt-get update && apt-get install -y --no-install-recommends fonts-noto-cjk fonts-noto-cjk-extra fonts-wqy-zenhei fonts-wqy-microhei

# Install Chromium
RUN apt-get update && apt-get install -y --no-install-recommends chromium

# Install Coding Environment (merged with upstream runtime deps)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        # Upstream runtime deps
        ca-certificates procps hostname curl git lsof openssl python3 \
        # Shell & utils
        dumb-init git-lfs locales lsb-release man-db nano vim-tiny wget zsh sudo \
        # Network tools
        iputils-ping dnsutils net-tools iproute2 tcpdump netcat-openbsd traceroute mtr-tiny iperf3 nmap telnet openssh-client \
        # System monitoring
        htop iotop sysstat file tree \
        # Build tools & languages
        gnupg software-properties-common build-essential gcc cmake g++ gdb golang-go \
        openjdk-17-jdk maven \
        python3-pip ffmpeg jq unzip zip \
        # Office & OCR
        libreoffice-calc libreoffice-writer libreoffice-impress poppler-utils antiword catdoc \
        tesseract-ocr tesseract-ocr-eng tesseract-ocr-chi-sim && \
    update-ca-certificates && \
    # Create python link
    ln -sf /usr/bin/python3 /usr/bin/python && \
    # Install office document processing Python libraries
    pip install --no-cache-dir --break-system-packages \
        python-docx openpyxl xlrd python-pptx pypdf reportlab markitdown[pptx] PyMuPDF pdf2image pillow pytesseract textract pandas openai python-dotenv && \
    # Install Node.js packages for PPTX generation
    npm install -g pptxgenjs && \
    # Install PHP
    wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list && \
    apt-get update && \
    apt-get install -y \
        php7.4 php7.4-cli php7.4-common php7.4-curl php7.4-xml php7.4-mbstring php7.4-zip \
        php8.4 php8.4-cli php8.4-common php8.4-curl php8.4-xml php8.4-mbstring php8.4-zip && \
    # Set PHP 8.4 as default
    update-alternatives --set php /usr/bin/php8.4 && \
    # Install .NET 10 SDK
    wget https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y dotnet-sdk-10.0 && \
    # Clean
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Verify installation results
RUN chown -R 1000:1000 /home/node \
  && chmod -R 755 /home/node \
  && echo "=== Verify installation results ===" \
  && python --version \
  && php --version \
  && java -version \
  && javac -version \
  && dotnet --version \
  && go version \
  && gdb --version

# ====== OpenClaw App: Factory Backup Pattern ======
# Copy compressed app archive from Stage 1 (does NOT include upstream /app layer)
COPY --from=app-extract /openclaw-app.tar.xz /openclaw-app.tar.xz

# Extract package.json temporarily for corepack setup, then clean up
# This ensures pnpm is pre-cached so the node user doesn't need a first-run network fetch
RUN mkdir -p /tmp/oc-extract && \
    tar -xJf /openclaw-app.tar.xz -C /tmp/oc-extract app/package.json && \
    COREPACK_HOME=/usr/local/share/corepack && \
    install -d -m 0755 "$COREPACK_HOME" && \
    corepack enable && \
    corepack prepare "$(node -p "require('/tmp/oc-extract/app/package.json').packageManager")" --activate && \
    chmod -R a+rX "$COREPACK_HOME" && \
    rm -rf /tmp/oc-extract

# Create OpenClaw CLI symlink (points into /app which is a volume at runtime)
RUN ln -sf /app/openclaw.mjs /usr/local/bin/openclaw

# Pre-create directories with correct ownership for volume mounting
# Named volumes inherit these permissions on first creation
RUN install -d -m 0755 -o node -g node /app && \
    install -d -m 0700 -o node -g node /home/node/.openclaw && \
    install -d -m 0700 -o node -g node /var/lib/openclaw/plugin-runtime-deps

# Copy entrypoint initialization script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV NODE_ENV=production

USER node

ENTRYPOINT ["dumb-init", "--", "/entrypoint.sh"]
HEALTHCHECK --interval=3m --timeout=10s --start-period=60s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:18789/healthz').then((r)=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured"]