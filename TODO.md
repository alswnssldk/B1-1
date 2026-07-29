# 내려받은 뒤 수행할 TODO List

이 파일은 저장소를 내려받은 뒤 **직접 실행하고 증거를 수집해야 하는 작업**만 정리한 체크리스트입니다. 체크박스는 실제 확인 후에만 완료로 바꾸십시오.

## 0. 사전 준비

- [ ] Docker와 Docker Compose가 설치되어 있는지 확인한다.

```bash
docker --version
docker compose version
```

- [ ] 저장소 루트에서 파일 구조를 확인한다.

```bash
find . -maxdepth 3 -type f | sort
```

## 1. 컨테이너 실행

- [ ] Ubuntu 22.04 이미지를 빌드하고 컨테이너를 실행한다.

```bash
docker compose up -d --build
docker compose ps
```

- [ ] 컨테이너 내부로 들어간다.

```bash
docker exec -it agent-linux bash
```

## 2. 환경 자동 구성

- [ ] root로 설정 스크립트를 실행한다.

```bash
bash /mission/scripts/setup.sh
```

- [ ] 스크립트가 오류 없이 끝났는지 확인한다.
- [ ] SSH 비밀번호 로그인까지 시험할 경우 임시 비밀번호를 설정한다.

```bash
passwd agent-admin
```

> 제출이 끝나면 비밀번호를 잠그거나 컨테이너를 삭제한다.

## 3. SSH 보안 증거

- [ ] SSH 포트가 20022인지 확인한다.
- [ ] Root 원격 로그인이 차단됐는지 확인한다.
- [ ] sshd가 20022에서 LISTEN 중인지 확인한다.

```bash
cat /etc/ssh/sshd_config.d/99-agent-mission.conf
sshd -T | grep -E '^(port|permitrootlogin|passwordauthentication) '
ss -ltnp | grep ':20022'
```

- [ ] 필요하면 호스트의 새 터미널에서 실제 접속을 확인한다.

```bash
ssh -p 20022 agent-admin@127.0.0.1
```

- [ ] 위 결과를 `수행내역서.md`의 SSH 증거 영역에 붙여넣거나 스크린샷으로 첨부한다.

## 4. UFW 증거

- [ ] UFW가 active인지 확인한다.
- [ ] 인바운드 허용 규칙이 20022/tcp와 15034/tcp인지 확인한다.

```bash
ufw status verbose
ufw status numbered
```

- [ ] 예상 외 허용 규칙이 없는지 확인한다.
- [ ] 결과를 수행내역서에 기록한다.

## 5. 계정·그룹·ACL 증거

- [ ] 세 계정과 두 그룹을 확인한다.

```bash
id agent-admin
id agent-dev
id agent-test
getent group agent-common
getent group agent-core
```

- [ ] 디렉토리와 스크립트 소유권·권한을 확인한다.

```bash
ls -ld /home/agent-admin/agent-app/upload_files
ls -ld /home/agent-admin/agent-app/api_keys
ls -ld /var/log/agent-app
ls -l /home/agent-admin/agent-app/agent-app
ls -l /home/agent-admin/agent-app/bin/monitor.sh
```

- [ ] 기본 ACL을 확인한다.

```bash
getfacl /home/agent-admin/agent-app/upload_files
getfacl /home/agent-admin/agent-app/api_keys
getfacl /var/log/agent-app
```

- [ ] `agent-test`는 공유 디렉토리에 쓸 수 있는지 시험한다.

```bash
sudo -u agent-test touch /home/agent-admin/agent-app/upload_files/test-by-agent-test.txt
ls -l /home/agent-admin/agent-app/upload_files
```

- [ ] `agent-test`는 보안 디렉토리에 접근하지 못하는지 시험한다.

```bash
sudo -u agent-test ls /home/agent-admin/agent-app/api_keys
```

예상 결과: `Permission denied`

- [ ] `agent-dev`는 보안 디렉토리에 접근 가능한지 시험한다.

```bash
sudo -u agent-dev ls -l /home/agent-admin/agent-app/api_keys
```

- [ ] 결과를 수행내역서에 기록한다.

## 6. 키 경로 차이 증거

- [ ] 미션 문서용 `t_secret.key`와 바이너리용 `secret.key`를 확인한다.

```bash
ls -l /home/agent-admin/agent-app/api_keys
sudo -u agent-admin cat /home/agent-admin/agent-app/api_keys/t_secret.key
sudo -u agent-admin cat /home/agent-admin/agent-app/api_keys/secret.key
```

- [ ] 수행내역서에 “문서와 제공 바이너리의 요구 경로가 달라 두 파일을 생성했으며, 실제 실행 환경 변수는 디렉토리를 사용했다”고 기록한다.

## 7. 앱 Boot Sequence 증거

- [ ] 포그라운드 실행으로 Boot Sequence를 수집한다.

```bash
bash /mission/scripts/start-agent.sh
```

- [ ] 다음 항목이 출력되는지 확인한다.
  - [ ] 1/5 사용자 계정 `[OK]`
  - [ ] 2/5 환경 변수 `[OK]`
  - [ ] 3/5 키 파일 `[OK]`
  - [ ] 4/5 포트 사용 가능 `[OK]`
  - [ ] 5/5 로그 권한 `[OK]`
  - [ ] `All Boot Checks Passed!`
  - [ ] `Agent READY`
  - [ ] `Agent listening at port 15034`
- [ ] 출력 결과를 저장한 뒤 `Ctrl+C`로 종료한다.

## 8. 앱 백그라운드 실행 및 포트 증거

- [ ] 앱을 백그라운드로 시작한다.

```bash
bash /mission/scripts/start-agent-background.sh
```

- [ ] 프로세스와 포트를 확인한다.

```bash
pgrep -a -u agent-admin -x agent-app
ss -ltnp | grep ':15034'
tail -n 30 /var/log/agent-app/agent-app.log
```

- [ ] 결과를 수행내역서에 기록한다.

## 9. monitor.sh 정상 테스트

- [ ] 소유자·그룹·권한이 `agent-dev:agent-core`, `750`인지 확인한다.

```bash
stat -c '%U:%G %a %n' /home/agent-admin/agent-app/bin/monitor.sh
```

- [ ] `agent-admin`으로 실행한다.

```bash
sudo -u agent-admin /home/agent-admin/agent-app/bin/monitor.sh
echo "exit=$?"
```

- [ ] 다음을 확인한다.
  - [ ] 프로세스 `[OK]`
  - [ ] 포트 `[OK]`
  - [ ] UFW 상태
  - [ ] CPU/MEM/DISK 값
  - [ ] 임계값 초과 시 `[WARNING]`
  - [ ] 정상 Health Check에서는 `exit=0`
- [ ] 결과를 수행내역서에 기록한다.

## 10. monitor.log 누적 증거

- [ ] 현재 로그 라인 수와 최근 값을 확인한다.

```bash
wc -l /var/log/agent-app/monitor.log
tail -n 5 /var/log/agent-app/monitor.log
```

- [ ] monitor.sh를 한 번 더 실행한다.

```bash
sudo -u agent-admin /home/agent-admin/agent-app/bin/monitor.sh
wc -l /var/log/agent-app/monitor.log
tail -n 5 /var/log/agent-app/monitor.log
```

- [ ] 이전 로그가 보존되고 새 줄이 뒤에 추가됐는지 확인한다.
- [ ] `>`와 `>>` 차이 및 누적 로그에 `>>`가 필요한 이유를 수행내역서에 설명한다.

## 11. cron 자동 실행 증거

- [ ] `agent-admin`의 crontab을 확인한다.

```bash
sudo -u agent-admin crontab -l
service cron status
```

- [ ] 70초 전후 라인 수를 비교한다.

```bash
before=$(wc -l < /var/log/agent-app/monitor.log)
echo "before=$before"
sleep 70
after=$(wc -l < /var/log/agent-app/monitor.log)
echo "after=$after"
tail -n 5 /var/log/agent-app/monitor.log
```

- [ ] `after`가 `before`보다 큰지 확인한다.
- [ ] 결과를 수행내역서에 기록한다.

## 12. 비정상 상태에서 exit 1 증거

- [ ] 앱을 중단한다.

```bash
bash /mission/scripts/stop-agent.sh
```

- [ ] 실패 테스트를 실행한다.

```bash
bash /mission/scripts/test-monitor-failure.sh
echo "test_exit=$?"
```

- [ ] monitor.sh가 프로세스 비정상을 감지하고 자체적으로 `exit 1`을 반환했다는 출력을 기록한다.
- [ ] 앱을 다시 시작한다.

```bash
bash /mission/scripts/start-agent-background.sh
```

## 13. logrotate 설정·동작 증거

- [ ] 설정 파일과 디버그 결과를 확인한다.

```bash
cat /etc/logrotate.d/agent-app
logrotate -d /etc/logrotate.d/agent-app
```

- [ ] 테스트 전에 로그를 백업한다.

```bash
cp /var/log/agent-app/monitor.log /tmp/monitor.log.before-rotate
```

- [ ] 10MB를 넘도록 테스트 데이터를 추가한다.

```bash
dd if=/dev/zero bs=1M count=11 >> /var/log/agent-app/monitor.log
ls -lh /var/log/agent-app/monitor.log
```

- [ ] 강제로 회전하고 파일을 확인한다.

```bash
logrotate -f /etc/logrotate.d/agent-app
ls -lh /var/log/agent-app
```

- [ ] `monitor.log`와 회전 파일이 생성됐는지 확인한다.
- [ ] `size 10M`, `rotate 10`, `compress`, `copytruncate`의 의미를 수행내역서에 설명한다.

> 위 테스트는 로그에 0바이트 데이터를 넣습니다. 평가 증거를 확보한 뒤 필요하면 컨테이너를 다시 만들어 깨끗한 환경에서 재실행하십시오.

## 14. 전체 자동 검증

- [ ] 앱이 실행 중인 상태에서 검증 스크립트를 실행한다.

```bash
bash /mission/scripts/verify.sh
```

- [ ] `FAIL=0`인지 확인한다.
- [ ] 실패 항목이 있으면 원인을 해결하고 다시 실행한다.

## 15. 선택 보너스 report.sh

- [ ] 누적 로그 통계를 출력한다.

```bash
sudo -u agent-admin /home/agent-admin/agent-app/bin/report.sh
```

- [ ] CPU/MEM/DISK 평균·최대·최소와 샘플 수를 확인한다.
- [ ] 수행한 경우 결과를 수행내역서의 보너스 영역에 기록한다.

## 16. 수행내역서 완성

- [ ] `수행내역서.md`의 모든 `[실행 결과 붙여넣기]` 영역을 실제 결과로 교체한다.
- [ ] 명령어와 결과가 같은 환경에서 나온 것인지 확인한다.
- [ ] 비밀번호, 개인키, 실제 비밀값을 문서에 포함하지 않는다.
- [ ] 키 값은 과제에서 지정한 테스트 문자열만 표시한다.
- [ ] 평가항목 설명 질문에 대한 답변을 자기 말로 검토한다.
- [ ] 필요하면 Markdown을 PDF로 변환한다.

## 17. 제출 전 최종 확인

- [ ] SSH 포트 20022와 Root 로그인 차단 증거가 있다.
- [ ] UFW active와 두 허용 포트 증거가 있다.
- [ ] 계정·그룹·ACL과 접근 성공/실패 증거가 있다.
- [ ] Boot Sequence 5단계와 `Agent READY` 증거가 있다.
- [ ] monitor.sh 정상 실행과 `exit 0` 증거가 있다.
- [ ] 앱 중단 시 `exit 1` 증거가 있다.
- [ ] 지정 포맷의 monitor.log 누적 증거가 있다.
- [ ] cron 등록 및 1분 후 로그 증가 증거가 있다.
- [ ] logrotate 10MB/10개 설정 및 동작 증거가 있다.
- [ ] `monitor.sh` 소스코드가 제출물에 포함돼 있다.
- [ ] 수행내역서의 설명 문항을 말로 답할 수 있다.
