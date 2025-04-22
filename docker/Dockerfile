# Define build arguments
ARG USERNAME
ARG PASSWORD

# Use the official httpd image as base
FROM httpd:2.4

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
    python3 \
    gnupg \
    curl \
    vim \
    git \
    openssh-client \
    libapache2-mod-fcgid && \
    rm -rf /var/lib/apt/lists/*

# Download and install repo tool with signature verification
RUN export REPO=$(mktemp /tmp/repo.XXXXXXXXX) && \
    curl -o ${REPO} https://storage.googleapis.com/git-repo-downloads/repo && \
    gpg --recv-key 8BB9AD793E8E6153AF0F9A4416530D5E920F5C65 && \
    curl -s https://storage.googleapis.com/git-repo-downloads/repo.asc | gpg --verify - ${REPO} && \
    install -m 755 ${REPO} /usr/bin/repo

# Define the working directory for the container
WORKDIR /usr/local/apache2/htdocs

# Performance optimization for Git
RUN git config --system pack.threads "16" && \
    git config --system core.compression 9 && \
    git config --system http.postBuffer 524288000 && \
    git config --system core.bigFileThreshold 16m && \
    git config --system pack.windowMemory "32g" && \
    git config --system pack.packSizeLimit "2g" && \
    git config --system user.name "www-data" && \
    git config --system user.email "www-data@email.com"

# Copy extra configurations for apache throttling and git http server setup
COPY ./apache-config/apache-performance.conf /usr/local/apache2/conf/extra/
COPY ./apache-config/apache-server-name.conf /usr/local/apache2/conf/extra/
COPY ./apache-config/git-http.conf /usr/local/apache2/conf/extra/
COPY ./apache-config/healthcheck.conf /usr/local/apache2/conf/extra/

RUN echo "Include conf/extra/apache-performance.conf" >> /usr/local/apache2/conf/httpd.conf && \
    echo "Include conf/extra/apache-server-name.conf" >> /usr/local/apache2/conf/httpd.conf && \
    echo "Include conf/extra/git-http.conf" >> /usr/local/apache2/conf/httpd.conf && \
    echo "Include conf/extra/healthcheck.conf" >> /usr/local/apache2/conf/httpd.conf && \
    git config --system --add safe.directory '*'

# Copy the entrypoint script and set permissions
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set custom entrypoint (starts Apache after setup)
ENTRYPOINT ["/entrypoint.sh"]

# Expose port 80
EXPOSE 80