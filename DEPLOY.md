# Backend Deployment Guide (Spring Boot + Railway)

This guide walks you through deploying the `springboot` backend service to [Railway](https://railway.com) using PostgreSQL, Docker multi-stage builds, and Spring Boot Actuator health checks.

---

## 1. Prerequisites

- A [Railway](https://railway.com) account.
- This repository pushed to a GitHub repo (or deployed via Railway CLI).
- Java 21 LTS project configured with Maven.

---

## 2. Step-by-Step Railway Deployment

### Step 1: Create a New Project on Railway
1. Log in to your [Railway Dashboard](https://railway.com/dashboard).
2. Click **"New Project"**.
3. Select **"Provision PostgreSQL"** to add a managed PostgreSQL database.

### Step 2: Add the Backend Service
1. In the same project canvas, click **"+ Create"** (or **"New"**) -> **"GitHub Repo"**.
2. Select your repository. If this repository is a mono-repo containing both `springboot` and `frontend`, set the **Root Directory** in Railway service settings:
   - Go to **Settings** -> **Root Directory** -> set to `/springboot`.
3. Railway will read `railway.json` and detect the `DOCKERFILE` builder.

### Step 3: Link Database Environment Variables
When you add the PostgreSQL plugin in the same Railway project, Railway automatically provisions connection credentials. You can link the backend service to PostgreSQL:
- Railway provides `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, and `PGDATABASE` across services or via variable references.
- In your backend service's **Variables** tab, set:
  ```env
  SPRING_PROFILES_ACTIVE=prod
  ```
  The production profile (`application-prod.properties`) automatically maps:
  `jdbc:postgresql://${PGHOST}:${PGPORT}/${PGDATABASE}` with `${PGUSER}` and `${PGPASSWORD}`.
- Alternatively, you can explicitly set `DB_URL` using Railway's reference syntax:
  ```env
  DB_URL=jdbc:postgresql://${{Postgres.PGHOST}}:${{Postgres.PGPORT}}/${{Postgres.PGDATABASE}}
  DB_USERNAME=${{Postgres.PGUSER}}
  DB_PASSWORD=${{Postgres.PGPASSWORD}}
  ```

### Step 4: Configure Application Environment Variables
In the **Variables** tab of the backend service, add the following required variables:

| Variable | Value / Description | Required |
|---|---|---|
| `SPRING_PROFILES_ACTIVE` | `prod` | Yes |
| `JWT_SECRET` | A secure random 256-bit string (min 32 characters) | Yes |
| `FRONTEND_URL` | Public URL of your frontend (e.g. `https://frontend.up.railway.app`) | Yes (update after frontend deploy) |
| `KHQR_MODE` | `mock` (or `bakong` if live keys are available) | Yes |
| `UPLOAD_DIR` | `/app/uploads` | Optional (default: `/app/uploads`) |
| `BAKONG_TOKEN` | Your NBC Bakong JWT token | Only if `KHQR_MODE=bakong` |
| `BAKONG_ACCOUNT_ID` | Your Bakong account ID (e.g. `merchant@bank`) | Only if `KHQR_MODE=bakong` |

> **Note on Volume Storage**: By default, `/app/uploads` is ephemeral in containers. To persist uploaded product images across redeployments, click **"Add Volume"** in the backend service settings and mount it to `/app/uploads`.

### Step 5: Generate a Public Domain
1. In the backend service, go to **Settings** -> **Networking** -> **Public Networking**.
2. Click **"Generate Domain"** (e.g. `ecom-backend-production.up.railway.app`).
3. Note this domain; your frontend service will need it as `NEXT_PUBLIC_API_URL` (with `/api/v1` appended).

### Step 6: Verify Deployment & Health Check
1. Railway uses the path `/actuator/health` configured in `railway.json` to monitor the service.
2. Once the deployment finishes, open:
   ```
   https://<your-backend-domain>.up.railway.app/actuator/health
   ```
   You should see:
   ```json
   {"status":"UP"}
   ```
3. Test a public API endpoint:
   ```bash
   curl -s https://<your-backend-domain>.up.railway.app/api/v1/categories
   ```
   You should receive a `200 OK` response with JSON data seeded by Flyway.

---

## 3. Troubleshooting

### 1. Port Binding Errors
- **Symptom**: Railway deployment fails with `Healthcheck failed` or container logs show port issues.
- **Cause**: Application listening on a fixed port instead of the port assigned by Railway.
- **Fix**: Railway injects the `$PORT` environment variable. Our configuration uses `server.port=${PORT:8080}` and binds to `server.address=0.0.0.0`. Never hardcode `8080` without the fallback `${PORT:8080}`.

### 2. Wrong Java Version
- **Symptom**: `UnsupportedClassVersionError: ... has been compiled by a more recent version of the Java Runtime (class file version 65.0)`.
- **Cause**: Compiling on Java 21 but running on an older JRE (such as Java 17).
- **Fix**: Both the `builder` stage (`maven:3.9.9-eclipse-temurin-21-jammy`) and runtime stage (`eclipse-temurin:21-jre-jammy`) in `Dockerfile` are strictly pinned to Java 21 LTS.

### 3. Database Connection Errors
- **Symptom**: `Connection to localhost:5432 refused` or `FATAL: password authentication failed for user "postgres"`.
- **Cause**: `SPRING_PROFILES_ACTIVE` is unset (defaulting to `dev` which targets `localhost:5432`), or `PG*` variables are missing.
- **Fix**:
  1. Confirm `SPRING_PROFILES_ACTIVE=prod` in Railway variables.
  2. Ensure the PostgreSQL plugin exists in the same Railway project.
  3. Verify `DB_URL` points to `jdbc:postgresql://${PGHOST}:${PGPORT}/${PGDATABASE}`. Note that standard `DATABASE_URL` (starting with `postgresql://`) must be prefixed with `jdbc:` for JDBC driver compatibility.

### 4. Out-of-Memory (OOM) During Build or Runtime
- **Symptom**: Maven build crashes with exit code 137 (`Killed`), or container restarts repeatedly.
- **Cause**: Maven downloading plugins or Spring Boot JVM exceeding container memory limit.
- **Fix**:
  1. The Dockerfile passes `-XX:MaxRAMPercentage=75.0` to ensure the JVM leaves 25% of container RAM for off-heap OS memory.
  2. If the Maven build runs out of memory on low-tier Railway plans, add `MAVEN_OPTS="-Xmx512m"` or upgrade the service plan memory limit.

### 5. CORS Errors (Frontend unable to call backend)
- **Symptom**: Browser console shows `Access to XMLHttpRequest at '...' from origin '...' has been blocked by CORS policy`.
- **Cause**: `FRONTEND_URL` in the backend service does not match the frontend's domain, or has trailing slashes.
- **Fix**:
  1. Go to the backend service's **Variables**.
  2. Set `FRONTEND_URL` to the exact frontend domain without trailing slash (e.g. `https://my-frontend.up.railway.app`).
  3. Multiple origins can be separated by commas (e.g. `https://frontend.up.railway.app,https://my-custom-domain.com`).
  4. Redeploy the backend after changing `FRONTEND_URL`.

---

## 4. Manual Railway Dashboard Checklist

1. [ ] Create a Railway project.
2. [ ] Provision a PostgreSQL database plugin in the project.
3. [ ] Add backend service from GitHub repo (set Root Directory to `/springboot` if in a monorepo).
4. [ ] In backend service **Variables**, add:
   - `SPRING_PROFILES_ACTIVE=prod`
   - `JWT_SECRET=<strong-random-key>`
   - `KHQR_MODE=mock` (or `bakong`)
   - `FRONTEND_URL=<frontend-public-url>` (set after frontend deployment)
5. [ ] In backend service **Settings** -> **Public Networking**, generate a public domain.
6. [ ] (Optional) In backend service **Settings** -> **Volumes**, mount a persistent volume at `/app/uploads`.
7. [ ] Verify `/actuator/health` returns `{"status":"UP"}`.
