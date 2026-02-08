# Estágio de build
FROM node:22-bookworm AS build

# Instalar Bun (requerido pelo build)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

# Copiar arquivos de dependências
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

# Copiar o restante do projeto e buildar
COPY . .
RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

# Estágio final (produção)
FROM node:22-bookworm

WORKDIR /app

# Copiar artefatos do build
COPY --from=build /app /app

# Instalar CLI globalmente
RUN npm install -g openclaw@latest

# Permite o usuário 'node' escrever arquivos
RUN chown -R node:node /app

USER node
ENV HOME=/home/node

# Onboarding não interativo com OpenAI
ENTRYPOINT ["sh", "-c", "\
  if [ ! -f /home/node/.openclaw/openclaw.json ]; then \
    echo 'No config found — running non-interactive onboarding'; \
    openclaw onboard --non-interactive \
      --mode local \
      --auth-choice apiKey \
      --openai-api-key \"$OPENAI_API_KEY\" \
      --gateway-port 18789 \
      --gateway-bind lan \
      --skip-skills \
      --install-daemon; \
    echo 'Onboarding complete'; \
  fi && \
  echo 'Starting gateway...' && \
  openclaw gateway --port 18789 --bind lan \
"]
