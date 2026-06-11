# syntax=docker/dockerfile:1

# ============================================================
# Stage 1 — Build the executable Spring Boot WAR with Gradle
# ============================================================
FROM eclipse-temurin:21-jdk AS build

WORKDIR /workspace

# Copy the Gradle wrapper first so it can be reused across rebuilds
COPY gradlew ./
COPY gradle ./gradle

# Copy the build configuration and pre-fetch dependencies (better layer caching)
COPY settings.gradle build.gradle system.properties ./
RUN chmod +x gradlew && ./gradlew --no-daemon dependencies > /dev/null 2>&1 || true

# Copy the rest of the sources and build the bootWar (tests are run in CI, not here)
COPY src ./src
COPY .openapi-generator-ignore ./
RUN ./gradlew --no-daemon clean bootWar -x test

# ============================================================
# Stage 2 — Minimal runtime image
# ============================================================
FROM eclipse-temurin:21-jre AS runtime

# curl is used by the container HEALTHCHECK
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Run as an unprivileged user
RUN groupadd --system spring && useradd --system --gid spring spring
USER spring:spring

# Copy the executable WAR produced by the build stage (version-agnostic)
COPY --from=build --chown=spring:spring /workspace/build/libs/*.war app.war

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.war"]
