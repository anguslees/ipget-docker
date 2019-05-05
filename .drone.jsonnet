local goimg = "golang:1.12.4";

local registry_settings = {
  registry: "quay.io",
  repo: "quay.io/anguslees/ipget",
  username: {from_secret: "docker_username"},
  password: {from_secret: "docker_password"},
};

local imgs = {
  amd64: {
    env: {
      GOOS: "linux",
      GOARCH: "amd64",
    },
  },
  armv6: {
    env: {
      GOOS: "linux",
      GOARCH: "arm",
      GOARM: "6",
    },
  },
  armv7: {
    env: {
      GOOS: "linux",
      GOARCH: "arm",
      GOARM: "7",
    },
  },
  arm64: {
    env: {
      GOOS: "linux",
      GOARCH: "arm64",
    },
  },
};

{
  kind: "pipeline",
  name: "default",

  clone: {disable: true},

  workspace: {
    base: "/go",
    path: "src/github.com/ipfs/ipget",
  },

  steps: [
    {
      name: "myclone",
      image: "docker:git",
      commands: [
        "git clone -b ${DRONE_TAG:-master} https://github.com/ipfs/ipget.git $DRONE_WORKSPACE",
      ],
    },
    {
      name: "deps",
      image: goimg,
      commands: [
        "make deps",
        |||
          cat <<EOF >Dockerfile
          FROM scratch
          ARG BIN=ipget
          LABEL \
           org.opencontainers.image.revision=$DRONE_COMMIT_SHA \
           org.opencontainers.image.authors="$DRONE_COMMIT_AUTHOR_EMAIL" \
           org.opencontainers.image.url=https://github.com/ipfs/ipget \
           org.opencontainers.image.source=https://github.com/ipfs/ipget.git \
           org.opencontainers.image.version=$DRONE_TAG
          COPY \\$$BIN /usr/bin/ipget
          ENTRYPOINT ["ipget"]
          EOF
        |||,
      ],
    },
  ] +
  [{
    name: k,
    image: goimg,
    environment: {
      CGO_ENABLED: 0,
    } + imgs[k].env,
    commands: [
      "go build -ldflags='-s -w -extldflags=-static' -tags netgo -installsuffix netgo -o ipget.%s" % k,
    ],
  } for k in std.objectFields(imgs)] +
  [{
    name: "docker-%s" % k,
    image: "banzaicloud/drone-kaniko",
    settings: registry_settings {
      local env = {GOARM: ""} + imgs[k].env,
      tags: "${DRONE_COMMIT_SHA}-" + env.GOOS + env.GOARCH + env.GOARM,
      build_args: [
        "BIN=ipget.%s" % k,
      ],
    },
    when: {event: ["push", "tag"]},
  } for k in std.objectFields(imgs)] +
  [
    {
      name: "manifest",
      image: "plugins/manifest",
      settings: registry_settings {
        template: self.repo + ":${DRONE_COMMIT_SHA}-OSARCHVARIANT",
        platforms: [
          local env = {GOARM: ""} + imgs[k].env;
          std.join("/", [env.GOOS, env.GOARCH] + (
            if env.GOARM != "" then [env.GOARM] else []
          ))
          for k in std.objectFields(imgs)
        ],
      },
      when: {event: ["push", "tag"]},
    },
  ],
}
