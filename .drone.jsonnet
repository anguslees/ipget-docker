local goimg = "golang:1.12.4";

local repo = "quay.io/anguslees/ipget";

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
          COPY ipget /usr/bin/
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
      "go build -ldflags='-s -w -extldflags=-static' -tags netgo -installsuffix netgo -o %s/ipget" % k,
      "cp Dockerfile %s/" % k,
    ],
  } for k in std.objectFields(imgs)] +
  [{
    name: "docker-%s" % k,
    image: "banzaicloud/drone-kaniko",
    settings: {
      context: k,
      repo: repo,
      auto_tag: true,
      local env = {GOARM: ""} + imgs[k].env,
      auto_tag_suffix: env.GOOS + env.GOARCH + env.GOARM,
      username: {from_secret: "docker_username"},
      password: {from_secret: "docker_password"},
    },
    when: {event: ["push"]},
  } for k in std.objectFields(imgs)] +
  [
    {
      name: "manifest",
      image: "plugins/manifest",
      settings: {
        target: repo,
        template: repo + ":OSARCHVARIANT",
        platforms: [
          local env = {GOARM: ""} + imgs[k].env;
          std.join("/", [env.GOOS, env.GOARCH] + (
            if env.GOARM != "" then [env.GOARM] else []
          ))
          for k in std.objectFields(imgs)
        ],
        username: {from_secret: "docker_username"},
        password: {from_secret: "docker_password"},
      },
      when: {event: ["push"]},
    },
    {
      name: "publish",
      image: "banzaicloud/drone-kaniko",
      settings: {
        repo: repo,
        auto_tag: true,
        username: {from_secret: "docker_username"},
        password: {from_secret: "docker_password"},
      },
      when: {event: ["push"]},
    },
  ],
}
