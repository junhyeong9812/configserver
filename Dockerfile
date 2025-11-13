FROM eclipse-temurin:21-jdk
ARG JAR_FILE=build/libs/*.jar
COPY ${JAR_FILE} app.jar

#ENV HOSTNAME=localhost
#ENV EUREKA_URL=http://localhost:3150/eureka/

ENTRYPOINT exec java \
  -DEUREKA_INSTANCE_HOSTNAME=${EUREKA_HOSTNAME} \
  -DEUREKA_CLIENT_SERVICEURL_DEFAULTZONE=${EUREKA_URL} \
  -jar app.jar

EXPOSE 3100