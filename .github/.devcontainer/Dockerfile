FROM mcr.microsoft.com/devcontainers/base:ubuntu

ARG DEBIAN_FRONTEND=noninteractive
ARG OPENCODE_VERSION=1.2.10

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl unzip git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# .NET SDK 10.0.102 LTS
RUN curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin \
      --version 10.0.102 \
      --install-dir /usr/share/dotnet \
    && ln -sf /usr/share/dotnet/dotnet /usr/local/bin/dotnet
ENV DOTNET_ROOT=/usr/share/dotnet
ENV PATH="${PATH}:${DOTNET_ROOT}:${DOTNET_ROOT}/tools"

# Avalonia templates
RUN dotnet new install Avalonia.Templates

# Bun
ENV BUN_INSTALL=/usr/local/bun
ENV PATH="${BUN_INSTALL}/bin:${PATH}"
RUN curl -fsSL https://bun.sh/install | bash \
    && ln -sf "${BUN_INSTALL}/bin/bun" /usr/local/bin/bun

# uv (Astral Python package manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && cp /root/.local/bin/uv /usr/local/bin/uv \
    && cp /root/.local/bin/uvx /usr/local/bin/uvx \
    && chmod +x /usr/local/bin/uv /usr/local/bin/uvx

# opencode CLI
RUN curl -fsSL https://opencode.ai/install | bash -s -- --version "${OPENCODE_VERSION}" --no-modify-path \
    && cp /root/.opencode/bin/opencode /usr/local/bin/opencode \
    && chmod +x /usr/local/bin/opencode
