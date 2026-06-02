FROM --platform=linux/amd64 alpine:3.22

# Small docker image to allow using fasm and zig on macOS with Apple Silicon (arm64).

RUN apk add --no-cache curl tar gzip xz bash binutils \
    && curl -L -o /tmp/fasm.tgz https://flatassembler.net/fasm-1.73.35.tgz \
    && tar -xzf /tmp/fasm.tgz -C /opt \
    && rm /tmp/fasm.tgz \
    && curl -L -o /tmp/zig.tar.xz https://ziglang.org/download/0.16.0/zig-x86_64-linux-0.16.0.tar.xz \
    && tar -xJf /tmp/zig.tar.xz -C /opt \
    && mv /opt/zig-x86_64-linux-0.16.0 /opt/zig \
    && rm /tmp/zig.tar.xz

ENV PATH="/opt/fasm:/opt/zig:${PATH}"
