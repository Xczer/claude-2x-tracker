use chrono::{Datelike, Timelike, Utc, Offset};
use chrono_tz::Tz;
use serde::{Deserialize, Serialize};
use std::fs;
use tauri::{
    AppHandle, Emitter, Manager, Runtime,
    image::Image,
    menu::{Menu, MenuItem},
    tray::{MouseButtonState, TrayIconBuilder, TrayIconEvent},
};
use tauri_plugin_positioner::{Position, WindowExt};

// ── Config ────────────────────────────────────────────────────────────────────

#[derive(Debug, Deserialize)]
struct Config {
    timezone: String,
    active_days: Vec<String>,
    blocked_window: BlockedWindow,
    #[serde(default)]
    theme: Theme,
}

#[derive(Debug, Deserialize)]
struct BlockedWindow {
    start: String,
    end: String,
}

#[derive(Debug, Deserialize, Default)]
struct Theme {
    #[serde(default = "default_active_color")]
    active_color: String,
    #[serde(default = "default_blocked_color")]
    blocked_color: String,
    #[serde(default = "default_weekend_color")]
    weekend_color: String,
    #[serde(default = "default_accent")]
    accent: String,
}

fn default_active_color() -> String { "#22C55E".into() }
fn default_blocked_color() -> String { "#DC2626".into() }
fn default_weekend_color() -> String { "#6B7280".into() }
fn default_accent() -> String { "#C96442".into() }

fn load_config() -> Config {
    let candidates = vec![
        std::env::current_exe()
            .ok()
            .and_then(|p| p.parent().map(|d| d.join("../../../config.json")))
            .unwrap_or_default(),
        std::path::PathBuf::from("config.json"),
        std::path::PathBuf::from("../../config.json"),
    ];
    for path in &candidates {
        if let Ok(text) = fs::read_to_string(path) {
            let clean: String = text
                .lines()
                .filter(|l| !l.trim().starts_with("\"_comment\""))
                .collect::<Vec<_>>()
                .join("\n");
            if let Ok(cfg) = serde_json::from_str::<Config>(&clean) {
                return cfg;
            }
        }
    }
    Config {
        timezone: "America/New_York".into(),
        active_days: vec!["monday","tuesday","wednesday","thursday","friday"]
            .into_iter().map(String::from).collect(),
        blocked_window: BlockedWindow { start: "08:00".into(), end: "14:00".into() },
        theme: Theme::default(),
    }
}

fn parse_hhmm(s: &str) -> u32 {
    let parts: Vec<&str> = s.splitn(2, ':').collect();
    let h: u32 = parts.first().and_then(|v| v.parse().ok()).unwrap_or(0);
    let m: u32 = parts.get(1).and_then(|v| v.parse().ok()).unwrap_or(0);
    h * 60 + m
}

// ── Status ────────────────────────────────────────────────────────────────────

#[derive(Debug, Serialize, Clone, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum Status { Active, Blocked, Weekend }

#[derive(Debug, Serialize, Clone)]
pub struct StatusPayload {
    status: Status,
    label: String,
    sublabel: String,
    next_window: String,
    minutes_now: f64,
    block_start_min: u32,
    block_end_min: u32,
    calendar: Vec<CalendarDay>,
    theme: ThemePayload,
    et_time: String,
    elapsed_active_min: u32,
    remaining_active_min: u32,
    day_progress_pct: f64,
}

#[derive(Debug, Serialize, Clone)]
pub struct ThemePayload {
    active_color: String,
    blocked_color: String,
    weekend_color: String,
    accent: String,
}

#[derive(Debug, Serialize, Clone)]
pub struct CalendarDay {
    day_num: u32,
    day_name: String,
    is_weekend: bool,
    is_today: bool,
}

// ── Remote schedule cache ─────────────────────────────────────────────────────

use std::sync::Mutex;
use std::time::Instant;

struct CachedSchedule {
    et_block_start: u32,
    et_block_end: u32,
    fetched_at: Instant,
}

static SCHEDULE_CACHE: std::sync::LazyLock<Mutex<Option<CachedSchedule>>> =
    std::sync::LazyLock::new(|| Mutex::new(None));

const SCHEDULE_URL: &str = "https://raw.githubusercontent.com/Xczer/claude-2x/main/schedule.json";
const CACHE_DURATION_SECS: u64 = 6 * 3600; // 6 hours

/// Priority: remote schedule.json > local config.json > hardcoded default
fn get_schedule(cfg: &Config) -> (u32, u32) {
    let hardcoded = (8 * 60, 14 * 60); // 8 AM - 2 PM ET
    let from_config = (parse_hhmm(&cfg.blocked_window.start), parse_hhmm(&cfg.blocked_window.end));

    // Check cache first
    if let Ok(cache) = SCHEDULE_CACHE.lock() {
        if let Some(ref cached) = *cache {
            if cached.fetched_at.elapsed().as_secs() < CACHE_DURATION_SECS {
                return (cached.et_block_start, cached.et_block_end);
            }
        }
    }

    // Try remote fetch (blocking but rare — every 6h)
    let result = std::thread::spawn(|| {
        let agent = ureq::Agent::new_with_config(
            ureq::config::Config::builder()
                .timeout_global(Some(std::time::Duration::from_secs(5)))
                .build()
        );
        let body = agent.get(SCHEDULE_URL)
            .call()
            .ok()?
            .into_body()
            .read_to_string()
            .ok()?;
        let json: serde_json::Value = serde_json::from_str(&body).ok()?;
        let start = parse_hhmm(json.get("peak_start")?.as_str()?);
        let end = parse_hhmm(json.get("peak_end")?.as_str()?);
        Some((start, end))
    }).join().ok().flatten();

    if let Some((start, end)) = result {
        if let Ok(mut cache) = SCHEDULE_CACHE.lock() {
            *cache = Some(CachedSchedule {
                et_block_start: start,
                et_block_end: end,
                fetched_at: Instant::now(),
            });
        }
        return (start, end);
    }

    // Fallback 1: stale cache
    if let Ok(cache) = SCHEDULE_CACHE.lock() {
        if let Some(ref cached) = *cache {
            return (cached.et_block_start, cached.et_block_end);
        }
    }

    // Fallback 2: local config.json
    if from_config != hardcoded {
        return from_config;
    }

    // Fallback 3: hardcoded default
    hardcoded
}

fn compute_status(cfg: &Config) -> StatusPayload {
    // Use ET for the blocked window definition, local timezone for display + weekday
    let et: Tz = "America/New_York".parse().unwrap();
    let now_utc = chrono::Utc::now();
    let now_et = now_utc.with_timezone(&et);
    let now_local = chrono::Local::now();

    // Weekday check uses LOCAL timezone (Monday is Monday for the user)
    let weekday_str = match now_local.weekday() {
        chrono::Weekday::Mon => "monday", chrono::Weekday::Tue => "tuesday",
        chrono::Weekday::Wed => "wednesday", chrono::Weekday::Thu => "thursday",
        chrono::Weekday::Fri => "friday", chrono::Weekday::Sat => "saturday",
        chrono::Weekday::Sun => "sunday",
    };
    let is_active_day = cfg.active_days.iter().any(|d| d.as_str() == weekday_str);

    // Priority: remote schedule > local config.json > hardcoded default
    let (remote_start, remote_end) = get_schedule(cfg);
    let et_block_start = remote_start as i32;
    let et_block_end   = remote_end as i32;
    let et_offset_sec  = now_et.offset().fix().utc_minus_local() * -1;
    let local_offset_sec = now_local.offset().local_minus_utc();
    let diff_min = (local_offset_sec - et_offset_sec) / 60;

    let block_start = ((et_block_start + diff_min + 1440) % 1440) as u32;
    let block_end   = ((et_block_end + diff_min + 1440) % 1440) as u32;

    // Use local time for display
    let minutes_now = (now_local.hour() * 60 + now_local.minute()) as f64 + now_local.second() as f64 / 60.0;

    let status = if !is_active_day {
        Status::Weekend
    } else if minutes_now >= block_start as f64 && minutes_now < block_end as f64 {
        Status::Blocked
    } else {
        Status::Active
    };

    let (label, sublabel) = match &status {
        Status::Active  => ("2× ACTIVE".into(), "smash those prompts".into()),
        Status::Blocked => ("BLOCKED".into(),    "standard limits".into()),
        Status::Weekend => ("WEEKEND".into(),    "enjoy the weekend".into()),
    };

    let next_window = compute_next_window(minutes_now as u32, block_start, block_end, is_active_day, weekday_str);

    // Local time string (HH:MM)
    let et_time = format!("{:02}:{:02}", now_local.hour(), now_local.minute());

    // Daily active progress: total active = 1440 - (block_end - block_start)
    let total_active = 1440 - (block_end - block_start);
    let now_min = minutes_now as u32;
    let (elapsed_active_min, remaining_active_min) = if !is_active_day {
        (0, 0)
    } else if now_min < block_start {
        // Before blocked window: elapsed = now_min, remaining = (block_start - now_min) + (1440 - block_end)
        (now_min, total_active - now_min)
    } else if now_min < block_end {
        // In blocked window: elapsed = block_start, remaining = 1440 - block_end
        (block_start, 1440 - block_end)
    } else {
        // After blocked window: elapsed = block_start + (now_min - block_end), remaining = 1440 - now_min
        (block_start + (now_min - block_end), 1440 - now_min)
    };
    let day_progress_pct = if total_active > 0 {
        (elapsed_active_min as f64 / total_active as f64 * 100.0).min(100.0)
    } else {
        0.0
    };

    let calendar = (0i64..8).map(|offset| {
        let day = now_local.date_naive() + chrono::Duration::days(offset);
        let wd  = day.weekday();
        let is_weekend = matches!(wd, chrono::Weekday::Sat | chrono::Weekday::Sun);
        let day_name = match wd {
            chrono::Weekday::Mon => "Mon", chrono::Weekday::Tue => "Tue",
            chrono::Weekday::Wed => "Wed", chrono::Weekday::Thu => "Thu",
            chrono::Weekday::Fri => "Fri", chrono::Weekday::Sat => "Sat",
            chrono::Weekday::Sun => "Sun",
        };
        CalendarDay { day_num: day.day(), day_name: day_name.into(), is_weekend, is_today: offset == 0 }
    }).collect();

    StatusPayload {
        status, label, sublabel, next_window,
        minutes_now, block_start_min: block_start, block_end_min: block_end,
        calendar,
        theme: ThemePayload {
            active_color:  cfg.theme.active_color.clone(),
            blocked_color: cfg.theme.blocked_color.clone(),
            weekend_color: cfg.theme.weekend_color.clone(),
            accent:        cfg.theme.accent.clone(),
        },
        et_time,
        elapsed_active_min,
        remaining_active_min,
        day_progress_pct,
    }
}

fn compute_next_window(now_min: u32, block_start: u32, block_end: u32, is_active_day: bool, weekday_str: &str) -> String {
    if !is_active_day {
        // Weekend: time until Monday 00:00 LOCAL
        let to_midnight = 1440 - now_min;
        let total = if weekday_str == "saturday" {
            to_midnight + 1440
        } else {
            to_midnight
        };
        let h = total / 60;
        let m = total % 60;
        return if h > 0 { format!("Next 2\u{00d7} in {}h {:02}m", h, m) } else { format!("Next 2\u{00d7} in {}m", m) };
    }

    if block_start < block_end {
        // Normal case (doesn't cross midnight)
        let (rem, prefix) = if now_min < block_start {
            (block_start - now_min, "Active for")
        } else if now_min < block_end {
            (block_end - now_min, "Next 2\u{00d7} in")
        } else {
            let to_midnight = 1440 - now_min;
            if weekday_str == "friday" {
                (to_midnight, "Active for")
            } else {
                (to_midnight + block_start, "Active for")
            }
        };
        let h = rem / 60;
        let m = rem % 60;
        if h > 0 { format!("{} {}h {:02}m", prefix, h, m) } else { format!("{} {}m", prefix, m) }
    } else {
        // Crosses midnight (far-east timezones)
        let (rem, prefix) = if now_min >= block_end && now_min < block_start {
            (block_start - now_min, "Active for")
        } else if now_min >= block_start {
            ((1440 - now_min) + block_end, "Next 2\u{00d7} in")
        } else {
            (block_end - now_min, "Next 2\u{00d7} in")
        };
        let h = rem / 60;
        let m = rem % 60;
        if h > 0 { format!("{} {}h {:02}m", prefix, h, m) } else { format!("{} {}m", prefix, m) }
    }
}

// ── Tauri commands ────────────────────────────────────────────────────────────

#[tauri::command]
fn get_status() -> StatusPayload {
    compute_status(&load_config())
}

/// Called from JS when clicking outside the popup.
#[tauri::command]
fn hide_window(window: tauri::WebviewWindow) {
    let _ = window.hide();
}

// ── Window toggle ─────────────────────────────────────────────────────────────

fn toggle_window<R: Runtime>(app: &AppHandle<R>) {
    if let Some(win) = app.get_webview_window("main") {
        if win.is_visible().unwrap_or(false) {
            let _ = win.hide();
        } else {
            // Emit BEFORE show so JS sets justShown before any blur fires
            let _ = win.emit("popup-shown", ());
            let _ = win.move_window(Position::TrayBottomCenter);
            let _ = win.show();
            let _ = win.set_focus();
        }
    }
}

// ── App setup ─────────────────────────────────────────────────────────────────

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_positioner::init())
        .setup(|app| {
            #[cfg(target_os = "macos")]
            app.set_activation_policy(tauri::ActivationPolicy::Accessory);

            // Force full transparency on the window + webview.
            if let Some(win) = app.get_webview_window("main") {
                use tauri::window::Color;
                let _ = win.set_background_color(Some(Color(0, 0, 0, 0)));

                #[cfg(target_os = "macos")]
                {
                    let _ = win.with_webview(|wv| unsafe {
                        let webview: *mut objc2::runtime::AnyObject = wv.inner().cast();
                        // Disable WKWebView drawing its own background
                        let no = objc2::runtime::Bool::NO;
                        let _: () = objc2::msg_send![webview, _setDrawsBackground: no];

                        // Walk up to the NSWindow and clear its background
                        let nswindow: *mut objc2::runtime::AnyObject = objc2::msg_send![webview, window];
                        if !nswindow.is_null() {
                            let clear: *mut objc2::runtime::AnyObject = objc2::msg_send![
                                objc2::class!(NSColor), clearColor
                            ];
                            let _: () = objc2::msg_send![nswindow, setBackgroundColor: clear];
                            let _: () = objc2::msg_send![nswindow, setOpaque: no];
                            let _: () = objc2::msg_send![nswindow, setHasShadow: no];

                            // Round the window's contentView layer to match CSS border-radius
                            let content_view: *mut objc2::runtime::AnyObject =
                                objc2::msg_send![nswindow, contentView];
                            if !content_view.is_null() {
                                let _: () = objc2::msg_send![content_view, setWantsLayer: objc2::runtime::Bool::YES];
                                let layer: *mut objc2::runtime::AnyObject =
                                    objc2::msg_send![content_view, layer];
                                if !layer.is_null() {
                                    let _: () = objc2::msg_send![layer, setCornerRadius: 22.0_f64];
                                    let _: () = objc2::msg_send![layer, setMasksToBounds: objc2::runtime::Bool::YES];
                                    // Clear the layer's background color too
                                    let cg_clear: *mut objc2::runtime::AnyObject = std::ptr::null_mut();
                                    let _: () = objc2::msg_send![layer, setBackgroundColor: cg_clear];
                                }
                            }
                        }
                    });
                }
            }

            // Tray icon: white "2X" on transparent (macOS template image).
            let tray_icon_bytes = include_bytes!("../icons/tray-icon.png");
            let tray_icon = Image::from_bytes(tray_icon_bytes)
                .expect("failed to decode tray-icon.png");

            // Right-click menu with Quit
            let quit = MenuItem::with_id(app, "quit", "Quit TwoX", true, None::<&str>)?;
            let menu = Menu::with_items(app, &[&quit])?;

            let handle = app.handle().clone();
            TrayIconBuilder::with_id("main")
                .icon(tray_icon)
                .icon_as_template(true)
                .menu(&menu)
                .show_menu_on_left_click(false)
                .on_menu_event(|app, event| {
                    if event.id().as_ref() == "quit" {
                        app.exit(0);
                    }
                })
                .on_tray_icon_event(move |_tray, event| {
                    tauri_plugin_positioner::on_tray_event(&handle, &event);
                    // Only toggle on mouse-UP — Click fires for both press and release
                    if let TrayIconEvent::Click { button_state: MouseButtonState::Up, .. } = event {
                        toggle_window(&handle);
                    }
                })
                .build(app)?;

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![get_status, hide_window])
        .run(tauri::generate_context!())
        .expect("error while running TwoX");
}
