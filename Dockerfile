ARG USERNAME
ARG PASSWORD

# Use the official httpd image as base
FROM httpd:2.4

RUN apt-get update -y && apt-get install -y python3 gnupg curl vim
# Download and install repo tool with signature verification
RUN export REPO=$(mktemp /tmp/repo.XXXXXXXXX) && curl -o ${REPO} https://storage.googleapis.com/git-repo-downloads/repo && gpg --recv-key 8BB9AD793E8E6153AF0F9A4416530D5E920F5C65 && curl -s https://storage.googleapis.com/git-repo-downloads/repo.asc | gpg --verify - ${REPO} && install -m 755 ${REPO} /usr/bin/repo

WORKDIR /usr/local/apache2
# Copy the mirror-aosp script from the host machine to the desired location within the container
RUN mkdir -p aosp_mirror_script
COPY mirror-aosp.sh aosp_mirror_script/mirror-aosp.sh
RUN chmod +x aosp_mirror_script/mirror-aosp.sh

# Define the working directory for the container
WORKDIR /usr/local/apache2/htdocs

# Install git
RUN apt-get update && apt-get install -y git

# Enable required Apache modules: cgi, cgid, alias, env
RUN sed -i \
    -e 's/#LoadModule cgi_module modules\/mod_cgi.so/LoadModule cgi_module modules\/mod_cgi.so/' \
    -e 's/#LoadModule alias_module modules\/mod_alias.so/LoadModule alias_module modules\/mod_alias.so/' \
    -e 's/#LoadModule env_module modules\/mod_env.so/LoadModule env_module modules\/mod_env.so/' \
    -e 's/#LoadModule cgid_module modules\/mod_cgid.so/LoadModule cgid_module modules\/mod_cgid.so/' \
    /usr/local/apache2/conf/httpd.conf

# Create a user in the password file
RUN htpasswd -bc /usr/local/apache2/htdocs/.htpasswd "$USERNAME" "$PASSWORD"

# Add configuration for Git HTTP backend
RUN echo "SetEnv GIT_PROJECT_ROOT /usr/local/apache2/htdocs/aosp_mirror" >> /usr/local/apache2/conf/httpd.conf && \
    echo "SetEnv GIT_HTTP_EXPORT_ALL" >> /usr/local/apache2/conf/httpd.conf && \
    echo 'ScriptAlias "/git/" "/usr/lib/git-core/git-http-backend/"' >> /usr/local/apache2/conf/httpd.conf && \
    echo '<Files "git-http-backend">' >> /usr/local/apache2/conf/httpd.conf && \
    echo "    AuthType Basic" >> /usr/local/apache2/conf/httpd.conf && \
    echo '    AuthName "Git Access"' >> /usr/local/apache2/conf/httpd.conf && \
    echo "    AuthUserFile /usr/local/apache2/htdocs/.htpasswd" >> /usr/local/apache2/conf/httpd.conf && \
    echo "    Require expr !(%{QUERY_STRING} -strmatch '*service=git-receive-pack*' || %{REQUEST_URI} =~ m#/git-receive-pack\$#)" >> /usr/local/apache2/conf/httpd.conf && \
    echo "    Require valid-user" >> /usr/local/apache2/conf/httpd.conf && \
    echo "</Files>" >> /usr/local/apache2/conf/httpd.conf

# Provide permissions to Apache user for Git repository directory
RUN chgrp -R www-data /usr/local/apache2/htdocs/* && \
    chown -R www-data:www-data /usr/local/apache2/htdocs/* && \
    chmod -R 775 /usr/local/apache2/htdocs/*

# Restart Apache
RUN apachectl -k restart

# Expose port 80
EXPOSE 80
