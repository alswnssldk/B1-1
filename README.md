# Linux Agent 운영 환경 구축 및 관제 자동화

## 1. 프로젝트 개요

본 프로젝트는 Ubuntu 22.04 기반 리눅스 환경에서 서버 운영에 필요한 기본 보안 설정, 계정 및 권한 분리, 제공 애플리케이션 실행 환경 구성, 시스템 상태 관제 자동화, cron 기반 주기 실행을 수행하는 실습 프로젝트이다.

주요 수행 항목은 다음과 같다.

- SSH 포트 변경 및 root 원격 접속 차단
- UFW 방화벽 설정
- 역할 기반 계정/그룹 생성
- 디렉토리 권한 및 ACL 확인
- 제공 `agent-app` 실행 환경 구성
- `monitor.sh`를 통한 프로세스, 포트, 리소스 상태 점검
- `/var/log/agent-app/monitor.log` 로그 기록
- cron을 통한 매분 자동 실행
- logrotate를 통한 로그 용량 관리

---

## 2. 실행 환경

| 항목 | 내용 |
|---|---|
| OS | Ubuntu 24.04 LTS |
| 실행 방식 | Docker Compose |
| 컨테이너 이름 | agent-linux |
| SSH 포트 | 20022/tcp |
| App 포트 | 15034/tcp |
| 앱 실행 파일 | agent-app |
| 앱 배포 경로 | `/mission` |
| 로그 경로 | `/var/log/agent-app` |

---

## 3. 프로젝트 파일 구조

```txt
B1-1/
├── docker-compose.yml
├── README.md
└── agent-app/
    ├── agent-app
    └── monitor.sh
```

> 실제 컨테이너 내부에서는 `agent-app` 디렉토리가 마운트된 위치에서 파일을 복사하여 사용한다.

---

## 4. Docker Compose 실행 방법

### 컨테이너 실행

```bash
docker compose up -d
```

### 컨테이너 접속

```bash
docker exec -it agent-linux bash
```

### 컨테이너 중지

```bash
docker compose stop
```

### 컨테이너 삭제

```bash
docker compose down
```

---

## 5. docker-compose.yml

```yaml
services:
  agent-linux:
    image: ubuntu:22.04
    container_name: agent-linux
    privileged: true
    ports:
      - "20022:20022"
      - "15034:15034"
    volumes:
      - ./agent-app:/mission
    command: sleep infinity
```

---

## 6. 기본 패키지 설치

컨테이너 내부에서 다음 패키지를 설치한다.

```bash
apt update && apt install -y sudo nano openssh-server ufw cron acl logrotate iproute2 procps bc
```

설치 목적은 다음과 같다.

| 패키지 | 용도 |
|---|---|
| sudo | 일반 계정 권한 실행 |
| nano | 파일 편집 |
| openssh-server | SSH 서버 구성 |
| ufw | 방화벽 설정 |
| cron | 자동 실행 등록 |
| acl | 권한 확인 및 ACL 관리 |
| logrotate | 로그 용량 관리 |
| iproute2 | `ss` 명령어로 포트 확인 |
| procps | 프로세스/메모리 확인 |
| bc | Bash 소수점 비교 |

---

## 7. 계정 및 그룹 구조

### 생성 계정

| 계정 | 역할 |
|---|---|
| agent-admin | 운영/관리, cron 실행자 |
| agent-dev | 개발/운영, monitor.sh 작성자 |
| agent-test | QA/테스트 |

### 생성 그룹

| 그룹 | 포함 계정 | 용도 |
|---|---|---|
| agent-common | agent-admin, agent-dev, agent-test | 공용 업로드 디렉토리 접근 |
| agent-core | agent-admin, agent-dev | API 키 및 로그 등 핵심 영역 접근 |

### 확인 명령어

```bash
id agent-admin
id agent-dev
id agent-test
```

### 확인 결과

```txt
여기에 실행 결과를 작성한다.
```

---

## 8. 디렉토리 구조

컨테이너 내부 최종 디렉토리 구조는 다음과 같다.

```txt
/home/agent-admin/agent-app
├── agent-app
├── upload_files
├── api_keys
│   └── t_secret.key
└── bin
    └── monitor.sh

/var/log/agent-app
├── monitor.log
└── cron.log
```

---

## 9. 권한 정책

| 대상 | 소유자 | 그룹 | 권한 | 설명 |
|---|---|---|---|---|
| `/home/agent-admin/agent-app/upload_files` | agent-admin | agent-common | 770 | admin/dev/test 공용 업로드 영역 |
| `/home/agent-admin/agent-app/api_keys` | agent-admin | agent-core | 770 | admin/dev만 접근 가능한 키 저장 영역 |
| `/var/log/agent-app` | agent-admin | agent-core | 770 | admin/dev만 접근 가능한 로그 영역 |
| `/home/agent-admin/agent-app/agent-app` | agent-admin | agent-core | 750 | 제공 앱 실행 파일 |
| `/home/agent-admin/agent-app/bin/monitor.sh` | agent-dev | agent-core | 750 | 모니터링 자동화 스크립트 |

### 확인 명령어

```bash
ls -ld /home/agent-admin/agent-app/upload_files
ls -ld /home/agent-admin/agent-app/api_keys
ls -ld /var/log/agent-app
ls -l /home/agent-admin/agent-app/agent-app
ls -l /home/agent-admin/agent-app/bin/monitor.sh

getfacl /home/agent-admin/agent-app/upload_files
getfacl /home/agent-admin/agent-app/api_keys
getfacl /var/log/agent-app
```

### 확인 결과

```txt
여기에 실행 결과를 작성한다.
```

---

## 10. 키 파일 설정

### 키 파일 경로

```txt
/home/agent-admin/agent-app/api_keys/t_secret.key
```

### 키 파일 내용

```txt
agent_api_key_test
```

### 생성 명령어

```bash
echo "agent_api_key_test" > /home/agent-admin/agent-app/api_keys/t_secret.key
```

### 확인 명령어

```bash
cat /home/agent-admin/agent-app/api_keys/t_secret.key
ls -l /home/agent-admin/agent-app/api_keys/t_secret.key
```

### 확인 결과

```txt
여기에 실행 결과를 작성한다.
```

---

## 11. SSH 보안 설정

### 설정 내용

| 항목 | 설정값 |
|---|---|
| SSH 포트 | 20022 |
| Root 원격 접속 | 차단 |

### 확인 명령어

```bash
grep -E "Port|PermitRootLogin" /etc/ssh/sshd_config
ss -tulnp | grep 20022
```

### 확인 결과

```txt
여기에 실행 결과를 작성한다.
```

### 설명

SSH 기본 포트인 22번 대신 20022번 포트를 사용하도록 설정하였다. 또한 root 계정의 원격 접속을 차단하여 관리자 권한 탈취 위험을 줄였다.

---

## 12. 방화벽 설정

### 사용 도구

```txt
UFW
```

### 허용 포트

| 포트 | 용도 |
|---|---|
| 20022/tcp | SSH |
| 15034/tcp | Agent App |

### 확인 명령어

```bash
ufw status
```

### 확인 결과

```txt
여기에 실행 결과를 작성한다.
```

### 설명

인바운드 트래픽은 기본적으로 차단하고, SSH 접속용 20022번 포트와 애플리케이션 실행용 15034번 포트만 허용하였다.

---

## 13. 애플리케이션 실행 환경

### 환경 변수

```bash
export AGENT_HOME=/home/agent-admin/agent-app
export AGENT_PORT=15034
export AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
export AGENT_KEY_PATH=$AGENT_HOME/api_keys/t_secret.key
export AGENT_LOG_DIR=/var/log/agent-app
```

### 앱 실행 명령어

```bash
sudo -u agent-admin bash -c '
export AGENT_HOME=/home/agent-admin/agent-app
export AGENT_PORT=15034
export AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
export AGENT_KEY_PATH=$AGENT_HOME/api_keys/t_secret.key
export AGENT_LOG_DIR=/var/log/agent-app
cd $AGENT_HOME
./agent-app
'
```

### 성공 기준

- Boot Sequence 5단계 모두 `[OK]`
- 마지막에 `Agent READY` 출력
- `0.0.0.0:15034` LISTEN 상태 확인

### 앱 실행 결과

```txt
여기에 Boot Sequence 및 Agent READY 결과를 작성한다.
```

### 포트 확인 명령어

```bash
ss -tulnp | grep 15034
```

### 포트 확인 결과

```txt
여기에 실행 결과를 작성한다.
```

---

## 14. monitor.sh 기능 설명

`monitor.sh`는 시스템 상태를 점검하고 `/var/log/agent-app/monitor.log`에 결과를 기록하는 Bash 스크립트이다.

### 주요 기능

- `agent-app` 프로세스 실행 여부 확인
- TCP 15034 포트 LISTEN 여부 확인
- UFW 활성화 상태 확인
- CPU 사용률 수집
- 메모리 사용률 수집
- 루트 디스크 사용률 수집
- 임계값 초과 시 `[WARNING]` 출력
- `/var/log/agent-app/monitor.log`에 결과 누적 기록
- 프로세스 또는 포트 비정상 시 `exit 1`

### 임계값

| 항목 | 임계값 |
|---|---|
| CPU | 20% 초과 |
| Memory | 10% 초과 |
| Disk Used | 80% 초과 |

### 파일 위치

```txt
/home/agent-admin/agent-app/bin/monitor.sh
```

### 실행 명령어

```bash
sudo -u agent-admin /home/agent-admin/agent-app/bin/monitor.sh
```

### 실행 결과

```txt
여기에 monitor.sh 실행 결과를 작성한다.
```

---

## 15. monitor.log 로그 포맷

### 로그 파일 위치

```txt
/var/log/agent-app/monitor.log
```

### 로그 포맷

```txt
[YYYY-MM-DD HH:MM:SS] PID:... CPU:..% MEM:..% DISK_USED:..%
```

### 로그 예시

```txt
[2026-02-25 13:58:01] PID:48291 CPU:10.2% MEM:3.2% DISK_USED:23%
```

### 로그 확인 명령어

```bash
tail -n 5 /var/log/agent-app/monitor.log
```

### 확인 결과

```txt
여기에 실행 결과를 작성한다.
```

---

## 16. 로그 용량 관리

### 관리 방식

```txt
logrotate 사용
```

### 정책

| 항목 | 설정 |
|---|---|
| 대상 파일 | `/var/log/agent-app/monitor.log` |
| 최대 크기 | 10MB |
| 보관 개수 | 10개 |

### 설정 파일

```txt
/etc/logrotate.d/agent-app
```

### 설정 내용

```txt
/var/log/agent-app/monitor.log {
    size 10M
    rotate 10
    missingok
    notifempty
    copytruncate
}
```

### 확인 명령어

```bash
cat /etc/logrotate.d/agent-app
logrotate -d /etc/logrotate.d/agent-app
```

### 확인 결과

```txt
여기에 실행 결과를 작성한다.
```

---

## 17. cron 자동 실행

### 설정 내용

`agent-admin` 계정의 crontab에 `monitor.sh`를 매분 실행하도록 등록하였다.

### crontab 내용

```cron
* * * * * /home/agent-admin/agent-app/bin/monitor.sh >> /var/log/agent-app/cron.log 2>&1
```

### 확인 명령어

```bash
sudo -u agent-admin crontab -l
```

### 확인 결과

```txt
여기에 실행 결과를 작성한다.
```

### 자동 실행 확인 명령어

```bash
tail -n 10 /var/log/agent-app/monitor.log
ls -l /var/log/agent-app/monitor.log
```

### 자동 실행 확인 결과

```txt
여기에 1~2분 뒤 monitor.log가 증가한 결과를 작성한다.
```

---

## 18. 최종 검증 체크리스트

| 항목 | 완료 여부 | 증거 위치 |
|---|---|---|
| Ubuntu 22.04 환경 구성 | [ ] | README 2번 |
| Docker Compose 실행 | [ ] | README 4번 |
| SSH 포트 20022 변경 | [ ] | 수행내역서 / README 11번 |
| Root 원격 접속 차단 | [ ] | 수행내역서 / README 11번 |
| UFW 활성화 | [ ] | 수행내역서 / README 12번 |
| 20022/tcp 허용 | [ ] | 수행내역서 / README 12번 |
| 15034/tcp 허용 | [ ] | 수행내역서 / README 12번 |
| agent-admin 계정 생성 | [ ] | 수행내역서 / README 7번 |
| agent-dev 계정 생성 | [ ] | 수행내역서 / README 7번 |
| agent-test 계정 생성 | [ ] | 수행내역서 / README 7번 |
| agent-common 그룹 생성 | [ ] | 수행내역서 / README 7번 |
| agent-core 그룹 생성 | [ ] | 수행내역서 / README 7번 |
| 디렉토리 구조 생성 | [ ] | 수행내역서 / README 8번 |
| 권한 설정 확인 | [ ] | 수행내역서 / README 9번 |
| 키 파일 생성 | [ ] | 수행내역서 / README 10번 |
| agent-app 실행 | [ ] | 수행내역서 / README 13번 |
| Boot Sequence 5단계 OK | [ ] | 수행내역서 / README 13번 |
| Agent READY 출력 | [ ] | 수행내역서 / README 13번 |
| 15034 LISTEN 확인 | [ ] | 수행내역서 / README 13번 |
| monitor.sh 작성 | [ ] | 수행내역서 / README 14번 |
| monitor.sh 권한 750 | [ ] | 수행내역서 / README 9번 |
| monitor.sh 실행 성공 | [ ] | 수행내역서 / README 14번 |
| monitor.log 기록 확인 | [ ] | 수행내역서 / README 15번 |
| logrotate 설정 | [ ] | 수행내역서 / README 16번 |
| cron 매분 실행 등록 | [ ] | 수행내역서 / README 17번 |
| monitor.log 자동 증가 확인 | [ ] | 수행내역서 / README 17번 |

---

## 19. 제출 파일

| 파일 | 설명 |
|---|---|
| `README.md` | 프로젝트 실행 방법 및 구성 설명 |
| `수행내역서.md` 또는 `수행내역서.pdf` | 요구사항 수행 내역 및 증거 자료 |
| `src/monitor.sh` | 시스템 상태 수집 및 로깅 스크립트 |
| `docker-compose.yml` | Ubuntu 실습 컨테이너 실행 설정 |
| `src/agent-app` | 제공 애플리케이션 실행 파일 |

---

## 20. 결론

본 프로젝트에서는 Ubuntu 22.04 환경에서 서버 운영에 필요한 기본 보안 설정, 역할 기반 권한 분리, 애플리케이션 실행 환경 구성, 시스템 상태 모니터링 자동화, cron 기반 주기 실행을 수행하였다.

이를 통해 SSH 포트 변경, root 원격 접속 차단, 필요한 포트만 허용하는 방화벽 정책, 계정/그룹 기반 접근 제어, 로그 기반 시스템 상태 추적의 필요성을 확인하였다.
