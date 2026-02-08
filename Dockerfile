# Base: imagem oficial do código OpenClaw
FROM node:22-bookworm

# Instala Bun (necessário para scripts de build do projeto)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

# Permite adicionar pacotes APT extras se necessário
ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

# Copia arquivos essenciais para instalar dependências
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

# Copia o restante do código e builda
COPY . .
RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build

# Build da UI (Front-end)
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

ENV NODE_ENV=production

# **Instala o CLI global aqui**
RUN npm install -g openclaw@latest

# Permite ao usuário node escrever arquivos temporários
RUN chown -R node:node /app

USER node

# Entrada padrão: não starta o gateway automático
# Isso permite usar este container também para CLI
ENTRYPOINT ["sh"]
