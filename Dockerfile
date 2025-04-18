# syntax=docker/dockerfile:1.15@sha256:05e0ad437efefcf144bfbf9d7f728c17818408e6d01432d9e264ef958bbd52f3
FROM --platform=$BUILDPLATFORM golang@sha256:d9db32125db0c3a680cfb7a1afcaefb89c898a075ec148fdc2f0f646cc2ed509 AS builder

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

FROM --platform=$TARGETPLATFORM gcr.io/distroless/static@sha256:3d0f463de06b7ddff27684ec3bfd0b54a425149d0f8685308b1fdf297b0265e9

COPY --from=builder /out/ipget /usr/bin/ipget
ENTRYPOINT ["ipget"]
