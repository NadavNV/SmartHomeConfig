FROM grafana/grafana:latest

USER root

COPY dashboards /var/lib/grafana/dashboards
COPY provisioning /etc/grafana/provisioning
COPY create-viewer.sh /etc/grafana/create-viewer.sh
COPY startup.sh /etc/grafana/startup.sh

RUN chmod +x /etc/grafana/create-viewer.sh /etc/grafana/startup.sh

# Install dos2unix and clean dashboard files
RUN apk add --no-cache dos2unix && \
    find /var/lib/grafana/dashboards -name '*.json' -exec dos2unix {} + && \
    find /var/lib/grafana/dashboards -name '*.json' -exec sed -i '1s/^\xEF\xBB\xBF//' {} +

CMD ["/etc/grafana/startup.sh"]
