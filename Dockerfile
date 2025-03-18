# syntax=docker/dockerfile:1.14@sha256:4c68376a702446fc3c79af22de146a148bc3367e73c25a5803d453b6b3f722fb
FROM --platform=$BUILDPLATFORM golang@sha256:af0bb3052d6700e1bc70a37bca483dc8d76994fd16ae441ad72390eea6016d03 AS builder

# renovate: datasource=github-releases repoName=ipfs/ipget
ENV IPGET_VERSION=v0.7.0

RUN git clone -b ${IPGET_VERSION} https://github.com/ipfs/ipget.git /go/src/github.com/ipfs/ipget

WORKDIR /go/src/github.com/ipfs/ipget
RUN go mod download

ENV CGO_ENABLED=0
ENV GOCACHE=/go/.buildcache

ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
ENV GOOS=${TARGETOS}
ENV GOARCH=${TARGETARCH}

RUN \
        --mount=type=cache,target=/go/pkg/mod \
        --mount=type=cache,target=/go/.buildcache \
        set -e; \
        if [ "$TARGETARCH" = "arm" ]; then \
                GOARM="${TARGETVARIANT#v}"; \
                export GOARM; \
        fi; \
        go build -o /out/ipget

FROM --platform=$TARGETPLATFORM gcr.io/distroless/static@sha256:95ea148e8e9edd11cc7f639dc11825f38af86a14e5c7361753c741ceadef2167

COPY --from=builder /out/ipget /usr/bin/ipget
ENTRYPOINT ["ipget"]
