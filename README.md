# Config Server 프로젝트 개요

이 프로젝트는 Spring Cloud Config Server를 기반으로 하여 마이크로서비스 환경에서 공통 설정을 중앙 집중형으로 관리하기 위한 설정 서버입니다. 여러 서비스가 각각 개별적으로 설정 파일을 가지는 대신, 설정 서버에서 공통 설정을 통합 관리하여 환경 일관성, 운영 편의성, 릴리즈 시 설정 변경 용이성을 제공합니다.

## 기술 스택

| 항목                   | 내용                                           |
| -------------------- | -------------------------------------------- |
| Spring Boot          | 3.5.7                                        |
| Java                 | 21                                           |
| Build Tool           | Gradle (Groovy DSL)                          |
| Packaging            | WAR                                          |
| Spring Cloud Version | 2025.0.0                                     |
| 주요 의존성               | Config Server, Actuator, Prometheus Registry |

## Config Server 내부 동작 방식

Config Server는 설정 저장소(예: Git, 파일 시스템, Vault 등)에서 설정 정보를 조회하고, 클라이언트 애플리케이션(Spring Cloud Config Client 등)은 이를 HTTP API 형태로 조회합니다.

### 동작 흐름

```
클라이언트 서비스                          Config 서버                         설정 저장소
     │                                          │                                          │
     │         GET /{application}/{profile}     │                                          │
     ├─────────────────────────────────────────>│                                          │
     │                                          │         설정 파일 조회                    │
     │                                          ├─────────────────────────────────────────>│
     │                                          │                                          │
     │                                          │         설정 데이터 반환                  │
     │                                          │<──────────────────────────────────────────┤
     │             JSON (환경 설정 값)          │
     │<─────────────────────────────────────────┤
```

### 핵심 개념

| 용어               | 설명                               |
| ---------------- | -------------------------------- |
| Application Name | 설정을 요청하는 서비스 이름                  |
| Profile          | dev, prod 등 환경 구분                |
| Label            | Git 기반 설정 시 branch 또는 version 의미 |

## Native 로컬 파일 기반 설정

현재 설정은 Git 저장소를 사용하지 않고, 로컬 classpath `/config` 폴더를 설정 저장소로 사용합니다.

```
spring:
  application:
    name: config-server

  profiles:
    active: native

  cloud:
    config:
      server:
        native:
          search-locations: classpath:/config
          
server:
  port: 3001
```

### 설정 의미

| 설정 키                               | 설명                                          |
| ---------------------------------- | ------------------------------------------- |
| spring.profiles.active=native      | 설정 저장소를 로컬 파일 시스템으로 사용                      |
| search-locations=classpath:/config | 설정 파일을 `src/main/resources/config/` 경로에서 탐색 |
| server.port=3001                   | Config Server는 3001 포트에서 실행                 |

## Config Server 활성화 코드

```
@EnableConfigServer
@SpringBootApplication
public class ConfigServerApplication {
    public static void main(String[] args) {
        SpringApplication.run(ConfigServerApplication.class, args);
    }
}
```

## Gradle 의존성 설명

```
dependencies {
    implementation 'org.springframework.boot:spring-boot-starter-actuator'
    implementation 'org.springframework.boot:spring-boot-starter-web'
    implementation 'org.springframework.cloud:spring-cloud-config-server'
    runtimeOnly 'io.micrometer:micrometer-registry-prometheus'
    providedRuntime 'org.springframework.boot:spring-boot-starter-tomcat'
    testImplementation 'org.springframework.boot:spring-boot-starter-test'
}
```

| 의존성                                          | 설명                                                   |
| -------------------------------------------- | ---------------------------------------------------- |
| spring-cloud-config-server                   | Config Server 기능 제공 핵심 의존성                           |
| spring-boot-starter-web                      | 설정을 HTTP API로 제공하기 위한 웹 서버 기능                        |
| spring-boot-starter-actuator                 | /actuator/health, /actuator/prometheus 등 운영 상태 조회 제공 |
| micrometer-registry-prometheus               | Prometheus 메트릭 수집 지원                                 |
| spring-boot-starter-tomcat (providedRuntime) | 외부 Tomcat 사용 가능하도록 WAR 패키징 지원                        |

## Prometheus 연동

Actuator + Micrometer를 통해 Prometheus가 메트릭을 수집할 수 있는 엔드포인트를 제공합니다.

| 경로                                                                                     | 설명                      |
| -------------------------------------------------------------------------------------- | ----------------------- |
| [http://localhost:3001/actuator/health](http://localhost:3001/actuator/health)         | Config Server 상태 확인     |
| [http://localhost:3001/actuator/prometheus](http://localhost:3001/actuator/prometheus) | Prometheus 메트릭 수집 엔드포인트 |

Prometheus 설정 예시:

```
scrape_configs:
  - job_name: 'config-server'
    static_configs:
      - targets: ['localhost:3001']
```

## 설정 파일 저장 방식 & 명명 규칙 (Native 모드, classpath)

> 목표: 팀원이 아무것도 몰라도 바로 따라 해서 동작 확인할 수 있도록 “폴더 구조 → 파일 이름 → 예제 내용 → 조회 방법”을 1:1로 매칭해 설명합니다.

### 1) 폴더 구조

```
src/
 └─ main/
     └─ resources/
         └─ config/                 # ← search-locations=classpath:/config
            ├─ application.yml      # (공통 기본값)
            ├─ application-dev.yml  # (모든 서비스 공통 dev 오버라이드) *선택
            ├─ application-prod.yml # (모든 서비스 공통 prod 오버라이드) *선택
            ├─ orders.yml           # orders 서비스 기본값
            ├─ orders-dev.yml       # orders 서비스 dev 전용
            ├─ orders-prod.yml      # orders 서비스 prod 전용
            ├─ users.yml            # users 서비스 기본값
            └─ users-prod.yml       # users 서비스 prod 전용
```

### 2) 파일 명명 규칙

* **형식**: `{application}.yml` 또는 `{application}-{profile}.yml`
* `{application}` = 클라이언트 서비스의 `spring.application.name`
* `{profile}` = 클라이언트가 활성화하는 프로필(`spring.profiles.active`)
* **적용 우선순위(하위가 더 강함)**

    1. `application.yml` (전체 공통 기본값)
    2. `application-{profile}.yml` (전체 공통의 프로필 전용)
    3. `{application}.yml` (서비스 개별 기본값)
    4. `{application}-{profile}.yml` (서비스 개별 + 프로필 전용)

### 3) 예제 파일 내용

**application.yml (공통 기본값)**

```yaml
# src/main/resources/config/application.yml
logging:
  level:
    root: INFO
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus
```

**orders.yml (orders 서비스 기본값)**

```yaml
# src/main/resources/config/orders.yml
orders:
  cacheTtlSeconds: 300
  paymentProvider: toss
```

**orders-dev.yml (orders 서비스의 dev 오버라이드)**

```yaml
# src/main/resources/config/orders-dev.yml
orders:
  cacheTtlSeconds: 5   # 개발 편의를 위해 TTL 단축
logging:
  level:
    xyz.sparta_project.manjok: DEBUG
```

> 참고: 한 파일 안에서 `---`로 프로필을 분할하는 방법도 가능하지만, **처음에는 파일을 분리**(e.g., `orders-dev.yml`)하는 것이 가장 직관적입니다.

### 4) 클라이언트가 어떻게 가져가나? (호출 규칙)

Config Server의 기본 HTTP 규칙은 아래와 같습니다.

* `/{application}/{profile}`
* `/{application}-{profile}.yml`
* `/{label}/{application}-{profile}.json` (Git 사용 시 label=branch)

**예시 (서버 포트 3001, Native 모드)**

```
# orders 서비스가 dev 프로필로 조회
GET http://localhost:3001/orders/dev
GET http://localhost:3001/orders-dev.yml
GET http://localhost:3001/orders/dev/application.yml  # 상세 뷰
```

### 5) 클라이언트(마이크로서비스) 설정법

Spring Boot 3.5+ / Spring Cloud 2025.x 기준, 클라이언트는 `spring.config.import`로 Config Server를 선언합니다.

**clients/orders/src/main/resources/application.yml**

```yaml
spring:
  application:
    name: orders
  profiles:
    active: dev
  config:
    import: optional:configserver:http://localhost:3001

# Config Server에서 내려온 값들이 여기에 병합됩니다.
```

> `optional:`을 빼면 Config Server가 응답하지 않을 때 부팅 실패합니다.

### 6) 즉시 적용/갱신(옵션)

* 기본적으로 **애플리케이션 재시작** 시에만 최신 설정을 반영합니다.
* 실시간 갱신이 필요하다면 **Spring Cloud Bus(AMQP/Kafka)** 를 추가해 `/actuator/busrefresh`로 브로드캐스트 하세요.

### 7) Properties도 가능한가?

가능합니다. `*.properties`와 `*.yml` 혼용 가능하지만, **팀 표준으로 YAML**을 권장합니다.

### 8) 자주 하는 실수 체크리스트

* [ ] 클라이언트의 `spring.application.name`과 설정 파일명 `{application}`이 불일치
* [ ] 프로필 철자(`dev`/`prod`)가 파일명과 다름
* [ ] Config Server의 `search-locations` 경로 오타 또는 리소스 폴더 위치 오류
* [ ] 클라이언트에서 `spring.config.import` 누락
* [ ] 방화벽/포트(3001) 미개방

---

## Eureka 연동 (Config Server 서비스 등록)

Config Server가 Eureka Server(예: 포트 5000)에 자신을 서비스로 등록하면, 클라이언트들은 Config Server의 실제 주소를 직접 알 필요가 없고 **서비스 이름으로 설정을 가져올 수 있습니다.**

### 1) Eureka Server 주소

```
http://localhost:5000/eureka/
```

### 2) Config Server에 Eureka Client 설정 추가

**build.gradle** (Config Server)

```
implementation 'org.springframework.cloud:spring-cloud-starter-netflix-eureka-client'
```

**application.yml** (Config Server)

```
spring:
  application:
    name: config-server
  cloud:
    config:
      server:
        native:
          search-locations: classpath:/config

server:
  port: 3001

eureka:
  client:
    service-url:
      defaultZone: http://localhost:5000/eureka/
    register-with-eureka: true
    fetch-registry: true
```

Config Server는 Eureka에 **`config-server`** 라는 서비스명으로 등록됩니다.

---

### 3) 클라이언트 서비스에서 Config Server 가져오기 (Eureka 기반)

클라이언트 서비스는 `URL` 대신 **서비스 이름으로 Config Server를 찾습니다.**

**build.gradle** (Client 서비스)

```
implementation 'org.springframework.cloud:spring-cloud-starter-netflix-eureka-client'
implementation 'org.springframework.cloud:spring-cloud-starter-config'
```

**application.yml** (Client 서비스)

```yaml
spring:
  application:
    name: orders
  profiles:
    active: dev
  config:
    import: "optional:configserver:http://config-server"   # URL 대신 서비스명 사용

# Eureka 등록

Eureka:
  client:
    service-url:
      defaultZone: http://localhost:5000/eureka/
```

> 여기서 `http://config-server` 는 Config Server가 Eureka에 등록된 서비스 이름입니다.
> Eureka가 내부적으로 IP/Port 를 확인해 연결합니다.

---

### 4) 아키텍처 흐름

```
    [Config Server] ── registers ──> [Eureka Server]
           ▲                                 │
           │                                 │ resolves service name
           │                                 ▼
    [Client Service] ── requests config ──> config-server
```

---

## 파일 시스템 기반 저장소(native) 상세 설명

### 설정 예시

```
spring:
  profiles:
    active: native
  cloud:
    config:
      server:
        native:
          search-locations: file:///{FILE_PATH}
```

* **native 프로필**: Config Server가 **파일 시스템 또는 classpath** 에서 설정 파일을 읽도록 지시하는 프로필
* **{FILE_PATH}**: 설정 파일이 저장된 실제 시스템 경로
* **search-locations**: 여러 경로를 쉼표로 구분하여 입력 가능, `classpath:` 사용 시 리소스 폴더에서 탐색

예시 (classpath 기반):

```
spring:
  cloud:
    config:
      server:
        native:
          search-locations: classpath:/config
```

> classpath:/config → `src/main/resources/config` 디렉토리를 자동으로 인식

---

## 설정 파일명 규칙 및 우선순위

### 기본 파일명 규칙

* `{application-name}-{profile}.yml` 또는 `.properties`
* `{application-name}` = 클라이언트의 `spring.application.name`
* `{profile}` = 클라이언트가 설정한 `spring.profiles.active`

### 적용 우선순위 (위 → 아래 순으로 강함)

1. **애플리케이션 + 프로필 설정**

    * `{app-name}-{profile}.yml`
    * `{app-name}/application-{profile}.yml`
    * `{app-name}/{profile}.yml`
2. **애플리케이션 공통 설정**

    * `{app-name}.yml`
    * `{app-name}/application.yml`
3. **전체 공통 프로필 설정**

    * `application-{profile}.yml`
4. **전체 공통 기본 설정**

    * `application.yml`

---

## Git 기반 설정 저장소 사용

```
spring:
  profiles:
    active: native, git

  cloud:
    config:
      server:
        native:
          search-locations: classpath:/configs

        git:
          uri: https://github.com/yonggyo1125/project-configs
          default-label: main
          search-paths: configs/**
          basedir: configs
          clone-on-start: true
```

| 설정                            | 설명                                 |
| ----------------------------- | ---------------------------------- |
| profiles.active = native, git | Native + Git 저장소 둘 다 사용 가능하게 구성    |
| git.uri                       | 원격 Git 저장소 주소                      |
| git.default-label             | 기본 branch (main)                   |
| git.search-paths              | Git repo 내부에서 설정 파일 검색할 디렉토리 경로 패턴 |
| git.basedir                   | Git repo를 로컬로 clone 하는 위치 이름       |
| git.clone-on-start            | 서버 시작 시 Git repo를 자동으로 clone       |

---

## Eureka 서버와 연동하여 Config Server 등록

### 의존성

```
implementation 'org.springframework.cloud:spring-cloud-starter-netflix-eureka-client'
```

### Config Server `application.yml`

```
eureka:
  client:
    register-with-eureka: true
    fetch-registry: true
    serviceUrl:
      defaultZone: http://localhost:5000/eureka/
```

* `register-with-eureka`: Config Server가 Eureka에 등록됨
* `fetch-registry`: Eureka에 등록된 다른 서비스 정보를 가져옴

---

## Prometheus + Grafana 모니터링

### 의존성

```
runtimeOnly 'io.micrometer:micrometer-registry-prometheus'
```

### application.yml

```
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus
  endpoint:
    prometheus:
      enabled: true
```

* Prometheus는 `/actuator/prometheus` 로 메트릭을 수집

---

## Loki + Grafana 로그 수집

### build.gradle

```
implementation 'com.github.loki4j:loki-logback-appender:2.0.0'
```

### logback.xml

```
<configuration>
    <appender name="LOKI" class="com.github.loki4j.logback.Loki4jAppender">
        <http>
            <url>https://{LOKI_SERVER}/loki/api/v1/push</url>
        </http>
        <message class="com.github.loki4j.logback.JsonLayout" />
    </appender>

    <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
            <pattern>%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n</pattern>
        </encoder>
    </appender>

    <root level="INFO">
        <appender-ref ref="LOKI"/>
        <appender-ref ref="STDOUT"/>
    </root>
</configuration>
```

---

#

* **저장 위치**: `src/main/resources/config` (native)
* **파일 이름**: `{application}.yml`, `{application}-{profile}.yml`
* **우선순위**: 공통 < 공통-프로필 < 서비스 < 서비스-프로필
* **클라이언트 연결**: `spring.config.import: optional:configserver:http://localhost:3001`
* **운영**: Actuator/Prometheus로 상태 및 메트릭 관찰, 필요 시 Cloud Bus로 핫 리프레시 확장
