# syntax=docker/dockerfile:1.2
FROM --platform=$BUILDPLATFORM golang@sha256:7b297d9abee021bab9046e492506b3c2da8a3722cbf301653186545ecc1e00bb AS builder

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

FROM --platform=$TARGETPLATFORM gcr.io/distroless/static@sha256:072d78bc452a2998929a9579464e55067db4bf6d2c5f9cde582e33c10a415bd1

COPY --from=builder /out/ipget /usr/bin/ipget
ENTRYPOINT ["ipget"]
