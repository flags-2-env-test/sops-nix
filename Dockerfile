FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      bash ca-certificates git nix-bin xz-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /fixture
COPY . .

# The Docker build context intentionally excludes caller Git metadata. Recreate
# a tiny repository so the shared Git ignore/index assertions stay meaningful.
RUN git init -q \
    && git config user.name fixture \
    && git config user.email fixture@example.invalid \
    && git add -A \
    && git commit -qm fixture

CMD ["nix", "--extra-experimental-features", "nix-command", "--extra-experimental-features", "flakes", "--option", "sandbox", "false", "--option", "build-users-group", "", "run", "--no-write-lock-file", ".#verify"]
