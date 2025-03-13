FROM maven:3-eclipse-temurin-23 AS base
COPY . /app
WORKDIR /app
RUN mvn clean package -DskipTests
RUN mv ./target/*.jar ./target/dev-ops-app.jar
RUN ls -l /app/target


FROM eclipse-temurin:23-jre-ubi9-minimal
COPY --from=base /app/target/dev-ops-app.jar ./target/dev-ops-app.jar
