# Workshop Organizer Web API

Welcome to the Workshop Organizer Web API! This application is designed to facilitate workshops open to the public. Whether you’re organizing coding bootcamps, art classes, or any other type of workshop, this API will help manage registrations, schedules, and resources.

## Table of Contents

1. Context
2. Technical Overview
3. Building and Running
4. Testing
5. Continuous Integration (CI/CD)
6. Release
7. Packaging

## Context

Workshops play a crucial role in fostering learning and collaboration. Our application aims to streamline the workshop organization process, making it easier for organizers to manage participants, sessions, and materials. Whether you're a seasoned workshop host or just starting out, this API has got you covered!

## Technical Overview

- **Java Development Kit (JDK):** We use **JDK 21**, tested with **Adoptium**, to power our application.
- **Database:** Our backend relies on a **PostgreSQL 13** database for data storage.
- **Build Tool:** We leverage **Gradle 8.7** for managing dependencies and building the project.
- **Spring Boot:** Our application is based on **Spring Boot 3.2.4**, which provides a robust framework for creating RESTful APIs.
- **Application Server:** Our application can run on Tomcat server that require version 10.1.24.

## Building and Running

To compile and run the application locally, follow these steps:

1. Ensure you have JDK 21 installed.
2. Clone this repository.
3. Navigate to the project root directory.
4. Execute the following command to compile the Java code :
   ```bash
   ./gradlew clean compileJava
   ```
5. Run the application locally. The simplest way is the helper script, which
   loads the database credentials from your `.env` file and starts the app:
   ```bash
   ./run-local.sh
   ```
   On the very first run it creates `.env` from `.env.example` and asks you to
   fill in your local database credentials (see [Configuration](#configuration)),
   then re-run it.

   Alternatively you can run it yourself, either from your IDE (execute the main
   method in the Application class, with the `SPRING_DATASOURCE_USERNAME` /
   `SPRING_DATASOURCE_PASSWORD` variables set in the Run/Debug configuration), or
   from the command line with the Spring Boot Gradle plugin once the variables are
   exported in your shell:
   ```bash
   set -a; source .env; set +a
   ./gradlew bootRun
   ```
   For production, package the application as WAR and use a tomcat server.

To run the full stack (application + PostgreSQL) with Docker, simply run the
following from the project root. Compose will build the application image,
start PostgreSQL with a persistent volume, wait until the database is healthy,
then start the app:

```bash
docker compose up -d
```

Once both containers report `healthy`, the API is available at
`http://localhost:8080` (e.g. `http://localhost:8080/api/notions`), and the
container health endpoint is `http://localhost:8080/actuator/health`.

To stop everything (the database volume is preserved):

```bash
docker compose down
```

## Configuration

You can configure the application with these environment variables

- SPRING_DATASOURCE_URL: JDBC URI for DB access (ex. jdbc:postgresql://db:5432/mydatabase)
- SPRING_DATASOURCE_USERNAME: Database user name used by the application
- SPRING_DATASOURCE_PASSWORD: Database user password used by the application

The database username and password are **not** hard-coded in
`application.properties` — they are read from the `SPRING_DATASOURCE_USERNAME`
and `SPRING_DATASOURCE_PASSWORD` environment variables. Docker Compose and the
CI workflow already provide them.

For local command-line runs, the `./run-local.sh` helper takes care of this: on
first run it creates `.env` from the committed `.env.example` template, then it
loads the variables and starts the app:

```bash
./run-local.sh                # creates .env on first run; edit it, then re-run
```

The `.env` file is git-ignored, so secrets stay out of version control
(`.env.example` is the committed template). If you prefer to do it manually, copy
the template and source it before launching the app yourself:

```bash
cp .env.example .env          # then edit .env with your local DB credentials
set -a; source .env; set +a   # export the variables into the current shell
./gradlew bootRun
```

## Testing

We take testing seriously! To verify the correctness of our application, run the following command:

```bash
./gradlew clean test
```

During execution junit reports are generated in the `build/test-results/test` folder.

Alternatively, a helper script is provided that checks the required dependencies
(JDK, Gradle wrapper), cleans up previous artifacts, runs the suite and collects
the JUnit XML and HTML reports into a `test-results/` folder, propagating the
test exit code:

```bash
./run-tests.sh
```

## Continuous Integration (CI/CD)

A GitHub Actions workflow lives at `.github/workflows/ci.yml`. It runs on every
push to `main`, on pull requests, and can be triggered manually from the Actions
tab (`workflow_dispatch`) to cut a release. It is made of three jobs:
`test` → `build` → `release`.

### 1. `test`

- Detects the project type (Java/Gradle here), sets up **JDK 21** (Temurin) with
  Gradle dependency caching.
- Runs the suite with `./gradlew test --no-daemon`.
- Publishes the JUnit results as a check in the Actions/PR UI and uploads the
  `build/test-results/` reports as a build artifact (`test-results`).

### 2. `build` (Build & push image)

Runs after `test` succeeds, on pushes to `main` and on manual (`workflow_dispatch`)
runs.

1. Builds the Docker image from the project `Dockerfile` (loaded locally, not yet
   pushed).
2. **Validates** the image before publishing: it spins up an ephemeral
   PostgreSQL container on a private Docker network, starts the application
   container connected to it (via the `SPRING_DATASOURCE_*` variables), and polls
   `http://localhost:8080/actuator/health` until it returns `200`. If the app
   fails to boot or never becomes healthy, the image is **not** pushed.
3. On success, logs in to the **GitHub Container Registry (GHCR)** with the
   built-in `GITHUB_TOKEN` and pushes the image tagged `<branch>-<short-sha>`
   to `ghcr.io/<owner>/<repo>`.

This relies on the Spring Boot Actuator health endpoint (`/actuator/health`) that
the application exposes; no extra secrets are required for the build job — only
the automatically provided `GITHUB_TOKEN`.

### 3. `release`

This is the **release phase**. It is **manual**: trigger it from the GitHub
Actions tab via **Run workflow** (`workflow_dispatch`). It runs after `build`, so
a release only ever ships an image that already passed validation. See
[Release](#release) below for what it produces.

## Release

Releases are cut by manually running the workflow (Actions tab → **CI** →
**Run workflow** on `main`). The `release` job is fully GitHub-native — it uses
**GitHub Releases** and the **GitHub Container Registry (GHCR)**; no GitLab or
external registry is involved.

When triggered, the `release` job:

1. Runs [**semantic-release**](https://semantic-release.gitbook.io/) over the
   git history. It reads the [Conventional Commits](https://www.conventionalcommits.org/)
   since the last tag and decides the next **SemVer** version
   (`fix:` → patch, `feat:` → minor, `feat!:`/`fix!:` → major).
2. If a version bump is warranted, it creates the **git tag**, publishes a
   **GitHub Release** with an auto-generated changelog, and re-tags the exact
   image the `build` job validated for this commit — **no rebuild** — with the
   SemVer tags and pushes them to GHCR:
   `X.Y.Z`, the rolling `X.Y` and `X`, and `latest`.
3. If no commits since the last tag warrant a bump, it exits cleanly without
   creating a release.

Because versioning is driven by commit messages, write them following the
Conventional Commits convention (e.g. `feat: add workshop search`,
`fix: correct notion mapping`, `feat!: change registration payload`) for the
release automation to pick the right version.

The job only needs the automatically provided `GITHUB_TOKEN` (granted
`contents: write` for the tag/release and `packages: write` for the image push) —
**no manually configured secrets are required**.

### Pulling a released image

```bash
docker pull ghcr.io/<owner>/<repo>:latest
# or a specific version
docker pull ghcr.io/<owner>/<repo>:1.4.0
```

Replace `<owner>/<repo>` with this repository's GitHub path.

## Packaging

When you’re ready to package the application for deployment, create a deployable WAR file:

```bash
./gradlew bootWar
```

The generated war file can be used with many application servers such as Tomcat, Wildfly...

Feel free to enhance this README with additional details, such as API endpoints, security considerations, and deployment instructions. Happy organizing! 🚀
