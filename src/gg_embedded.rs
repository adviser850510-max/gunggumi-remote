//! 궁구미 원격: PC 지킴이 모드(창 없이 실행) — 고객 화면에는 PC 지킴이 창 하나만 보이게.
//!
//! 켜기: 관리자 권한으로 안쪽 exe를 `GunggumiRemote.exe --server --gg-embedded` 로 실행.
//! - 본창·연결 관리 창(CM)·트레이를 띄우지 않는다. 원본 `--server`(창 없는 서버)를 그대로 쓰고,
//!   CM은 이 프로세스 안에서 창 없이 돈다: 원본 `ui_cm_interface::start_ipc` 에 화면 대신
//!   상태 파일을 쓰는 `GgCm` 을 끼운다. 서버는 `_cm` 파이프에 이미 CM이 있으므로 `--cm` 창을 띄우지 않는다.
//! - 포터블 서비스(UAC 창 조작)는 관리자 권한일 때 원본과 같이 시작한다.
//!
//! 상태 파일: `%AppData%\GunggumiRemote\gg_state.json` — 바뀔 때마다 임시 파일에 쓰고 이름을 바꾼다.
//! 명령: `GunggumiRemote.exe --gg-cmd accept|reject|close|new-password`
//! - 명령 파이프(`_ggcmd`)는 SDDL `D:P(A;;GA;;;SY)(A;;GA;;;BA)` 로 SYSTEM과 관리자(BA)만 열 수 있다.
//!   관리자 계정이라도 관리자 권한으로 실행하지 않은 프로그램은 BA가 '거부 전용'이라 열 수 없다.
//!   → 일반 권한 프로그램은 '허용'을 보낼 수 없다.
//! - 결과는 종료 코드: 0 = 처리됨, 1 = 처리할 것 없음/모르는 명령, 2 = 지킴이 모드 프로세스에 못 붙음(권한 없음 포함).

use crate::ipc::{self, Data};
use crate::ui_cm_interface::{self, Client, ConnectionManager, InvokeUiCM};
use hbb_common::{
    allow_err, bail, config::Config, futures::StreamExt as _, log, password_security, tokio,
    ResultType,
};
use parity_tokio_ipc::{Endpoint, SecurityAttributes};
use std::{collections::BTreeMap, sync::Mutex, time::Duration};

pub const ARG: &str = "--gg-embedded";
pub const CMD_ARG: &str = "--gg-cmd";
const CMD_POSTFIX: &str = "_ggcmd";
const CMD_SDDL: &str = "D:P(A;;GA;;;SY)(A;;GA;;;BA)";
const CMD_NAME: &str = "gg-cmd";

#[derive(Clone)]
struct Peer {
    name: String,
    peer_id: String,
    authorized: bool,
    is_remote: bool,
    keyboard: bool,
    file: bool,
    clipboard: bool,
    since: i64,
}

lazy_static::lazy_static! {
    static ref PEERS: Mutex<BTreeMap<i32, Peer>> = Default::default();
    static ref LAST_WRITTEN: Mutex<String> = Default::default();
    static ref ENDED: Mutex<bool> = Mutex::new(false);
}

fn now_secs() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

fn state_path() -> std::path::PathBuf {
    let base = std::env::var("APPDATA").unwrap_or_default();
    std::path::Path::new(&base)
        .join(crate::get_app_name())
        .join("gg_state.json")
}

/// 상태 파일 쓰기. 내용이 그대로면 쓰지 않는다. 임시 파일 → 이름 바꾸기(원자적).
fn write_state() {
    let peers = PEERS.lock().unwrap().clone();
    let main = peers
        .iter()
        .find(|(_, p)| p.is_remote)
        .or_else(|| peers.iter().next());
    let ended = *ENDED.lock().unwrap();
    let (state, state_ko) = match main {
        None => {
            if ended {
                ("ended", "끊김")
            } else {
                ("waiting", "대기")
            }
        }
        Some((_, p)) => {
            if p.authorized {
                ("connected", "연결됨")
            } else {
                ("requested", "요청 옴")
            }
        }
    };
    let v = serde_json::json!({
        "id": Config::get_id(),
        "password": password_security::temporary_password(),
        "state": state,
        "state_ko": state_ko,
        "technician": main.map(|(_, p)| p.name.clone()).unwrap_or_default(),
        "technician_id": main.map(|(_, p)| p.peer_id.clone()).unwrap_or_default(),
        "conn_id": main.map(|(id, _)| *id).unwrap_or(0),
        "connected_at": main.map(|(_, p)| p.since).unwrap_or(0),
        "permissions": {
            "view": main.is_some(),
            "input": main.map(|(_, p)| p.keyboard).unwrap_or(false),
            "file": main.map(|(_, p)| p.file).unwrap_or(false),
            "clipboard": main.map(|(_, p)| p.clipboard).unwrap_or(false),
        },
        "connections": peers.len(),
    });
    let s = v.to_string();
    {
        let mut last = LAST_WRITTEN.lock().unwrap();
        if *last == s {
            return;
        }
        *last = s.clone();
    }
    let path = state_path();
    if let Some(dir) = path.parent() {
        std::fs::create_dir_all(dir).ok();
    }
    let tmp = path.with_extension("json.tmp");
    match std::fs::write(&tmp, s.as_bytes()) {
        Ok(_) => {
            if let Err(e) = std::fs::rename(&tmp, &path) {
                log::error!("gg_state: rename failed: {}", e);
                LAST_WRITTEN.lock().unwrap().clear();
            }
        }
        Err(e) => {
            log::error!("gg_state: write failed: {}", e);
            LAST_WRITTEN.lock().unwrap().clear();
        }
    }
}

/// 창 없는 CM: 원본 CM 화면 대신 상태 파일을 쓴다.
#[derive(Clone)]
struct GgCm;

impl InvokeUiCM for GgCm {
    fn add_connection(&self, c: &Client) {
        let is_remote = !c.is_file_transfer
            && !c.is_terminal
            && !c.is_view_camera
            && c.port_forward.is_empty();
        {
            let mut peers = PEERS.lock().unwrap();
            let old_since = peers.get(&c.id).map(|p| p.since).unwrap_or(0);
            peers.insert(
                c.id,
                Peer {
                    name: c.name.clone(),
                    peer_id: c.peer_id.clone(),
                    authorized: c.authorized,
                    is_remote,
                    keyboard: c.keyboard,
                    file: c.file,
                    clipboard: c.clipboard,
                    since: if c.authorized {
                        if old_since > 0 {
                            old_since
                        } else {
                            now_secs()
                        }
                    } else {
                        0
                    },
                },
            );
        }
        *ENDED.lock().unwrap() = false;
        write_state();
    }

    fn remove_connection(&self, id: i32, _close: bool) {
        let empty = {
            let mut peers = PEERS.lock().unwrap();
            peers.remove(&id);
            peers.is_empty()
        };
        if empty {
            *ENDED.lock().unwrap() = true;
        }
        write_state();
    }

    fn new_message(&self, _id: i32, _text: String) {}

    fn change_theme(&self, _dark: String) {}

    fn change_language(&self) {}

    fn show_elevation(&self, _show: bool) {}

    fn update_voice_call_state(&self, _client: &Client) {}

    fn file_transfer_log(&self, _action: &str, _log: &str) {}
}

/// `--server --gg-embedded` 일 때 core_main이 서버를 시작하기 전에 부른다.
pub fn start() {
    log::info!("gunggumi embedded mode (PC 지킴이 모드)");
    // 포터블 서비스(UAC 창 조작): 원본 quick support와 같이, 설치 안 됐고 관리자 권한일 때
    if !crate::platform::is_installed() && crate::platform::is_elevated(None).unwrap_or(false) {
        use crate::portable_service::client;
        client::set_quick_support(true);
        if let Err(e) = client::start_portable_service(client::StartPara::Direct) {
            log::error!("gg embedded: failed to start portable service: {:?}", e);
        }
    }
    // 창 없는 CM — 서버가 연결을 받기 전에 `_cm` 파이프를 먼저 연다
    std::thread::spawn(|| {
        ui_cm_interface::start_ipc(ConnectionManager { ui_handler: GgCm });
    });
    std::thread::spawn(start_cmd_server);
    // 접속번호·1회용 비밀번호가 바뀌면 다시 쓴다(연결이 끝나면 비밀번호가 바뀜)
    std::thread::spawn(|| loop {
        write_state();
        std::thread::sleep(Duration::from_secs(1));
    });
}

fn handle_cmd(cmd: &str) -> String {
    let peers = PEERS.lock().unwrap().clone();
    let res = match cmd {
        "accept" => {
            let ids: Vec<i32> = peers
                .iter()
                .filter(|(_, p)| !p.authorized)
                .map(|(id, _)| *id)
                .collect();
            if ids.is_empty() {
                "nothing".to_owned()
            } else {
                for id in ids.iter() {
                    ui_cm_interface::authorize(*id);
                    if let Some(p) = PEERS.lock().unwrap().get_mut(id) {
                        p.authorized = true;
                        p.since = now_secs();
                    }
                }
                "ok".to_owned()
            }
        }
        "reject" => {
            let ids: Vec<i32> = peers
                .iter()
                .filter(|(_, p)| !p.authorized)
                .map(|(id, _)| *id)
                .collect();
            if ids.is_empty() {
                "nothing".to_owned()
            } else {
                for id in ids.iter() {
                    ui_cm_interface::close(*id);
                }
                "ok".to_owned()
            }
        }
        "close" => {
            if peers.is_empty() {
                "nothing".to_owned()
            } else {
                for id in peers.keys() {
                    ui_cm_interface::close(*id);
                }
                "ok".to_owned()
            }
        }
        "new-password" => {
            password_security::update_temporary_password();
            "ok".to_owned()
        }
        _ => "unknown".to_owned(),
    };
    log::info!("gg cmd {} -> {}", cmd, res);
    write_state();
    res
}

/// 명령 파이프 서버 — SYSTEM과 관리자 권한 프로세스만 열 수 있다.
#[tokio::main(flavor = "current_thread")]
async fn start_cmd_server() {
    let mut endpoint = Endpoint::new(Config::ipc_path(CMD_POSTFIX));
    match SecurityAttributes::from_sddl(CMD_SDDL) {
        Ok(attr) => endpoint.set_security_attributes(attr),
        Err(e) => {
            // 보안 설정을 못 하면 통로를 열지 않는다(아무나 '허용'을 보내지 못하게)
            log::error!("gg cmd: security attributes failed, not listening: {}", e);
            return;
        }
    }
    let mut incoming = match endpoint.incoming() {
        Ok(incoming) => incoming,
        Err(e) => {
            log::error!("gg cmd: listen failed: {}", e);
            return;
        }
    };
    log::info!("gg cmd: listening");
    loop {
        match incoming.next().await {
            Some(Ok(stream)) => {
                tokio::spawn(async move {
                    let mut conn = ipc::Connection::new(stream);
                    if let Ok(Some(Data::Config((name, Some(cmd))))) = conn.next_timeout(3000).await
                    {
                        if name == CMD_NAME {
                            let res = handle_cmd(&cmd);
                            allow_err!(conn.send(&Data::Config((CMD_NAME.to_owned(), Some(res)))).await);
                        }
                    }
                });
            }
            Some(Err(e)) => {
                log::error!("gg cmd: accept failed: {}", e);
            }
            None => break,
        }
    }
}

/// `--gg-cmd <명령>` — 지킴이 모드 프로세스에 명령을 보내고 종료 코드로 결과를 알린다.
pub fn send_cmd(cmd: &str) -> i32 {
    match send_cmd_async(cmd) {
        Ok(res) => {
            println!("{}", res);
            if res == "ok" {
                0
            } else {
                1
            }
        }
        Err(e) => {
            println!("error: {}", e);
            2
        }
    }
}

#[tokio::main(flavor = "current_thread")]
async fn send_cmd_async(cmd: &str) -> ResultType<String> {
    let mut conn = ipc::connect(2000, CMD_POSTFIX).await?;
    conn.send(&Data::Config((CMD_NAME.to_owned(), Some(cmd.to_owned()))))
        .await?;
    match conn.next_timeout(3000).await? {
        Some(Data::Config((_, Some(res)))) => Ok(res),
        _ => bail!("no response"),
    }
}
