// sketchybar-notifications: LaunchAgent that mirrors the notifications
// currently in Notification Center into ~/.cache/sketchybar/notifications.tsv
// (mode 600), newest first, one per line:
//   bundle_id<TAB>delivered_epoch<TAB>title<TAB>subtitle<TAB>body
// and triggers `notifications_update` in SketchyBar when it changes.
//
// Source: the usernoted database
//   ~/Library/Group Containers/group.com.apple.usernoted/db2/db
// which is protected by Full Disk Access. Grant FDA to this binary only
// (~/.local/bin/sketchybar-notifications), not to sketchybar. The DB is opened
// read-only; nothing is ever written to it.
//
// Status (ok | no-access | schema: <error>) goes to
// ~/.cache/sketchybar/notifications_status.
import Foundation
import SQLite3

let home = FileManager.default.homeDirectoryForCurrentUser
let dbDir = home.appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db2")
let dbPath = dbDir.appendingPathComponent("db").path
let cacheDir = home.appendingPathComponent(".cache/sketchybar")
let outFile = cacheDir.appendingPathComponent("notifications.tsv")
let statusFile = cacheDir.appendingPathComponent("notifications_status")
let macEpoch = 978_307_200.0  // 2001-01-01 in Unix time

func writePrivate(_ text: String, to url: URL) {
    let fm = FileManager.default
    let tmp = url.appendingPathExtension("tmp")
    fm.createFile(atPath: tmp.path, contents: text.data(using: .utf8),
                  attributes: [.posixPermissions: 0o600])
    _ = try? fm.replaceItemAt(url, withItemAt: tmp)
}

func setStatus(_ s: String) {
    if (try? String(contentsOf: statusFile, encoding: .utf8)) != s { writePrivate(s, to: statusFile) }
}

func trigger() {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/sketchybar")
    p.arguments = ["--trigger", "notifications_update"]
    p.standardOutput = FileHandle.nullDevice
    p.standardError = FileHandle.nullDevice
    try? p.run()
}

func clean(_ s: String?) -> String {
    (s ?? "").replacingOccurrences(of: "\t", with: " ")
        .replacingOccurrences(of: "\r", with: " ")
        .replacingOccurrences(of: "\n", with: " ")
        .trimmingCharacters(in: .whitespaces)
}

// The record blob is a binary plist; title/subtitle/body live under "req" as
// titl/subt/body. Search recursively so small layout changes don't break it.
func find(_ key: String, in obj: Any) -> String? {
    if let d = obj as? [String: Any] {
        if let v = d[key] as? String { return v }
        for v in d.values { if let r = find(key, in: v) { return r } }
    } else if let a = obj as? [Any] {
        for v in a { if let r = find(key, in: v) { return r } }
    }
    return nil
}

var last: String?

func refresh() {
    guard FileManager.default.isReadableFile(atPath: dbPath) else {
        setStatus("no-access"); return
    }
    var db: OpaquePointer?
    guard sqlite3_open_v2("file:\(dbPath)?mode=ro", &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else {
        setStatus("no-access"); sqlite3_close(db); return
    }
    defer { sqlite3_close(db) }
    let sql = """
        SELECT a.identifier, r.delivered_date, r.data
        FROM record r JOIN app a ON a.app_id = r.app_id
        ORDER BY r.delivered_date DESC LIMIT 300
        """
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
        setStatus("schema: \(String(cString: sqlite3_errmsg(db)))"); return
    }
    defer { sqlite3_finalize(stmt) }

    var lines: [String] = []
    while sqlite3_step(stmt) == SQLITE_ROW {
        let bundle = sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? ""
        let date = Int(sqlite3_column_double(stmt, 1) + macEpoch)
        var title = "", subtitle = "", body = ""
        if let bytes = sqlite3_column_blob(stmt, 2) {
            let data = Data(bytes: bytes, count: Int(sqlite3_column_bytes(stmt, 2)))
            if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) {
                title = clean(find("titl", in: plist))
                subtitle = clean(find("subt", in: plist))
                body = clean(find("body", in: plist))
            }
        }
        guard !bundle.isEmpty, !(title.isEmpty && body.isEmpty) else { continue }
        lines.append([bundle.lowercased(), String(date), title, subtitle, body].joined(separator: "\t"))
    }
    setStatus("ok")
    let text = lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n")
    guard text != last else { return }
    last = text
    writePrivate(text, to: outFile)
    trigger()
}

try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

// usernoted writes through its WAL; checking the mtimes is essentially free,
// so poll them and only re-read the database when they change.
func stamp() -> String {
    ["db", "db-wal"].map {
        let p = dbDir.appendingPathComponent($0).path
        let d = (try? FileManager.default.attributesOfItem(atPath: p)[.modificationDate]) as? Date
        return String(d?.timeIntervalSince1970 ?? 0)
    }.joined(separator: "/")
}

var lastStamp = ""
let interval = Double(CommandLine.arguments.dropFirst().first ?? "") ?? 3
refresh()
Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
    let s = stamp()
    if s != lastStamp || s == "0.0/0.0" { lastStamp = s; refresh() }
}
// Full refresh every 10 minutes regardless (also re-announces to sketchybar).
Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { _ in last = nil; refresh() }
RunLoop.main.run()
