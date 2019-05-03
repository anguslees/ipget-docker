FROM scratch
COPY ipget /usr/bin/
ENTRYPOINT ["ipget"]
