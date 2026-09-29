// A cross-process race check for QuickControlsStore, run on macOS.
//
// Several "tapper" processes record taps while one "drainer" process drains
// in a loop, all against one UserDefaults suite through cfprefsd — the same
// daemon that brokers App Group defaults on iOS. Every tap must be drained
// exactly once. Run via tool/store_race_check.sh; it is not part of
// `flutter test` because it needs swiftc and spawns processes.
//
// What it cannot show: iOS-specific cfprefsd behaviour, App Group
// containers, or a suspended extension. It checks the key-per-event argument
// under real cross-process defaults, nothing more.

import Foundation

let args = CommandLine.arguments
let suite = args[2]
guard let store = QuickControlsStore(appGroupId: suite) else { fatalError("no suite") }

switch args[1] {
case "tap":
    for _ in 0..<Int(args[3])! { store.recordTap(on: "rows", kind: .counter) }
case "drain":
    // Drain until the stop file appears, then once more for stragglers.
    let stop = args[3]
    var ids: [String] = []
    var batches = 0  // Non-empty drains while tappers ran: proof they overlapped.
    while !FileManager.default.fileExists(atPath: stop) {
        let batch = store.drain().map(\.id)
        if !batch.isEmpty { batches += 1 }
        ids += batch
    }
    Thread.sleep(forTimeInterval: 0.5)
    ids += store.drain().map(\.id)
    print("drained=\(ids.count) unique=\(Set(ids).count) concurrent_batches=\(batches)")
case "clear":
    UserDefaults.standard.removePersistentDomain(forName: suite)
default:
    fatalError("usage: tap|drain|clear <suite> ...")
}
