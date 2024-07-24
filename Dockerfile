# syntax=docker/dockerfile:1.2
FROM --platform=$BUILDPLATFORM golang@sha256:86a3c48a61915a8c62c0e1d7594730399caa3feb73655dfe96c7bc17710e96cf AS builder

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

FROM --platform=$TARGETPLATFORM gcr.io/distroless/static@sha256:ce46866b3a5170db3b49364900fb3168dc0833dfb46c26da5c77f22abb01d8c3

COPY --from=builder /out/ipget /usr/bin/ipget
ENTRYPOINT ["ipget"]
