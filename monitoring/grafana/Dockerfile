FROM grafana/grafana:latest

USER root

COPY dashboards /var/lib/grafana/dashboards
COPY provisioning /etc/grafana/provisioning
COPY startup.sh /startup.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /startup.sh
RUN chmod +x /entrypoint.sh

RUN apk add --no-cache jq
RUN apk add --no-cache grep

# Install dos2unix and clean dashboard files
RUN apk add --no-cache dos2unix && \
    find /var/lib/grafana/dashboards -name '*.json' -exec dos2unix {} + && \
    find /var/lib/grafana/dashboards -name '*.json' -exec sed -i '1s/^\xEF\xBB\xBF//' {} +

# Entrypoint will wait for Grafana then run the setup script
ENTRYPOINT ["/entrypoint.sh"]
