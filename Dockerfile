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

WORKDIR /usr/local/apache2
# Copy the mirror-aosp script from the host machine to the desired location within the container
RUN mkdir -p aosp_mirror_script
COPY mirror-aosp.sh aosp_mirror_script/mirror-aosp.sh
RUN chmod +x aosp_mirror_script/mirror-aosp.sh

# Define the working directory for the container
WORKDIR /usr/local/apache2/htdocs

# Performance optimization for Git
RUN git config --system pack.threads "16" && \
    git config --system core.compression 9 && \
    git config --system http.postBuffer 524288000 && \
    git config --system core.bigFileThreshold 16m && \
    git config --system pack.windowMemory "32g" && \
    git config --system pack.packSizeLimit "2g" && \
    git config --system user.name "root" && \
    git config --system user.email "root@email.com"

# Copy extra configurations for apache throttling and git http server setup
COPY apache-performance.conf /usr/local/apache2/conf/extra/
COPY apache-server-name.conf /usr/local/apache2/conf/extra/
COPY git-http.conf /usr/local/apache2/conf/extra/

RUN echo "Include conf/extra/apache-performance.conf" >> /usr/local/apache2/conf/httpd.conf && \
    echo "Include conf/extra/apache-server-name.conf" >> /usr/local/apache2/conf/httpd.conf && \
    echo "Include conf/extra/git-http.conf" >> /usr/local/apache2/conf/httpd.conf

# Create a user in the password file
RUN htpasswd -bc /usr/local/apache2/htdocs/.htpasswd "$USERNAME" "$PASSWORD"

# Provide permissions to Apache user for Git repository directory
RUN chgrp -R www-data /usr/local/apache2/htdocs/* && \
    chown -R www-data:www-data /usr/local/apache2/htdocs/* && \
    chmod -R 775 /usr/local/apache2/htdocs/*

# Restart Apache
RUN apachectl -k restart

# Expose port 80
EXPOSE 80