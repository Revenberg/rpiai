FROM arm64v8/debian:bookworm-slim

ENV OLLAMA_HOST=0.0.0.0:11434 \
    OLLAMA_MODELS=/models

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl tini \
    && rm -rf /var/lib/apt/lists/*

# Install latest stable Ollama for ARM64.
RUN curl -fsSL https://ollama.com/install.sh | sh

COPY init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

EXPOSE 11434
VOLUME ["/models"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=5 \
  CMD curl -fsS http://127.0.0.1:11434/api/tags > /dev/null || exit 1

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/bin/init.sh"]
