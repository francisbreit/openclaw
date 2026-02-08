# Dockerfile.openclaw-full
FROM node:22-bookworm AS build

# Instalar Bun (requerido pelo build)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"
RUN corepack enable

WORKDIR /app

# Cache de dependências
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

COPY . .
RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

# Produção
FROM node:22-bookworm

WORKDIR /app

# Copiar build
COPY --from=build /app /app

# Instalar CLI global
RUN npm install -g openclaw@latest

# Permite que o usuário node escreva arquivos
RUN chown -R node:node /app

USER node

ENV HOME=/home/node

# Verifica onboarding e executa
ENTRYPOINT ["sh", "-c", "\
  if [ ! -f /home/node/.openclaw/openclaw.json ]; then \
    echo 'No config found — running onboarding'; \
    openclaw onboard --yes && \
    echo 'Onboarding complete'; \
  fi && \
  echo 'Starting gateway...' && \
  openclaw gateway --port 18789 --bind lan \
"]
