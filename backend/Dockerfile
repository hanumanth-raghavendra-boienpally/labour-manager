# syntax=docker/dockerfile:1

# Stage 1: build the jar and split it into layers (dependencies change rarely, so rebuilds stay small).
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /build
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2 mvn -B -q dependency:go-offline
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -B -q package \
 && cp target/*.jar application.jar \
 && java -Djarmode=tools -jar application.jar extract --layers --destination /build/extracted

# Stage 2: minimal JRE, non-root user. Configuration (DB1_URL, DB2_URL, TOKEN_SECRET ...) arrives as environment variables.
FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY --from=build /build/extracted/dependencies/ ./
COPY --from=build /build/extracted/spring-boot-loader/ ./
COPY --from=build /build/extracted/snapshot-dependencies/ ./
COPY --from=build /build/extracted/application/ ./
USER app
EXPOSE 8080
# /api/auth/app-info is public (the sign-in page calls it before login).
HEALTHCHECK --interval=15s --timeout=3s --start-period=60s --retries=5 \
  CMD wget -qO- http://localhost:8080/api/auth/app-info >/dev/null || exit 1
ENTRYPOINT ["java", "-jar", "application.jar"]
