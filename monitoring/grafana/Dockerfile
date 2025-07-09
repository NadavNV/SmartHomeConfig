FROM grafana/grafana:latest

USER root

COPY dashboards /var/lib/grafana/dashboards
COPY provisioning /etc/grafana/provisioning
COPY create-viewer.sh /etc/grafana/create-viewer.sh
COPY startup.sh /etc/grafana/startup.sh

RUN chmod +x /etc/grafana/create-viewer.sh /etc/grafana/startup.sh

# Install dos2unix and clean up dashboard files (line endings and BOM)
RUN apt-get update && apt-get install -y dos2unix && \
    find /var/lib/grafana/dashboards -name '*.json' -exec dos2unix {} + && \
    find /var/lib/grafana/dashboards -name '*.json' -exec sed -i '1s/^\xEF\xBB\xBF//' {} + && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

CMD ["/etc/grafana/startup.sh"]
