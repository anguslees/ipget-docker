# syntax=docker/dockerfile:1.2
FROM --platform=$BUILDPLATFORM golang@sha256:ef61a20960397f4d44b0e729298bf02327ca94f1519239ddc6d91689615b1367 AS builder

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

FROM --platform=$TARGETPLATFORM gcr.io/distroless/static@sha256:a43abc840a7168c833a8b3e4eae0f715f7532111c9227ba17f49586a63a73848

COPY --from=builder /out/ipget /usr/bin/ipget
ENTRYPOINT ["ipget"]
