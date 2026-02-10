# Project Escape Hatch: Self‑Hosted Chat Infrastructure

This repository contains a Docker‑based, self‑hosted chat and voice stack designed for a small group of trusted friends.

The goal is to provide a **Discord‑like experience**, while:
- Minimizing long‑term dependence on third‑party platforms
- Keeping configuration understandable and auditable
- Favoring privacy, stability, and boring reliability over growth or federation

This is **not** intended to be a public service.

---

## 🧱 Services Provided

### Matrix Stack
- **Synapse** – Matrix homeserver (federation disabled)
- **Element Web** – Primary web chat UI
- **Element Call** – Video rooms, presentations, and conferencing

### Voice Chat
- **Mumble Server** – Low‑latency group voice chat
- **Mumble Web** – Browser‑based access (experimental)
- **Botamusique** – Music playback bot for Mumble (version‑pinned)

### Website
- Lightweight static site at the root domain providing:
  - Links to all services
  - Client download instructions
  - Status / news updates
  - Contact info for requesting access

---

## 🧠 Design Principles

- **Invite‑only**: No public registration or discovery
- **No federation**: Matrix is fully closed to other servers
- **Minimal exposed ports**: nginx is the primary ingress
- **Composable**: Services are split into multiple Compose files
- **Auditable**: Plain YAML, no hidden automation

---

## 📁 Repository Layout

```text
self-hosted-chat/
├── docker-compose.yml        # Core services (nginx, fail2ban)
├── .env.example              # Environment variable template
├── .env                      # Local secrets (NOT committed)
├── nginx/                    # Reverse proxy + TLS
├── synapse/                  # Matrix backend + Postgres
├── element/                  # Element Web frontend
├── element-call/             # Video / conferencing
├── mumble/                   # Voice server
├── botamusique/              # Music bot
└── website/                  # Root landing page
```

Each service has its own `compose.yml` and persistent data directories where applicable.

---

## 🔐 Access Model

- All services are **invite‑only**
- A shared **friend code** is used for:
  - Initial Matrix account creation
  - Mumble server password
- No public room directory
- No federation

If you do not have an invite, request one via the contact page on the root website.

---

## 🚀 Deployment (Admin)

### Prerequisites
- Ubuntu 22.04+ server
- Docker Engine
- Docker Compose v2 plugin
- DNS records pointing to the server

### First‑time setup

```bash
cd self-hosted-chat
cp .env.example .env
# edit .env with real values
```

Bring everything up:

```bash
docker compose \
  -f docker-compose.yml \
  -f synapse/compose.yml \
  -f element/compose.yml \
  -f element-call/compose.yml \
  -f mumble/compose.yml \
  -f botamusique/compose.yml \
  -f website/compose.yml \
  up -d
```

Validate configuration:

```bash
docker compose config
```

---

## 🛡 Security Notes

- SSH password login is disabled (key‑only access)
- nginx rate limiting on login endpoints
- Fail2ban monitors auth failures
- Secrets are stored only in `.env`
- Persistent data directories are excluded from Git

---

## 📦 Backups (Recommended)

At minimum, back up:
- `synapse/data/`
- `synapse/db/`
- `mumble/data/`

Media and configuration loss is recoverable; chat history is not.

---

## 🧭 Project Status

This project is under active development.

Upcoming work:
- Synapse `homeserver.yaml` hardening
- nginx `.well-known` configuration
- Element defaults & sticker packs
- Mumble Web tuning
- Automated backups

---

## 🤝 Contributing

This is a private infrastructure project for friends.

If you are part of the group:
- Keep changes small and reviewable
- Avoid committing secrets
- Document breaking changes in the website news page

---

## 📄 License

Configuration and documentation are provided as‑is.

Use at your own risk. Self‑hosting means you own the consequences 😄

