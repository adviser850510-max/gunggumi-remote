# 궁구미 원격 (gunggumi-remote) — 프로젝트 노트

RustDesk(AGPL-3.0) 포크로 만드는 궁구미컴퓨터 고객 원격 프로그램. 시트롤 대체가 목표.
원본: https://github.com/rustdesk/rustdesk · 우리 저장소: https://github.com/adviser850510-max/gunggumi-remote (공개 유지 — AGPL)

## 정한 것
- 서버: 가게 시놀로지 NAS DS415+(DSM 7.1.1)의 Docker에 RustDesk OSS 서버(hbbs/hbbr). 주소는 gunggumi.iptime.org(ipTIME 공유기 포트포워딩 21115~21119). DS415+는 Atom C2538 결함 위험이 있어 **시험 서버로만** 쓴다.
- 서버 공개키는 NAS `docker/rustdesk-server/id_ed25519.pub`. 빌드에는 GitHub 비밀값 `RENDEZVOUS_SERVER`, `RS_PUB_KEY`로 들어간다.
- 빌드: GitHub Actions "Flutter Nightly Build"(workflow_dispatch) → Releases의 `nightly` 태그에 올라감. 쓰는 건 Windows x86_64 exe/msi.
- 이름·회사명·아이콘은 RDGen(https://github.com/bryangerlach/rdgen, generator-windows.yml)이 바꾸는 파일 목록을 그대로 따른다: 이름 GunggumiRemote, 회사 Gunggumi Computer, 아이콘은 PC 지킴이 방패(초록 #3fb27f, 어두운 바탕 #1c1f26).
- 고객 화면 디자인: **B안(구미 안내형)** 확정 — 단계 막대(번호 알려 주기 → 연결 허용 → 기사님이 해결) + 구미 말풍선. 화면 3개: 첫 화면 / 연결 중(경과 시간·할 수 있는 일·빨간 "원격 끝내기") / 끝난 화면. 시안: https://claude.ai/artifact/3bgxoMjNvYMgXspx5z3zkc (색: 바탕 #111318, 카드 #1c1f26, 선 #2b303b, 글자 #e9ecf2, 보조 #9aa3b2, 강조 #3fb27f)
- 접속번호: **6자리 숫자**(예: 482 913), 1회용 비밀번호도 **숫자 6자리**. 근거: rustdesk-server는 6자 미만 ID를 거절(rendezvous_server.rs `id.len() < 6`), 번호는 PC uuid에 묶임. 숫자 비밀번호는 원래 옵션 `allow-numeric-one-time-password` + `temporary-password-length`.
- 기사님 쪽은 원래 RustDesk 화면 그대로.

## 실패한 것과 원인
- GitHub 비밀값만 넣으면 서버가 박힌다고 봤음 → 공용 서버(rs-ny.rustdesk.com)에 붙음 → 지금 소스는 그 값을 읽지 않음(playground.yml만 사용). 해결: flutter-build.yml Windows 작업에 "Set Gunggumi server" 단계 추가(libs/hbb_common/src/config.rs를 sed로 교체, 커밋 023719e).
- master에 push하면 CI·Full Flutter CI가 저절로 돌아 실행 칸을 잡아먹음 → push 직후 그 두 run을 취소한다.
- nightly는 맥·안드로이드·리눅스까지 다 빌드해서 Windows가 늦게 시작됨(40~60분).

## 지켜야 할 규칙
- 바꾸기 전에 RDGen·원본 소스에서 해당 위치를 먼저 찾고, 같은 방식으로 바꾼다.
- "됩니다"는 실제 빌드 exe를 받아 확인한 뒤에만 말한다(파일 정보·실행 화면·서버 연결).
- 하단에 "자신만의 서버를 설정해 주세요" 문구가 보이면 공용 서버에 붙은 것 = 실패.
- 비밀번호·키 값은 이 노트·커밋에 적지 않는다(비밀값 이름만).
- AGPL: 저장소는 공개 유지.

## 다음 할 일
1. 빌드 run 45202110553(커밋 023719e) 결과 확인 → exe 받아 실행 → 하단 문구가 사라지고 ID가 뜨는지, 창 아이콘이 방패인지 확인.
2. 남은 이름 정리: 설정 폴더가 아직 %AppData%의 RustDesk(hbb_common APP_NAME), 안내 문장 속 "RustDesk" 잔여(sed가 줄당 첫 번째만 바꿈), 내려받는 파일 이름 rustdesk-1.5.3-*.exe.
3. 접속번호 6자리: hbb_common config.rs `get_auto_id()`를 무작위 6자리로, 서버가 UUID_MISMATCH로 거절하면 새 번호로 재시도.
4. 숫자 6자리 1회용 비밀번호를 기본값으로.
5. B안 화면을 Flutter 데스크톱 홈 화면(flutter/lib/desktop/pages/desktop_home_page.dart 등)에 입히기 — 연결 중·끝난 화면 포함.
6. 테스트 끝나면 flutter-nightly.yml의 매일 자동 빌드(cron) 끄기, 필요 없는 플랫폼 빌드 빼기.
7. 직원 PC 시험(서버 gunggumi.iptime.org) — 고객 배포는 아직 안 함.
