# 궁구미 원격 (gunggumi-remote) — 프로젝트 노트

RustDesk(AGPL-3.0) 포크로 만드는 궁구미컴퓨터 고객 원격 프로그램. 시트롤 대체가 목표.
원본: https://github.com/rustdesk/rustdesk · 우리 저장소: https://github.com/adviser850510-max/gunggumi-remote (공개 유지 — AGPL)

## 정한 것
- 서버: 가게 시놀로지 NAS DS415+(DSM 7.1.1)의 Docker에 RustDesk OSS 서버(hbbs/hbbr). 주소는 gunggumi.iptime.org(ipTIME 공유기 포트포워딩 21115~21119). DS415+는 Atom C2538 결함 위험이 있어 **시험 서버로만** 쓴다.
- 서버 공개키는 NAS `docker/rustdesk-server/id_ed25519.pub`. 빌드에는 GitHub 비밀값 `RENDEZVOUS_SERVER`, `RS_PUB_KEY`로 들어간다.
- 빌드: GitHub Actions "Flutter Nightly Build"(workflow_dispatch) → Releases의 `nightly` 태그에 올라감. 쓰는 건 Windows x86_64 exe/msi.
- 이름·회사명·아이콘은 RDGen(https://github.com/bryangerlach/rdgen, generator-windows.yml)이 바꾸는 파일 목록을 그대로 따른다: 이름 GunggumiRemote, 회사 Gunggumi Computer, 아이콘은 PC 지킴이 방패(초록 #3fb27f, 어두운 바탕 #1c1f26).
- 고객 화면 디자인: **B안(구미 안내형)** 확정 — 단계 막대(번호 알려 주기 → 연결 허용 → 기사님이 해결) + 구미 말풍선. 화면 4개: 첫 화면 / 연결 허용(초록 "허용"·"거절", 시안에 없어 연결 중 화면 틀로 만듦) / 연결 중(경과 시간·할 수 있는 일·빨간 "원격 끝내기") / 끝난 화면. 시안: https://claude.ai/artifact/3bgxoMjNvYMgXspx5z3zkc (색: 바탕 #111318, 카드 #1c1f26, 선 #2b303b, 글자 #e9ecf2, 보조 #9aa3b2, 강조 #3fb27f)
- 접속번호: **6자리 숫자**(예: 482 913), 1회용 비밀번호도 **숫자 6자리**. 근거: rustdesk-server는 6자 미만 ID를 거절(rendezvous_server.rs `id.len() < 6`), 번호는 PC uuid에 묶임. 숫자 비밀번호는 원래 옵션 `allow-numeric-one-time-password` + `temporary-password-length`.
- 기사님 쪽은 원래 RustDesk 화면 그대로.
- 앱 이름·기본 설정은 RDGen 방식 `custom_.txt`(exe 옆, base64 JSON)로 넣는다: app-name=GunggumiRemote, conn-type=incoming(받기 전용=고객용), default-settings(temporary-password-length=6, allow-numeric-one-time-password=Y). 서명 검사는 `.github/gunggumi/patch_gunggumi.py`가 빌드 때 지움(RDGen allowCustom.py와 같음).
- 화면 문장 속 "RustDesk"는 `src/lang.rs` translate()가 APP_NAME으로 바꿔 준다 → 언어 파일은 원본 그대로 둔다.
- 접속번호 6자리: patch_gunggumi.py가 hbb_common `get_auto_id()`·`update_id()`를 무작위 100000~999999로 바꿈. 서버가 UUID_MISMATCH를 보내면 원래 코드(rendezvous_mediator.rs handle_uuid_mismatch)가 update_id()로 새 번호를 뽑는다.
- B안 화면: `flutter/lib/desktop/widgets/gunggumi_ui.dart`. 첫 화면은 desktop_home_page.dart(받기 전용일 때), 연결 중·끝난 화면은 연결 관리(CM) 창 server_page.dart. CM 창은 Windows에서 별도 프로세스(--cm)라 연결 상태는 CM 창에서만 안다.
- 빌드는 Windows x64만(flutter-build.yml에서 다른 작업 if: false). 결과 파일 이름 GunggumiRemote-<버전>-x86_64.exe/.msi.
- 시험 방법: 직원 PC에서 exe 실행 → `%AppData%\GunggumiRemote\log\GunggumiRemote_rCURRENT.log`에 "start rendezvous mediator of gunggumi.iptime.org"와 Latency 줄, 설정 `GunggumiRemote.toml`의 key_confirmed = true 확인. 기사님 쪽은 서버가 박힌 이전 빌드 rustdesk-1.5.3-x86_64.exe를 `--connect <번호> --password <비밀번호>`로 실행.

## 실패한 것과 원인
- GitHub 비밀값만 넣으면 서버가 박힌다고 봤음 → 공용 서버(rs-ny.rustdesk.com)에 붙음 → 지금 소스는 그 값을 읽지 않음(playground.yml만 사용). 해결: flutter-build.yml Windows 작업에 "Set Gunggumi server" 단계 추가(libs/hbb_common/src/config.rs를 sed로 교체, 커밋 023719e).
- master에 push하면 CI·Full Flutter CI가 저절로 돌아 실행 칸을 잡아먹음 → push 직후 그 두 run을 취소한다.
- nightly는 맥·안드로이드·리눅스까지 다 빌드해서 Windows가 늦게 시작됨 → Windows x64만 남김(커밋 b8c19aa). 그래도 한 번에 약 55분(vcpkg·Rust 컴파일이 대부분).
- 언어 파일을 sed `s|RustDesk|..|`(줄당 첫 번째)로 바꿈 → 번역 키 쪽이 먼저 바뀌어 번역이 안 나옴("Show RustDesk" 키가 사라짐) → 원인: 키와 값이 같은 줄. 해결: 언어 파일은 원본으로 되돌리고 APP_NAME만 바꿈(translate()가 치환).
- 하단 "자신만의 서버를 설정해 주세요"로 서버 연결을 판정함 → 서버를 박아도 계속 뜸 → 원인: using_public_server()가 custom-rendezvous-server 옵션만 봄. 해결: RDGen처럼 안내를 끄고(connection_page.dart), 서버 확인은 로그·key_confirmed로 한다.
- B안 끝난 화면을 고객 "원격 끝내기" 때만 띄움 → 기사님 쪽이 끊으면 CM 창이 6초 뒤 그냥 꺼짐 → 원인: 기사님이 끊으면 연결이 '끊김 표시'가 아니라 목록에서 삭제(close=true)됨. 1차 수정: server_model.dart onClientRemove에서 허용된 연결이 지워질 때 GgSession.ended() → run 45229788572에서 다시 실패(창이 바로 꺼짐). 진짜 원인: server_page.dart `onRemoveId()`가 탭이 0개가 되면 즉시 windowManager.close(). 2회 실패 후 운영자가 (가) 선택 → onRemoveId()에서 GgSession.showingEnded면 닫지 않게 함(커밋 1236461) → run 45291778873에서 해결 확인.
- 같은 PC에서 기사님 쪽으로 자기 자신에 접속해 시험하면 내 마우스가 원격 입력으로 되돌아가 CM 창이 "원격 조작 차단"(buildRemoteBlock)에 걸림 → 해결: 기사님 창을 최소화(ShowWindow 6)한 뒤 CM 단추를 누르면 됨(run 45291778873). 누르기 전 WindowFromPoint로 그 자리 창 주인이 CM인지 확인한다. 또 2026-11-24 시험 때 접속 직후 "Windows 보안"(PickerHost) 투명 창이 CM 창 위를 덮고 있었음(원인 미확인).
- 켤 때마다 관리자 실행(바깥 exe manifest requireAdministrator, run 45316315690) → 관리자 실행·설치 카드 숨김은 됨. 하지만 포터블 서비스(UAC 창 조작용)가 안 켜짐: portable-service 로그 "Failed to run as system (os error 3)" → impersonate_system(winlogon 토큰 → CreateProcessWithTokenW)이 이 PC(직원 PC)에서 실패. D:\시험 폴더·다운로드 폴더 두 번 모두 같음. seclogon 서비스는 실행 중. 원인 확인(관리자 cmd로 안쪽 exe --elevate 실행): 관리자 권한·SeDebugPrivilege는 있음, 마지막 단계(SYSTEM 권한으로 새 프로세스 만들기)에서 "경로를 찾을 수 없음"으로 실패. Defender 탐지 기록은 없음. → 다른 직원 PC에서 같은 exe(run 45316315690)는 포터블 서비스 정상(운영자 확인, 2026-11-24). 즉 이 개발 PC 환경 문제(운영자: 이 PC는 UAC 보안 단계를 낮춰 둠) — 관리자 실행 유지. 포터블 서비스 시험은 이 PC에서 하지 말 것.
- 이전 공용 빌드를 돌린 PC는 %AppData%\RustDesk에 rs-ny 설정이 남아 시작 직후 NAT 검사가 rs-ny로 감 → 앱 이름을 바꿔 설정 폴더가 새로 생기면서 사라짐.

## 지켜야 할 규칙
- 바꾸기 전에 RDGen·원본 소스에서 해당 위치를 먼저 찾고, 같은 방식으로 바꾼다.
- "됩니다"는 실제 빌드 exe를 받아 확인한 뒤에만 말한다(파일 정보·실행 화면·서버 연결).
- 서버 연결 판정은 하단 문구가 아니라 로그(gunggumi.iptime.org 등록·Latency)와 key_confirmed = true로 한다.
- 언어 파일(src/lang/*.rs)은 건드리지 않는다. 이름은 APP_NAME(custom_.txt app-name)으로만 바꾼다.
- Flutter 코드는 이 PC에서 컴파일 검사가 안 됨(Flutter SDK 없음) → 화면 변경은 따로 커밋·빌드해서 다른 작업 확인을 막지 않게 한다.
- 비밀번호·키 값은 이 노트·커밋에 적지 않는다(비밀값 이름만).
- CM 창(B안) 단추는 Material 기본 단추(OutlinedButton 등) 대신 색을 직접 지정해 그린다 — CM 테마가 바탕색을 덮어쓴다.
- AGPL: 저장소는 공개 유지.

## 확인된 것 (exe 받아 실행)
- run 45210416802: GunggumiRemote-1.5.3-x86_64.exe, 설정 폴더 %AppData%\GunggumiRemote, 접속번호 6자리, 숫자 6자리 1회용 비밀번호, gunggumi.iptime.org 등록(key_confirmed), 방패 아이콘, 안내 문장 속 이름 GunggumiRemote.
- run 45221407440: B안 첫 화면, 연결 중 화면(경과 시간·할 수 있는 일·빨간 단추) 표시. 기사님 쪽 접속(rustdesk --connect) 성공.
- run 45291778873: 끝난 화면 됨 — ① 기사님이 끊으면 CM 창에 끝난 화면이 남고 "닫기"로 창이 닫힘(홈 창은 남음) ② 고객 "원격 끝내기" → 연결 끊김(로그 "Connection closed: connection manager") → 끝난 화면 → "닫기"로 닫힘. 연결이 끝나면 1회용 비밀번호가 새로 바뀜. 허용 전에 끊긴 연결은 끝난 화면 없이 닫힘(의도대로).

- run 45303839665: B안 연결 허용 화면(GgApproveView) — 틀린 비밀번호 접속 시 표시, "허용" → 연결 중 화면, "거절" → 연결 끊김(로그 "connection manager")·창 닫힘. 끝난 화면 "원격 시간 1분 미만". (run 45298497880에선 "거절"이 흰 바탕이었음 → CM 테마가 OutlinedButton을 덮어씀 → Material+InkWell로 직접 그려 해결)

- run 45309674792: 어두운 테마 고정(custom_.txt override-settings theme=dark) → 첫 화면 제목 막대·CM 탭 막대 어두움. 설치 안내는 B안 둥근 카드(GgNoticeCard). 창 모서리는 Windows 11이 원래 둥글게 그림(화면 캡처 CopyFromScreen으로 확인 — PrintWindow 캡처는 모서리가 안 보임).

## 다음 할 일
0. (보류, 2026-11-24 운영자 결정) 기사님 쪽 현황판 — 설치된 고객 PC·켜진 PC·연결 중 PC 목록. 지금 OSS 서버엔 없음. 후보: 오픈소스 관리 서버(lejianwen/rustdesk-api, NAS에서 되는지 조사 필요) / RustDesk Pro(유료) / hbbs sqlite 읽는 자체 페이지.
1. 포터블 서비스는 다른 직원 PC에서 정상 확인. 남은 시험: 그 PC에 기사님 쪽으로 접속해 UAC 확인 창이 기사님 화면에 보이고 눌리는지(시험 안 함).
   설치 파일(MSI)·앱 안 설치는 만들지 않기로 함(포터블만, disable-installation=Y).
2. 허용 화면에서 "수락 및 권한 상승" 단추를 뺌 — UAC 화면 조작이 필요하면 기사님 쪽 권한 상승 요청으로 되는지 시험 안 함.
3. 직원 PC 두 대로 실제 원격 시험 — 고객 배포는 아직 안 함. 코드 서명 없음(NotSigned).
