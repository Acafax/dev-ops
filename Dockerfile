FROM maven:3-eclipse-temurin-23 AS base
COPY . /app
WORKDIR /app
RUN mvn clean package -DskipTests
RUN mv ./target/*.jar ./target/dev-ops-app.jar
RUN ls -l /app/target

#Po dodaniu /app/target poprawnie działa
FROM eclipse-temurin:23-jre-ubi9-minimal
COPY --from=base /target/dev-ops-app.jar ./target/dev-ops-app.jar
CMD ["java", "-jar", "./target/dev-ops-app.jar"]

#
#
#FROM maven:3-eclipse-temurin-23 AS builder
#COPY . /app
#WORKDIR /app
#EXPOSE 8080
#CMD ["java", "-jar", "dev-ops.jar"]
#RUN mvn clean package -DskipTests
#
#FROM openjdk:23-jdk
#COPY . /app
#WORKDIR /app
#EXPOSE 8080

#
#FROM openjdk:23-jdk
#WORKDIR /app
#COPY --from=builder /app/target/*.jar spring-docker-app.jar
#ENTRYPOINT ["java", "-jar", "spring-docker-app.jar"]
#FROM openjdk:23-jdk
#RUN mv ./target/*.jar ./target/spring-docker-app.jar
#ENTRYPOINT ["java", "-jar", "./target/spring-docker-app.jar"]