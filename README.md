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

## 6 · Git commits so far

```bash
git add scripts/healthcheck.sh logs backup.dump
git commit -m "feat(sys): monitoring, DR backup/restore, health‑check"
```

---

## 7 · Next steps

1. **1B CI/CD** – `.github/workflows/ci.yml` that builds, tests, and runs `scripts/healthcheck.sh` on each push.
2. **2A RabbitMQ lab** – `docker run -d rabbitmq:3-management`, JS producer & consumer via `amqplib`.
3. **3A Azure deploy** – `az webapp up` or GitHub Actions pipeline.

> These phases map 1‑to‑1 to the "advantage" bullet‑points in the Consist job description.

---

### Appendix · Common WSL commands

| Command                     | Purpose                                      |
| --------------------------- | -------------------------------------------- |
| `wsl --shutdown`            | Gracefully stop all distros & free resources |
| `wsl -d <name>`             | Open an interactive shell in a chosen distro |
| `wsl --export` / `--import` | Backup / restore a distro                    |

---

*End of README – you can hand this file to any recruiter or teammate to reproduce the lab without extra guidance.*
