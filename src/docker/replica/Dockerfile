FROM postgres:18

RUN apt-get update \
 && apt-get install -y openssh-server openssh-sftp-server openssh-client iproute2


# SSH runtime (ROOT)
RUN mkdir -p /var/run/sshd /root/.ssh \
 && chmod 700 /root/.ssh

# SSH config
RUN echo "PasswordAuthentication no" >>  /etc/ssh/sshd_config \
 && echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config \
 && echo "PermitRootLogin yes" >> /etc/ssh/sshd_config \
 && echo "UsePAM no" >> /etc/ssh/sshd_config \
 && echo "AuthorizedKeysFile /root/.ssh/authorized_keys" >> /etc/ssh/sshd_config

COPY docker/replica/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]
CMD ["postgres"]

