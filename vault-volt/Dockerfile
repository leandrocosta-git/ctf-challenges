FROM localstack/localstack:3.0.2

COPY setup_vault.sh /etc/localstack/init/ready.d/setup_vault.sh
RUN chmod +x /etc/localstack/init/ready.d/setup_vault.sh

COPY landingpage/index.html /opt/volt-vault/index.html
COPY landingpage/serve.sh /etc/localstack/init/boot.d/serve.sh
RUN chmod +x /etc/localstack/init/boot.d/serve.sh

EXPOSE 8080
