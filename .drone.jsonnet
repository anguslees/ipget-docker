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
          ARG VERSION
          ARG COMMIT_SHA
          ARG COMMIT_AUTHOR_EMAIL
          LABEL \
           org.opencontainers.image.revision=$COMMIT_SHA \
           org.opencontainers.image.authors=$COMMIT_AUTHOR_EMAIL \
           org.opencontainers.image.url=https://github.com/ipfs/ipget \
           org.opencontainers.image.source=https://github.com/ipfs/ipget.git \
           org.opencontainers.image.version=$VERSION
          COPY $BIN /usr/bin/
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
      auto_tag: true,
      local env = {GOARM: ""} + imgs[k].env,
      auto_tag_suffix: env.GOOS + env.GOARCH + env.GOARM,
      build_args: [
        "BIN=ipget.%s" % k,
        "COMMIT_SHA=${DRONE_COMMIT_SHA}",
        "COMMIT_AUTHOR_EMAIL=${DRONE_COMMIT_AUTHOR_EMAIL}",
        "VERSION=${DRONE_TAG}",
      ],
    },
    when: {event: ["push"]},
  } for k in std.objectFields(imgs)] +
  [
    {
      name: "manifest",
      image: "plugins/manifest",
      settings: registry_settings {
        target: self.repo,
        template: self.repo + ":OSARCHVARIANT",
        platforms: [
          local env = {GOARM: ""} + imgs[k].env;
          std.join("/", [env.GOOS, env.GOARCH] + (
            if env.GOARM != "" then [env.GOARM] else []
          ))
          for k in std.objectFields(imgs)
        ],
      },
      when: {event: ["push"]},
    },
    {
      name: "publish",
      image: "banzaicloud/drone-kaniko",
      settings: registry_settings {
        auto_tag: true,
      },
      when: {event: ["push"]},
    },
  ],
}
