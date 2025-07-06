FROM grafana/grafana:latest

COPY dashboards /var/lib/grafana/dashboards
COPY provisioning /etc/grafana/provisioning
COPY create-viewer.sh /etc/grafana/create-viewer.sh
COPY startup.sh /etc/grafana/startup.sh

RUN chmod +x /etc/grafana/create-viewer.sh /etc/grafana/startup.sh

CMD ["/etc/grafana/startup.sh"]
