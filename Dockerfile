ARG USERNAME
ARG PASSWORD

# Use the official httpd image as base
FROM httpd:2.4

# Install git
RUN apt-get update && apt-get install -y git

# Initialize a bare Git repository
RUN mkdir -p /usr/local/apache2/htdocs/myproject.git && \
    git init --bare /usr/local/apache2/htdocs/myproject.git && \
    git config --global --add safe.directory /usr/local/apache2/htdocs/myproject.git

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
RUN echo "SetEnv GIT_PROJECT_ROOT /usr/local/apache2/htdocs" >> /usr/local/apache2/conf/httpd.conf && \
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
RUN chgrp -R www-data /usr/local/apache2/htdocs && \
    chown -R www-data:www-data /usr/local/apache2/htdocs/myproject.git && \
    chmod -R 775 /usr/local/apache2/htdocs/myproject.git

# Restart Apache
RUN apachectl -k restart

# Expose port 80
EXPOSE 80