FROM scratch
ARG BIN=ipget
ARG REVISION=""
ARG VERSION=""
ARG AUTHORS=""
LABEL \
        org.opencontainers.image.revision=$REVISION \
        org.opencontainers.image.authors="$AUTHORS" \
        org.opencontainers.image.url=https://github.com/ipfs/ipget \
        org.opencontainers.image.source=https://github.com/ipfs/ipget.git \
        org.opencontainers.image.version=$VERSION

COPY $BIN /usr/bin/ipget
ENTRYPOINT ["ipget"]
