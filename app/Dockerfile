# Aplicação estática servida pelo Apache (sem Node.js)
FROM httpd:2.4-alpine

EXPOSE 80

WORKDIR /usr/local/apache2/htdocs

COPY app.js index.html style.css healthcheck.html ./
COPY img/ ./img/

# Responde ao caminho /healthcheck usado pelas probes do Container Apps
RUN echo "Alias /healthcheck /usr/local/apache2/htdocs/healthcheck.html" >> /usr/local/apache2/conf/httpd.conf
