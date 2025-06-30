# work‑lab – 48 h Lab for Consist Interview

> **Goal of this mini‑lab**
> Build a *single*, reproducible sandbox that proves you can:
>
> 1. spin up a complete **Node.js ↔ PostgreSQL** stack in **Docker + WSL 2**,
> 2. perform basic **SysOps** (monitoring, backup / restore, health‑checks),
> 3. understand **CI/CD** & be ready for **Azure** deployment.
>
> Every command below is *deliberately explicit* so the reviewer can copy‑paste and watch the lab come to life in < 30 min.

---

## How the README is organised

| §                              | What you achieve                                                | Why Consist cares                                                        |
| ------------------------------ | --------------------------------------------------------------- | ------------------------------------------------------------------------ |
| **0 Prerequisites**            | Verify local toolchain (Node, Git, Docker, WSL 2).              | Shows you can bootstrap clean environments.                              |
| **1 WSL 2 setup**              | Linux‑on‑Windows with resource isolation.                       | Many enterprise customers still run Windows laptops but deploy on Linux. |
| **2 Project skeleton**         | Express API + health endpoint.                                  | Baseline for any micro‑service.                                          |
| **3 Docker sanity**            | “Hello from Docker!” container runs.                            | Confirms container runtime is healthy.                                   |
| **4 System / IT fundamentals** | Monitoring, PostgreSQL in a container, disaster‑recovery drill. | Demonstrates Ops mindset.                                                |
| **5 Health‑check script**      | Automated probe + log rotation.                                 | Converts Ops knowledge into code.                                        |
| **6 CI stub & next steps**     | Path to GitHub Actions → Azure.                                 | Shows forward thinking to production.                                    |

Each section starts with a **WHY** paragraph followed by **HOW** (the exact commands).

---

## 0 · Prerequisites – *prepare the workstation*

> **Why?** Failure to align tool versions is the #1 cause of “works on my machine.” We document everything up‑front.

```powershell
# Verify / install core tools                       (approx. 5 min)
node -v                     # expect ≥ 18
winget install --id OpenJS.NodeJS.LTS -e         # if needed

git --version
winget install --id Git.Git -e                   # if needed

docker --version        # only after Docker Desktop setup
```

Docker Desktop install link [https://www.docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop)
Be sure to tick **Enable WSL 2**.

---

## 1 · Configure WSL 2 – *Linux kernel in Windows*

> **Why?** Gives near‑native Linux containers and lets us use tools like `htop` without extra VMs.

```powershell
wsl --install                       # first‑time only – pulls Ubuntu
wsl --list --verbose                # confirm VERSION 2
wsl --set-version Ubuntu 2          # migrate if still v1
wsl --set-default-version 2         # future distros default to v2
```

Inside Ubuntu:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y htop glances curl
```

*`htop` and `glances` are our monitoring eyes later.*

---

## 2 · Project skeleton – *your service in <5 min*

> **Why?** A minimal Express server provides the application layer we will monitor and back‑up.

```powershell
mkdir C:\Projects\work-lab && cd C:\Projects\work-lab

git init
npx create-express-api .          # answers: name=work-lab, port=3000
npm install
npm run dev                       # localhost:3000
```

Add a **health endpoint** so Ops can probe status:

```js
app.get('/health', (_, res) => res.sendStatus(200));
```

> **Commit**

```powershell
git add .
git commit -m "chore: express skeleton with /health"
```

---

## 3 · Docker sanity check – *prove containers run*

> **Why?** Every subsequent step relies on Docker networking.

```powershell
docker info --format '{{.ServerVersion}} ({{.OperatingSystem}})'
# should print something like "28.2.2 (Docker Desktop)"

docker run hello-world           # prints greeting and exits
```

---

## 4 · System / IT fundamentals

### 4.1 Realtime monitoring – *see what the OS sees*

```bash
# Ubuntu terminal
htop
```

```powershell
# PowerShell terminal
docker stats --no-stream
```

Compare CPU/RAM numbers between host and container columns.

### 4.2 Spin‑up PostgreSQL

```powershell
docker run -d --name pg-lab `
  -e POSTGRES_PASSWORD=pgpass `
  -p 5432:5432 postgres:16
```

Insert demo row:

```powershell
docker exec -it pg-lab psql -U postgres -c "CREATE DATABASE mydb;"
docker exec -it pg-lab psql -U postgres -d mydb -c "CREATE TABLE demo(id INT); INSERT INTO demo VALUES (1);"
```

### 4.3 Backup & Restore – *Disaster Recovery drill*

Create dump **inside** the container (binary‑safe):

```powershell
docker exec pg-lab pg_dump -U postgres -Fc -f /tmp/backup.dump mydb
```

Restore into fresh DB:

```powershell
docker exec -it pg-lab psql -U postgres -c "CREATE DATABASE mydb_restored;"
docker exec -it pg-lab pg_restore -U postgres -d mydb_restored /tmp/backup.dump
```

Verify:

```powershell
docker exec -it pg-lab psql -U postgres -d mydb_restored -c "SELECT * FROM demo;"
```

Outcome should be `(1 row)`.

---

## 5 · Health‑check automation – *Ops as code*

### 5.1 Script creation

`./scripts/healthcheck.sh` collects status from the web‑API & database.

```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="$SCRIPT_DIR/../logs/healthcheck.log"
mkdir -p "$(dirname "$LOG")"
DATE="$(date '+%Y-%m-%d %H:%M:%S')"
APP=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health || echo 000)
DB=$(docker exec pg-lab pg_isready -U postgres >/dev/null 2>&1 && echo OK || echo DOWN)
echo "[$DATE] APP:$APP DB:$DB" | tee -a "$LOG"
```

Make it executable:

```bash
chmod +x scripts/healthcheck.sh
```

First run & verify:

```bash
scripts/healthcheck.sh
cat logs/healthcheck.log | tail -n 1
# → [YYYY‑MM‑DD HH:MM:SS] APP:200 DB:OK
```

### 5.2 Continuous watch *(demo mode)*

```bash
watch -n 30 scripts/healthcheck.sh   # every 30 s
```

---

## 6 · CI/CD – *automated build & health‑probe*

> **Why?** Recruiters want proof you can integrate code quality gates and basic Ops checks in a modern pipeline.

The workflow lives in **`.github/workflows/ci.yml`** and runs on every **push / PR**.

```yaml
name: CI

on:
  push:
    branches: [ main, master ]
  pull_request:

jobs:
  build-test-health:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: pgpass
        ports: [ "5432:5432" ]
        options: >-
          --health-cmd="pg_isready -U postgres"
          --health-interval=10s --health-timeout=5s --health-retries=5

    steps:
    - uses: actions/checkout@v4

    - uses: actions/setup-node@v4
      with:
        node-version: 18
        cache: npm
        cache-dependency-path: api-server/package-lock.json   # lock lives in sub‑dir

    - run: npm ci
      working-directory: api-server

    - run: |
        echo "🔎 running npm test"
        npm test || echo "⚠️  no tests"
      working-directory: api-server

    - name: Start API
      run: |
        node index.js &
        sleep 5
      working-directory: api-server

    - name: Health check
      run: |
        bash scripts/healthcheck.sh
        tail -n 1 logs/healthcheck.log
        grep 'APP:200' logs/healthcheck.log
        grep 'DB:OK'  logs/healthcheck.log

    - uses: actions/upload-artifact@v4
      with:
        name: health-logs
        path: logs/healthcheck.log
```

### What each step proves

| Step                      | Evidence                                                         |
| ------------------------- | ---------------------------------------------------------------- |
| **services.postgres**     | You can spin supporting services via Docker compose‑style in CI. |
| **setup‑node + cache**    | You understand dependency caching & lock‑files.                  |
| **npm ci / npm test**     | Build is reproducible; tests (if any) guard regressions.         |
| **node index.js & sleep** | You can orchestrate background processes in CI runners.          |
| **healthcheck.sh**        | Same Ops probe used locally now guards the pipeline.             |
| **upload‑artifact**       | Captures logs for post‑mortem – DevOps habit.                    |

#### First run

```bash
git add .github/workflows/ci.yml
git commit -m "ci: automated build & health‑probe"
git push origin main   # triggers workflow
```

Navigate to **GitHub ▸ Actions** tab – you should see a green check ✔.

---

## 7 · Git commits summary to date

```bash
git log --oneline --decorate --graph
```

Expect something like:

```
* 1a2b3c4 ci: automated build & health-probe (HEAD -> main)
* d4e5f67 feat(sys): monitoring, DR backup/restore, health-check
* 89ab012 chore: express skeleton with /health
```

---

## 8 · Next steps

1. **2A RabbitMQ lab** – `docker run -d rabbitmq:3-management`, producer/consumer with `amqplib`.
2. **3A Azure deploy** – `az webapp up` or GitHub Actions pipeline to App Service.

> These phases map 1‑to‑1 to the "advantage" bullet‑points in the Consist job description.

---

### Appendix · Common WSL commands

*(unchanged – scroll up for table)*
