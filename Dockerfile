# The inside-a-container half of the fixture. Deliberately NOT distroless: the
# assertions need a shell. A real runtime image needs none of this — it only
# reads environment variables that were injected at `docker run`.
FROM debian:bookworm-slim
ARG SOPS_VERSION=3.13.1
ARG TARGETARCH=arm64
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends \
      bash git curl ca-certificates python3 && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL -o /usr/local/bin/sops \
      "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.${TARGETARCH}" \
    && chmod 0755 /usr/local/bin/sops
WORKDIR /fixture
COPY . .
ENV SOPS_AGE_KEY_FILE=/fixture/age.key
CMD ["./scripts/assert.sh"]
