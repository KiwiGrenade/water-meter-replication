FROM postgres:18

# skopiuj entrypoint do kontenera a nasępnie nadaj mu prawa wykonawcze
COPY docker/replica/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]
CMD ["postgres"]

