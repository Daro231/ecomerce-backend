# Multi-stage Dockerfile for Spring Boot (Java 21) on Railway

# ------------------------------------------------------------------------------
# Stage 1: Build & Package
# ------------------------------------------------------------------------------
FROM maven:3.9.9-eclipse-temurin-21-jammy AS builder
WORKDIR /build

# Copy pom.xml and cache Maven dependencies
COPY pom.xml .
RUN mvn dependency:go-offline -B || true

# Copy source files and package JAR skipping tests
COPY src ./src
RUN mvn clean package -DskipTests -B

# ------------------------------------------------------------------------------
# Stage 2: Runtime
# ------------------------------------------------------------------------------
FROM eclipse-temurin:21-jre-jammy AS runner
WORKDIR /app

# Create a non-root group and user for security
RUN groupadd -r spring && useradd -r -g spring spring \
    && mkdir -p /app/uploads && chown -R spring:spring /app

USER spring:spring

# Copy packaged jar from builder
COPY --from=builder --chown=spring:spring /build/target/ecom-backend-*.jar app.jar

# Railway automatically sets the PORT environment variable at runtime
EXPOSE 8080

# Production-ready JVM options optimized for containers
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75.0 -XX:+UseContainerSupport -XX:+ExitOnOutOfMemoryError -Djava.security.egd=file:/dev/./urandom"

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
