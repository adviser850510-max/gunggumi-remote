# 궁구미 원격: 빌드 직전에 원본 소스를 고치는 패치 (Windows 빌드 작업에서 실행)
#
# 1) custom_.txt 허용 — RDGen(https://github.com/bryangerlach/rdgen) .github/patches/allowCustom.py 와
#    같은 방식. read_custom_client()의 서명 검사 블록(9줄)을 지우고 custom.txt → custom_.txt 로 읽게 함.
#    custom_.txt(app-name, default-settings)는 워크플로가 exe 옆에 만든다.
# 2) 접속번호 6자리 숫자 — hbb_common(서브모듈) config.rs
#    - get_auto_id(): 데스크톱은 MAC 주소로 만들던 번호를 무작위 6자리(100000~999999)로
#    - update_id(): 서버가 UUID_MISMATCH로 거절하면 부르는 함수. 새 번호도 6자리로
#    서버(rustdesk-server)는 6자 미만 ID를 거절하므로 6자리가 최소.
# 3) 1회용 비밀번호 4자리 허용 — password_security.rs temporary_password_length()
#
# 찾는 문장이 없으면(원본이 바뀐 경우) 조용히 넘어가지 않고 실패한다.
import sys

COMMON = "src/common.rs"
CONFIG = "libs/hbb_common/src/config.rs"


def fail(msg):
    print("ERROR: " + msg, file=sys.stderr)
    sys.exit(1)


def read(p):
    with open(p, "r", encoding="utf-8") as f:
        return f.read()


def write(p, s):
    with open(p, "w", encoding="utf-8", newline="") as f:
        f.write(s)


def patch_allow_custom():
    lines = read(COMMON).splitlines(keepends=True)
    start = None
    for i, line in enumerate(lines):
        if line.strip().startswith('const KEY: &str = "5Qbwsde3unUcJBtrx9ZkvUmwFNoExHzpryHuPUdqlWM=";'):
            start = i
            break
    if start is None:
        if "custom_.txt" in "".join(lines):
            print("common.rs already patched")
            return
        fail("custom client signature block not found in src/common.rs")
    block = "".join(lines[start:start + 9])
    if "get_rs_pk" not in block or "sign::verify" not in block:
        fail("block at common.rs:%d does not look like the signature check" % (start + 1))
    rest = lines[:start] + lines[start + 9:]
    rest = [l.replace("custom.txt", "custom_.txt") for l in rest]
    write(COMMON, "".join(rest))
    print("common.rs: signature check removed, reads custom_.txt")


def patch_six_digit_id():
    s = read(CONFIG)

    # update_id(): UUID_MISMATCH 때 새 번호
    old_upd = "let new_id = rng.gen_range(1_000_000_000..2_000_000_000).to_string();"
    if s.count(old_upd) != 1:
        fail("update_id() range not found exactly once")
    s = s.replace(old_upd, "let new_id = rng.gen_range(100_000..1_000_000u32).to_string();")

    # get_auto_id() 데스크톱 블록: MAC 기반 → 무작위 6자리
    head = "            let mut id = 0u32;\n            if let Ok(Some(ma)) = mac_address::get_mac_address() {"
    a = s.find(head)
    if a < 0 or s.count(head) != 1:
        fail("get_auto_id() desktop block not found exactly once")
    tail = "            } else {\n                None\n            }\n"
    b = s.find(tail, a)
    if b < 0:
        fail("end of get_auto_id() desktop block not found")
    new_block = (
        "            // Gunggumi: random 6-digit id (server rejects ids shorter than 6)\n"
        "            let id = rand::thread_rng().gen_range(100_000..1_000_000u32);\n"
        "            log::info!(\"Generated id {}\", id);\n"
        "            Some(id.to_string())\n"
    )
    s = s[:a] + new_block + s[b + len(tail):]
    write(CONFIG, s)
    print("config.rs: 6-digit id patched")


PWSEC = "libs/hbb_common/src/password_security.rs"


def patch_four_digit_password():
    # 3) 1회용 비밀번호 4자리 — 원본은 temporary-password-length 로 6/8/10만 받음.
    #    "4"도 받게 한 줄 추가(custom_.txt default-settings 에서 4로 지정).
    s = read(PWSEC)
    old = '    let length = Config::get_option("temporary-password-length");\n    if length == "8" {'
    if s.count(old) != 1:
        fail("temporary_password_length() not found exactly once")
    new = ('    let length = Config::get_option("temporary-password-length");\n'
           '    // Gunggumi: allow 4-digit one-time password\n'
           '    if length == "4" {\n'
           '        4\n'
           '    } else if length == "8" {')
    s = s.replace(old, new)
    write(PWSEC, s)
    print("password_security.rs: 4-digit one-time password allowed")


if __name__ == "__main__":
    patch_allow_custom()
    patch_six_digit_id()
    patch_four_digit_password()
