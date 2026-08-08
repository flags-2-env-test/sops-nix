FROM nixos/nix:2.35.1-amd64

RUN apk add --no-cache bash ca-certificates git

WORKDIR /fixture
COPY . .

# The Docker build context intentionally excludes caller Git metadata. Recreate
# a tiny repository so the shared Git ignore/index assertions stay meaningful.
RUN git init -q \
    && git config user.name fixture \
    && git config user.email fixture@example.invalid \
    && git add -A \
    && git commit -qm fixture

CMD ["nix", "--extra-experimental-features", "nix-command", "--extra-experimental-features", "flakes", "--option", "sandbox", "false", "run", "--no-write-lock-file", ".#verify"]
