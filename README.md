# Linux Agent 운영 환경 구축 및 관제 자동화

Ubuntu 22.04 컨테이너에서 SSH·방화벽·계정/그룹/ACL·애플리케이션 실행 환경을 구성하고, Bash 스크립트와 cron으로 프로세스·포트·리소스 상태를 관제하는 미션 저장소입니다.

## 구현 범위

- SSH 포트 `20022/tcp`, Root 원격 로그인 차단
- UFW 기본 인바운드 차단, `20022/tcp`와 `15034/tcp`만 허용
- `agent-admin`, `agent-dev`, `agent-test` 계정 구성
- `agent-common`, `agent-core` 그룹 기반 최소 권한 적용
- 공유·보안 디렉토리 소유권, setgid, 기본 ACL 구성
- 제공 바이너리의 CPU 아키텍처 자동 선택
- `monitor.sh` 프로세스·포트 Health Check와 CPU/MEM/DISK 관제
- 비정상 프로세스/포트에서 `exit 1`
- 방화벽 비활성·임계값 초과는 `[WARNING]`만 출력
- `/var/log/agent-app/monitor.log` 지정 형식 누적 기록
- logrotate `10MB`, `10개`, 압축, `copytruncate`
- `agent-admin` crontab 매분 실행
- 선택 보너스 `report.sh` 통계 리포트

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
│   ├── verify.sh
│   └── test-monitor-failure.sh
└── src/
    ├── monitor.sh
    └── report.sh
```

## 빠른 실행

### 1. 컨테이너 빌드 및 실행

```bash

docker compose up -d --build
docker exec -it agent-linux bash
```

### 2. 운영 환경 구성

컨테이너 내부에서 실행합니다.

```bash
bash /mission/scripts/setup.sh
```

설정 스크립트는 다음을 수행합니다.

1. 계정과 그룹 생성
2. 디렉토리·권한·ACL 설정
3. 현재 CPU 아키텍처에 맞는 앱 설치
4. 키 파일과 로그 파일 생성
5. SSH, UFW, logrotate, cron 구성

### 3. 앱을 포그라운드로 실행하여 Boot Sequence 증거 수집

```bash
bash /mission/scripts/start-agent.sh
```

성공 시 Boot Sequence 5단계 `[OK]`, `Agent READY`, `Agent listening at port 15034`가 출력됩니다. 증거를 저장한 후 `Ctrl+C`로 종료합니다.

### 4. 앱을 백그라운드로 실행

```bash
bash /mission/scripts/start-agent-background.sh
```

```bash
pgrep -a -u agent-admin -x agent-app
ss -ltnp | grep ':15034'
tail -n 30 /var/log/agent-app/agent-app.log
```

### 5. 모니터링 수동 실행

```bash
sudo -u agent-admin /home/agent-admin/agent-app/bin/monitor.sh
echo $?
tail -n 5 /var/log/agent-app/monitor.log
```

정상 시 종료 코드는 `0`입니다. CPU `20%`, 메모리 `10%`, 루트 디스크 `80%`를 초과하면 `[WARNING]`을 출력하지만 종료하지 않습니다.

### 6. 전체 상태 검증

```bash
bash /mission/scripts/verify.sh
```

### 7. cron 자동 증가 확인

```bash
sudo -u agent-admin crontab -l
wc -l /var/log/agent-app/monitor.log
sleep 70
wc -l /var/log/agent-app/monitor.log
tail -n 5 /var/log/agent-app/monitor.log
```

### 8. 앱 중단 시 `exit 1` 테스트

```bash
bash /mission/scripts/stop-agent.sh
bash /mission/scripts/test-monitor-failure.sh
```

테스트 후 앱을 다시 실행합니다.

```bash
bash /mission/scripts/start-agent-background.sh
```

## 환경 변수

| 변수 | 사용 값 | 목적 |
|---|---|---|
| `AGENT_HOME` | `/home/agent-admin/agent-app` | 앱 기준 경로 고정 |
| `AGENT_PORT` | `15034` | 앱 리슨 포트 |
| `AGENT_UPLOAD_DIR` | `/home/agent-admin/agent-app/upload_files` | 공유 업로드 경로 |
| `AGENT_KEY_PATH` | `/home/agent-admin/agent-app/api_keys` | 제공 바이너리가 요구하는 키 디렉토리 |
| `AGENT_LOG_DIR` | `/var/log/agent-app` | 앱 및 관제 로그 경로 |

## 제공 바이너리와 미션 문서의 키 경로 차이

미션 문서는 다음을 요구합니다.

```text
AGENT_KEY_PATH=$AGENT_HOME/api_keys/t_secret.key
```

그러나 제공된 실행 파일을 직접 검증하면 `AGENT_KEY_PATH`에 다음 **디렉토리**를 요구합니다.

```text
/home/agent-admin/agent-app/api_keys
```

그리고 디렉토리 내부의 `secret.key`를 읽습니다. 따라서 `setup.sh`는 두 요구를 모두 증명할 수 있도록 다음 파일을 같은 값으로 생성합니다.

```text
api_keys/t_secret.key  # 미션 문서 요구
api_keys/secret.key    # 제공 바이너리 실제 요구
```

앱 실행 시에는 제공 바이너리가 통과하는 디렉토리 경로를 사용합니다. 수행내역서에 이 차이와 검증 결과를 기록하십시오.

## 권한 정책

| 대상 | 소유자:그룹 | 권한 | 정책 |
|---|---|---:|---|
| `upload_files` | `agent-admin:agent-common` | `2770` | admin/dev/test 읽기·쓰기 |
| `api_keys` | `agent-admin:agent-core` | `2770` | admin/dev만 읽기·쓰기 |
| `/var/log/agent-app` | `agent-admin:agent-core` | `2770` | admin/dev만 읽기·쓰기 |
| `agent-app` | `agent-admin:agent-core` | `750` | 운영 계정 실행 |
| `monitor.sh` | `agent-dev:agent-core` | `750` | dev 소유, admin cron 실행 가능 |

디렉토리의 첫 번째 숫자 `2`는 setgid입니다. 새 파일과 하위 디렉토리가 상위 디렉토리의 그룹을 상속하도록 하여 협업 권한이 깨지는 것을 줄입니다. 기본 ACL도 함께 적용됩니다.

## monitor.sh 설계

### 프로세스 확인

```bash
pgrep -o -u agent-admin -x agent-app
```

- `-u`: 실행 계정을 `agent-admin`으로 제한
- `-x`: 프로세스 이름 전체 일치
- `-o`: PyInstaller 실행 구조에서 여러 PID가 보일 수 있어 가장 오래된 대표 PID 선택

### 포트 확인

```bash
ss -ltnH
```

`ss`는 리슨 중인 TCP 소켓을 직접 확인합니다. 프로세스가 존재해도 소켓 바인딩에 실패할 수 있으므로 프로세스와 포트를 별도로 점검합니다.

### 자원 수집

- CPU: `/proc/stat`을 1초 간격으로 두 번 읽어 전체 시간과 idle 시간의 변화량 계산
- MEM: `/proc/meminfo`의 `MemTotal`과 `MemAvailable`로 사용률 계산
- DISK: `df -P /`에서 루트 파티션 Used `%` 추출

### 종료 정책

- 앱 프로세스 또는 포트 비정상: 서비스 제공 불가 상태이므로 `exit 1`
- UFW 비활성·상태 확인 실패 또는 자원 임계값 초과: 관측 가능한 경고 상태이므로 `[WARNING]` 출력 후 로그 기록 및 `exit 0`

`monitor.sh`는 일반 계정으로 실행되므로, `setup.sh`는 `agent-admin`에게 `/usr/sbin/ufw status` 한 명령만 비밀번호 없이 실행할 수 있는 최소 sudo 권한을 부여합니다. 방화벽 변경 권한은 부여하지 않습니다.

### 로그 누적

```text
[YYYY-MM-DD HH:MM:SS] PID:... CPU:..% MEM:..% DISK_USED:..%
```

스크립트는 `>>`를 사용합니다. `>`는 기존 내용을 덮어쓰지만 `>>`는 기존 로그 뒤에 새 라인을 추가하므로 시간에 따른 장애 원인 추적이 가능합니다.

## logrotate 정책

```text
size 10M
rotate 10
compress
delaycompress
copytruncate
```

- 파일이 10MB 이상일 때 회전
- 이전 파일 10개 유지
- 오래된 회전 파일 압축
- 실행 중인 스크립트의 파일 디스크립터 문제를 줄이기 위해 `copytruncate` 사용
- `/etc/cron.d/agent-logrotate`에서 5분마다 크기 조건 확인

설정 검증:

```bash
logrotate -d /etc/logrotate.d/agent-app
```

강제 동작 검증은 `TODO.md` 절차를 따릅니다.

## 선택 보너스: 통계 리포트

```bash
sudo -u agent-admin /home/agent-admin/agent-app/bin/report.sh
```

CPU/MEM/DISK의 평균·최대·최소와 샘플 수를 출력합니다.

## 제출 준비

실제 실행 결과를 허위로 미리 채우지 않았습니다. 컨테이너를 실행한 뒤 `TODO.md` 순서대로 명령 결과 또는 스크린샷을 수집하여 `수행내역서.md`의 각 증거 영역을 교체하십시오.
