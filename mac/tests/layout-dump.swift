// Prints what each key of the ANSI keyboard types (plain and with Shift) in
// the installed Hebrew and English keyboard layouts. Read-only: it uses the
// layout data macOS ships, and enables or changes nothing.
// Run: swift mac/tests/layout-dump.swift
import Carbon
import Foundation

// Physical keys in the order of the tables in mac/hafuch-safa/core.lua.
let keys: [(String, UInt16)] = [
    ("`", 50), ("1", 18), ("2", 19), ("3", 20), ("4", 21), ("5", 23), ("6", 22), ("7", 26),
    ("8", 28), ("9", 25), ("0", 29), ("-", 27), ("=", 24),
    ("q", 12), ("w", 13), ("e", 14), ("r", 15), ("t", 17), ("y", 16), ("u", 32), ("i", 34),
    ("o", 31), ("p", 35), ("[", 33), ("]", 30), ("\\", 42),
    ("a", 0), ("s", 1), ("d", 2), ("f", 3), ("g", 5), ("h", 4), ("j", 38), ("k", 40),
    ("l", 37), (";", 41), ("'", 39),
    ("z", 6), ("x", 7), ("c", 8), ("v", 9), ("b", 11), ("n", 45), ("m", 46), (",", 43),
    (".", 47), ("/", 44),
]

func translate(_ layout: UnsafePointer<UCKeyboardLayout>, _ code: UInt16, shift: Bool) -> String {
    var dead: UInt32 = 0
    var chars = [UniChar](repeating: 0, count: 4)
    var len = 0
    let mods: UInt32 = shift ? UInt32(shiftKey >> 8) & 0xFF : 0
    let status = UCKeyTranslate(layout, code, UInt16(kUCKeyActionDown), mods, UInt32(LMGetKbdType()),
                                OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, 4, &len, &chars)
    return status == noErr ? String(utf16CodeUnits: chars, count: len) : "?"
}

let filter = [kTISPropertyInputSourceType as String: kTISTypeKeyboardLayout as String] as CFDictionary
let sources = TISCreateInputSourceList(filter, true).takeRetainedValue() as! [TISInputSource]
let args = CommandLine.arguments.dropFirst().filter { $0 != "--detail" }
let wanted = !args.isEmpty ? Array(args)
    : ["com.apple.keylayout.ABC", "com.apple.keylayout.US", "com.apple.keylayout.Hebrew",
       "com.apple.keylayout.Hebrew-PC", "com.apple.keylayout.Hebrew-QWERTY"]
for source in sources {
    guard let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { continue }
    let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
    guard wanted.contains(id), let dataPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { continue }
    let data = Unmanaged<CFData>.fromOpaque(dataPtr).takeUnretainedValue()
    let enabledPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsEnabled)
    let enabled = enabledPtr.map { CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque($0).takeUnretainedValue()) } ?? false
    let layout = UnsafeRawPointer(CFDataGetBytePtr(data)!).assumingMemoryBound(to: UCKeyboardLayout.self)
    if CommandLine.arguments.contains("--detail") {
        print(id)
        for k in keys {
            let p = translate(layout, k.1, shift: false), s = translate(layout, k.1, shift: true)
            let hex = { (t: String) in t.unicodeScalars.map { String(format: "%04X", $0.value) }.joined(separator: "+") }
            print("  \(k.0)  plain=\(p) [\(hex(p))]  shift=\(s) [\(hex(s))]")
        }
        continue
    }
    let plain = keys.map { translate(layout, $0.1, shift: false) }.joined()
    let shifted = keys.map { translate(layout, $0.1, shift: true) }.joined()
    print("\(id) enabled=\(enabled)")
    print("  plain:   \(plain)")
    print("  shifted: \(shifted)")
}
