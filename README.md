# ScarCoin – scarcoin-agentnet

[![CI](https://github.com/ZoaGrad/scarcoin-agentnet/actions/workflows/ci.yml/badge.svg)](https://github.com/ZoaGrad/scarcoin-agentnet/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/ZoaGrad/scarcoin-agentnet?display_name=tag&sort=semver)](https://github.com/ZoaGrad/scarcoin-agentnet/releases)
[![CodeQL](https://github.com/ZoaGrad/scarcoin-agentnet/actions/workflows/codeql.yml/badge.svg)](https://github.com/ZoaGrad/scarcoin-agentnet/actions/workflows/codeql.yml)
[![Dependabot](https://img.shields.io/badge/dependabot-enabled-brightgreen.svg?logo=dependabot)](https://github.com/ZoaGrad/scarcoin-agentnet/network/updates)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## 📖 Description
AgentNet is a minimal FastAPI service for the ScarCoin constellation. It will host agent-facing endpoints (e.g., witness logging, oracle relays, Supabase hooks). First-Ship exposes `/ping`.

---

## 🚀 Quickstart
```bash
git clone https://github.com/ZoaGrad/scarcoin-agentnet.git
cd scarcoin-agentnet
pip install -r requirements.txt
uvicorn scarcoin_agentnet.main:app --reload
# visit http://127.0.0.1:8000/ping
```

---

## ✅ Status

* CI: runs pytest
* CodeQL: enabled
* Dependabot: weekly
* Release: automated with release-please
