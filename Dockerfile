#FROM maven:3.9.6-eclipse-temurin
#COPY . /app
#WORKDIR /app
#RUN mvn clean package
#RUN mv ./target/*.jar ./target/dev-ops-app.jar
#
#ENTRYPOINT ["java", "-jar", "./target/dev-ops-app.jar"]



FROM maven:3-eclipse-temurin-23 AS builder
COPY . /app
WORKDIR /app
RUN mvn clean package -DskipTests
#


#FROM openjdk:23-jdk
#WORKDIR /app
#COPY --from=builder /app/target/*.jar spring-docker-app.jar
#ENTRYPOINT ["java", "-jar", "spring-docker-app.jar"]
#FROM openjdk:23-jdk
#RUN mv ./target/*.jar ./target/spring-docker-app.jar
#ENTRYPOINT ["java", "-jar", "./target/spring-docker-app.jar"]