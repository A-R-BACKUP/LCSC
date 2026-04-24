# LCSC
**TEST ONLY**

**Effectively abandoned due to performance limits.**

**Might've been a different story with a GPU in the mix...**



Self-hosted Open WebUI + SearXNG + Redis + Ollama on a single server.
Local inference only (gemma4:e2b, CPU). No external API calls.



## Port Map

| Service    | External Port | Internal |
|------------|--------------|---------|
| Open WebUI | 7777         | 8080    |
| SearXNG    | 7778 (debug) | 8080    |
| Redis      | none         | 6379    |
| Ollama     | none         | 11434   |

## Initial Installation

### Prerequisites

- Docker and Docker Compose plugin installed
- `jq`, `curl`, `openssl`, `ss` (iproute2) available on the host
- Ports 7777 and 7778 free

### Steps

**1. Run setup script**

```
./setup.sh
```

Generates `.env` with a random `SEARXNG_SECRET` and produces
`searxng/settings.yml` from the template. Each step prints `[OK]` or `[NG]`.

**2. Start all services**

```
docker compose up -d
```

**3. Pull the model (first time only)**

```
docker compose exec ollama ollama pull gemma4:e2b
```

Downloads approximately 3.2 GB. Wait for completion before proceeding.
Do not pull 27B or larger variants; the server lacks sufficient RAM.

**4. Verify the stack**

```
./verify.sh
```

Runs five health checks. The inference test (step 5) requires the model
to be fully loaded, which may take up to 2 minutes on first run.

**5. Open the browser**

Navigate to `http://<server-ip>:7777` and create an admin account.

**6. Set num_ctx to 16384**

In the Open WebUI admin panel:
`Admin Panel > Models > gemma4:e2b > Advanced Parameters > num_ctx = 16384`

The default of 2048 truncates web search context and produces incomplete
answers. This setting must be applied manually after the model is loaded.

## Operational Commands

**Start**
```
docker compose up -d
```

**Stop**
```
docker compose down
```

**View logs (all services)**
```
docker compose logs -f
```

**View logs (single service)**
```
docker compose logs -f open-webui
docker compose logs -f searxng
docker compose logs -f ollama
```

**Pull image updates**
```
docker compose pull
docker compose up -d
```

Note: `latest` tags change on pull. Record image digests before updating
in production:
```
docker compose images
```

**List loaded Ollama models**
```
docker compose exec ollama ollama list
```

**Remove a model**
```
docker compose exec ollama ollama rm <model-name>
```
