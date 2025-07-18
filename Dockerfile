FROM jenkins/jenkins:lts

USER root
# Install Node.js to run frontend unit tests
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - && \
    apt-get install -y nodejs

# Install Docker CLI
RUN apt-get update && apt-get install -y docker.io

# Create docker group with matching GID
RUN groupmod -g 1001 docker && \
    usermod -aG docker jenkins

# Entrypoint script to fix socket permissions
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]