# Linux Agent 운영 환경 구축 및 모니터링

Ubuntu 22.04 컨테이너 한 대를 리눅스 운영 서버처럼 구성하고, 제공된 `agent-app`을 실행한 뒤 Bash 스크립트와 cron으로 상태를 점검하는 프로젝트입니다.

계정과 그룹을 역할별로 분리하고, SSH·UFW·ACL·logrotate를 적용하여 애플리케이션 실행부터 모니터링 로그 관리까지 하나의 환경에서 동작하도록 구성했습니다.

## 전체 동작 구조

```text
호스트 PC
   │
   ├─ Docker Compose
   │      └─ Ubuntu 22.04 컨테이너 생성
   │
   ├─ localhost:20022 ── SSH 관리 접속
   └─ localhost:15034 ── agent-app 서비스 접속
                              │
                              ▼
                    Ubuntu 컨테이너 1개
                    ├─ SSH 서버
                    ├─ UFW 방화벽
                    ├─ agent-app
                    ├─ monitor.sh
                    ├─ cron
                    └─ logrotate
```

프로젝트의 실행 흐름은 다음과 같습니다.

```text
Dockerfile
   ↓
필요 패키지가 설치된 Ubuntu 이미지 생성
   ↓
docker-compose.yml
   ↓
포트와 볼륨을 연결하여 컨테이너 실행
   ↓
setup.sh
   ↓
계정·권한·SSH·UFW·cron·logrotate 구성
   ↓
start-agent.sh
   ↓
agent-app 실행 및 15034 포트 LISTEN
   ↓
monitor.sh
   ↓
프로세스·포트·방화벽·자원 사용률 확인
   ↓
monitor.log 누적 기록
```

## 주요 구성

- SSH 관리 포트: `20022/tcp`
- 애플리케이션 포트: `15034/tcp`
- Root SSH 로그인 차단
- UFW 기본 인바운드 차단
- 운영·개발·테스트 계정 분리
- 그룹 및 ACL 기반 디렉토리 접근 제어
- CPU 아키텍처에 맞는 실행 파일 자동 선택
- 프로세스와 포트 상태 점검
- CPU·메모리·디스크 사용률 수집
- cron을 이용한 매분 모니터링
- logrotate를 이용한 로그 용량 관리

## 저장소 구조

```text
.
├── Dockerfile
├── docker-compose.yml
├── README.md
├── TODO.md
├── 수행내역서.md
├── agent-app/
│   ├── agent-app-linux-x86
│   └── agent-app-linux-arm64
├── config/
│   └── agent-app.logrotate
├── scripts/
│   ├── container-entrypoint.sh
│   ├── setup.sh
│   ├── start-agent.sh
│   ├── start-agent-background.sh
│   ├── stop-agent.sh
│   ├── test-monitor-failure.sh
│   └── verify.sh
└── src/
    └── monitor.sh
```

## 파일별 역할

### `Dockerfile`

Ubuntu 22.04를 기반으로 프로젝트 실행에 필요한 패키지를 설치합니다.

주요 설치 항목:

- `openssh-server`: SSH 접속
- `ufw`: 방화벽 설정
- `cron`: 주기적 모니터링 실행
- `acl`: 사용자·그룹별 세부 권한 관리
- `logrotate`: 로그 회전 및 보관
- `sudo`, `procps`, `iproute2`: 권한 전환과 프로세스·포트 확인

### `docker-compose.yml`

Dockerfile로 만든 이미지를 실제 컨테이너로 실행합니다.

담당 항목:

- 컨테이너 이름 지정
- 호스트와 컨테이너 포트 연결
- 프로젝트 디렉토리를 `/mission`에 읽기 전용 마운트
- UFW 사용을 위한 `privileged` 권한
- 컨테이너 재시작 정책

### `config/agent-app.logrotate`

`monitor.log`의 크기가 계속 증가하지 않도록 회전 정책을 설정합니다.

- 로그 크기 `10M` 이상에서 회전
- 이전 로그 최대 10개 보관
- 오래된 로그 압축
- 실행 중에도 같은 로그 경로를 계속 사용할 수 있도록 `copytruncate` 적용

## `scripts` 디렉토리

### `container-entrypoint.sh`

컨테이너가 시작될 때 가장 먼저 실행됩니다.

주요 동작:

- `service cron start`로 cron 시작
- `trap`으로 종료 신호 처리
- 종료 시 SSH와 cron 정리
- `while`, `sleep`, `wait`를 사용하여 컨테이너 유지

이 스크립트는 애플리케이션을 직접 실행하지 않고, 컨테이너가 종료되지 않도록 기본 실행 상태를 유지합니다.

### `setup.sh`

컨테이너 내부의 운영 환경을 한 번에 구성하는 초기화 스크립트입니다.

주요 동작:

1. `groupadd`로 `agent-common`, `agent-core` 그룹 생성
2. `useradd`로 `agent-admin`, `agent-dev`, `agent-test` 계정 생성
3. `usermod -aG`로 역할에 맞는 그룹 배치
4. `install -d`로 디렉토리와 기본 권한 생성
5. `setfacl`로 현재 ACL과 기본 ACL 적용
6. `uname -m`, `case`로 CPU 아키텍처 확인
7. x86 또는 ARM용 `agent-app` 선택 및 설치
8. `monitor.sh`를 운영 경로에 복사
9. API 키와 로그 파일 생성
10. SSH 포트와 Root 로그인 정책 설정
11. UFW 기본 정책 및 허용 포트 설정
12. agent-admin crontab에 `monitor.sh` 등록
13. SSH와 cron 서비스 재시작

`set -euo pipefail`을 사용하여 명령 실패, 정의되지 않은 변수, 파이프라인 오류가 발생하면 설정을 중단합니다.

### `start-agent.sh`

환경 변수를 지정하고 `agent-app`을 포그라운드로 실행합니다.

내부 함수:

- `run_agent()`: `env`로 실행 환경을 전달하고 `exec`로 애플리케이션 실행

주요 동작:

- `pgrep`로 중복 실행 방지
- Root로 실행하면 `runuser`로 `agent-admin` 계정 전환
- `agent-admin`이 아닌 일반 계정의 직접 실행 차단
- `AGENT_HOME`, `AGENT_PORT`, 업로드·키·로그 경로 전달
- `exec`를 사용하여 셸 프로세스를 애플리케이션 프로세스로 교체

포그라운드 실행이므로 애플리케이션의 Boot Sequence를 터미널에서 바로 확인할 수 있습니다.

### `start-agent-background.sh`

`agent-app`을 백그라운드에서 실행합니다.

주요 동작:

- `pgrep`로 기존 프로세스 확인
- `nohup`과 `&`를 사용한 백그라운드 실행
- 표준 출력과 오류를 `agent-app.log`에 누적
- 실행 후 다시 `pgrep`하여 시작 성공 여부 확인

### `stop-agent.sh`

실행 중인 애플리케이션을 종료합니다.

주요 동작:

- `pkill -u agent-admin -x agent-app`으로 대상 프로세스만 종료
- 프로세스가 없으면 오류 대신 현재 상태 안내

사용자와 프로세스 이름을 함께 제한하여 다른 프로세스를 잘못 종료하지 않도록 구성했습니다.

### `test-monitor-failure.sh`

애플리케이션이 중지된 상태에서 `monitor.sh`의 장애 감지 동작을 확인합니다.

주요 동작:

- `pgrep`로 애플리케이션 중지 상태 확인
- `set +e`로 실패 종료 코드를 직접 수집
- `runuser`로 `agent-admin` 권한에서 모니터 실행
- `$?`로 종료 코드 저장
- 모니터가 `1`을 반환했는지 확인

### `verify.sh`

계정, 보안 설정, 파일 권한, 서비스 상태를 한 번에 확인하는 읽기 전용 검증 스크립트입니다.

내부 함수:

- `ok()`: 성공 메시지 출력 및 성공 개수 증가
- `no()`: 실패 메시지 출력 및 실패 개수 증가
- `check()`: 검사 명령을 실행한 뒤 `ok()` 또는 `no()` 호출

주요 확인 항목:

- 사용자와 그룹 존재 여부
- 계정별 그룹 소속
- SSH 포트와 Root 로그인 정책
- SSH 실제 LISTEN 상태
- UFW 활성화와 허용 포트
- `monitor.sh` 소유자·그룹·권한
- 키 파일과 logrotate 설정 존재 여부
- cron 등록 여부
- 애플리케이션 프로세스와 15034 포트 상태

마지막에 성공과 실패 개수를 요약하고, 실패 항목이 있으면 비정상 종료합니다.

## `src/monitor.sh`

애플리케이션과 시스템 상태를 확인하고 결과를 로그에 기록하는 핵심 모니터링 스크립트입니다.

내부 함수:

- `warn()`: 경고 메시지 출력 및 경고 개수 증가
- `fail()`: 장애 메시지를 출력하고 `exit 1`
- `is_greater_than()`: 측정값이 임계값보다 큰지 비교
- `read_cpu_snapshot()`: `/proc/stat`에서 CPU 누적값 읽기
- `get_cpu_usage()`: 두 CPU 스냅샷의 차이로 사용률 계산
- `get_memory_usage()`: `/proc/meminfo`로 메모리 사용률 계산
- `get_disk_usage()`: `df -P /`로 루트 디스크 사용률 확인

모니터링 순서:

1. `pgrep`로 `agent-admin`의 `agent-app` 프로세스 확인
2. `ss`로 TCP 15034 포트 LISTEN 확인
3. 최소 sudo 권한으로 UFW 상태 확인
4. 로그 디렉토리 존재 여부와 쓰기 권한 확인
5. CPU·메모리·디스크 사용률 수집
6. 설정된 임계값과 비교
7. 한 줄 형식으로 `monitor.log`에 누적 기록

프로세스나 포트가 정상적이지 않으면 서비스 장애로 판단하여 `exit 1`을 반환합니다. 자원 임계값 초과와 UFW 상태 문제는 경고로 기록하되 측정 로그는 계속 남깁니다.

로그 형식:

```text
[YYYY-MM-DD HH:MM:SS] PID:값 CPU:값% MEM:값% DISK_USED:값%
```

## 계정 및 권한 구조

| 계정 | 소속 그룹 | 역할 |
|---|---|---|
| `agent-admin` | `agent-common`, `agent-core` | 앱 실행, cron 모니터링 |
| `agent-dev` | `agent-common`, `agent-core` | 모니터 스크립트 관리 |
| `agent-test` | `agent-common` | 업로드 영역 테스트 |

| 경로 | 소유자:그룹 | 권한 | 접근 목적 |
|---|---|---:|---|
| `upload_files` | `agent-admin:agent-common` | `2770` | 세 계정이 함께 사용하는 업로드 영역 |
| `api_keys` | `agent-admin:agent-core` | `2770` | 운영·개발 계정만 접근하는 키 영역 |
| `/var/log/agent-app` | `agent-admin:agent-core` | `2770` | 운영 로그 저장 영역 |
| `agent-app` | `agent-admin:agent-core` | `750` | 운영 계정의 애플리케이션 실행 |
| `monitor.sh` | `agent-dev:agent-core` | `750` | 개발 계정 소유, 운영 계정 실행 |

디렉토리 권한의 `2`는 setgid 비트입니다. 하위에 생성되는 파일과 디렉토리가 상위 디렉토리의 그룹을 유지하도록 합니다. 기본 ACL도 함께 적용하여 새 파일에서도 접근 정책이 이어지도록 했습니다.

## 애플리케이션 환경 변수

| 변수 | 값 | 용도 |
|---|---|---|
| `AGENT_HOME` | `/home/agent-admin/agent-app` | 애플리케이션 기준 경로 |
| `AGENT_PORT` | `15034` | 서비스 리슨 포트 |
| `AGENT_UPLOAD_DIR` | `/home/agent-admin/agent-app/upload_files` | 업로드 파일 경로 |
| `AGENT_KEY_PATH` | `/home/agent-admin/agent-app/api_keys` | 키 파일이 위치한 디렉토리 |
| `AGENT_LOG_DIR` | `/var/log/agent-app` | 애플리케이션 및 모니터 로그 경로 |

제공된 실행 파일은 `AGENT_KEY_PATH`에 키 파일 자체가 아니라 `secret.key`가 들어 있는 디렉토리 경로를 사용합니다. 호환성을 위해 `setup.sh`는 `secret.key`와 `t_secret.key`를 같은 값으로 생성합니다.

## 실행 방법

### 1. 이미지 빌드 및 컨테이너 실행

```bash
docker compose up -d --build
docker exec -it agent-linux bash
```

### 2. 운영 환경 구성

```bash
bash /mission/scripts/setup.sh
```

SSH 비밀번호 접속을 사용할 경우:

```bash
passwd agent-admin
```

### 3. 애플리케이션 실행

포그라운드 실행:

```bash
bash /mission/scripts/start-agent.sh
```

백그라운드 실행:

```bash
bash /mission/scripts/start-agent-background.sh
```

### 4. 모니터링 실행

```bash
sudo -u agent-admin /home/agent-admin/agent-app/bin/monitor.sh
echo $?
tail -n 5 /var/log/agent-app/monitor.log
```

### 5. 전체 상태 확인

```bash
bash /mission/scripts/verify.sh
```

### 6. 애플리케이션 종료 및 재시작

```bash
bash /mission/scripts/stop-agent.sh
bash /mission/scripts/start-agent-background.sh
```

## 로그 관리

주요 로그 경로:

```text
/var/log/agent-app/agent-app.log
/var/log/agent-app/monitor.log
/var/log/agent-app/cron.log
```

`monitor.sh`는 `>>` 연산자로 기존 로그 뒤에 결과를 추가합니다. cron은 매분 모니터를 실행하며, 별도의 cron 항목이 5분마다 logrotate 정책을 확인합니다.
