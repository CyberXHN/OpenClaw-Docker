ARG UPSTREAM_VERSION
FROM ghcr.io/openclaw/openclaw:${UPSTREAM_VERSION}

USER root

# Install Fonts
RUN apt-get update && apt-get install -y --no-install-recommends fonts-noto-cjk fonts-noto-cjk-extra fonts-wqy-zenhei fonts-wqy-microhei 

# Install Chromium
RUN apt-get update && apt-get install -y --no-install-recommends chromium

# install Coding Environment
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl dumb-init git-lfs locales lsb-release man-db nano vim-tiny wget zsh sudo \
        iputils-ping dnsutils net-tools iproute2 tcpdump netcat-openbsd traceroute mtr-tiny iperf3 nmap telnet openssh-client \ 
        htop iotop lsof procps sysstat file tree \
        gnupg software-properties-common build-essential gcc cmake g++ python3 python3-pip git vim ca-certificates openjdk-17-jdk maven gdb golang-go ffmpeg jq unzip zip \
        libreoffice-calc libreoffice-writer libreoffice-impress poppler-utils antiword catdoc tesseract-ocr tesseract-ocr-eng tesseract-ocr-chi-sim && \
    # Creat python link
    ln -sf /usr/bin/python3 /usr/bin/python && \
    # Install office document processing Python libraries
    pip install --no-cache-dir --break-system-packages\
        python-docx openpyxl xlrd python-pptx pypdf reportlab markitdown[pptx] PyMuPDF pdf2image pillow pytesseract textract pandas openai python-dotenv && \
    # Install Node.js packages for PPTX generation
    npm install -g pptxgenjs && \
    # Install PHP
    wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list && \
    apt-get update && \
    apt-get install -y  \
        php7.4 php7.4-cli php7.4-common php7.4-curl php7.4-xml php7.4-mbstring php7.4-zip \
        php8.4 php8.4-cli php8.4-common php8.4-curl php8.4-xml php8.4-mbstring php8.4-zip && \
    # Set PHP 8.4
    update-alternatives --set php /usr/bin/php8.4 && \
    # Install .NET 10 SDK
    wget https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && \
    sudo dpkg -i packages-microsoft-prod.deb && \
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

USER node

HEALTHCHECK --interval=3m --timeout=10s --start-period=15s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:18789/healthz').then((r)=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured"]
