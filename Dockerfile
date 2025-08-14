# Stage 1: Build artifact with Maven
FROM maven:3.9.3-eclipse-temurin-17 AS build-stage

WORKDIR /opt/mindcircuit13
COPY . .
RUN mvn clean package -DskipTests

# Stage 2: Deploy artifact to Tomcat
FROM tomcat:10.1.15-jdk17

WORKDIR /usr/local/tomcat/webapps
COPY --from=build-stage /opt/mindcircuit13/target/*.war .
RUN rm -rf ROOT && mv *.war ROOT.war

EXPOSE 8080
