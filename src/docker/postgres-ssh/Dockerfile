FROM postgres:18

RUN apt-get update \
 && apt-get install -y --no-install-recommends openssh-server
 # && rm -rf /var/lib/apt/lists/*

# SSH runtime
RUN mkdir -p /var/run/sshd /root/.ssh /var/lib/postgresql/.ssh \
 && chmod 700 /root/.ssh /var/lib/postgresql/.ssh \
 && chown -R postgres:postgres /var/lib/postgresql/.ssh

# Minimalnie poluzowane, żeby w dockerze nie było problemów
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config \
 && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
 && echo "PermitRootLogin no" >> /etc/ssh/sshd_config \
 && echo "AllowUsers postgres" >> /etc/ssh/sshd_config \
 && echo "UsePAM no" >> /etc/ssh/sshd_config

EXPOSE 22

# Start: sshd + standardowy entrypoint postgresa
COPY docker-entrypoint-with-sshd.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint-with-sshd.sh

ENTRYPOINT ["docker-entrypoint-with-sshd.sh"]
CMD ["postgres"]

