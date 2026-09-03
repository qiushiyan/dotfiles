import AppKit
import Foundation

func fail(_ message: String) -> Never {
  fputs("macos-terminal-profile: \(message)\n", stderr)
  exit(1)
}

var options: [String: String] = [:]
var index = 1
while index < CommandLine.arguments.count {
  let key = CommandLine.arguments[index]
  guard key.hasPrefix("--"), index + 1 < CommandLine.arguments.count else {
    fail("usage: swift macos-terminal-profile.swift --ghostty FILE --name NAME --bold HEX --output FILE [--template NAME]")
  }
  options[key] = CommandLine.arguments[index + 1]
  index += 2
}

guard let ghosttyPath = options["--ghostty"],
      let profileName = options["--name"],
      let boldHex = options["--bold"],
      let outputPath = options["--output"] else {
  fail("usage: swift macos-terminal-profile.swift --ghostty FILE --name NAME --bold HEX --output FILE [--template NAME]")
}

func normalizedHex(_ raw: String, label: String) -> String {
  let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
  guard value.range(of: "^[0-9A-Fa-f]{6}$", options: .regularExpression) != nil else {
    fail("\(label) is not a six-digit RGB color: \(raw)")
  }
  return value
}

let source: String
do {
  source = try String(contentsOfFile: ghosttyPath, encoding: .utf8)
} catch {
  fail("cannot read Ghostty theme \(ghosttyPath): \(error)")
}

var fields: [String: String] = [:]
var ansi: [Int: String] = [:]
for rawLine in source.split(separator: "\n") {
  let line = String(rawLine).trimmingCharacters(in: .whitespaces)
  if line.isEmpty || line.hasPrefix("#") { continue }

  let parts = line.split(separator: "=", maxSplits: 2).map {
    String($0).trimmingCharacters(in: .whitespaces)
  }
  if parts.count == 3, parts[0] == "palette", let slot = Int(parts[1]) {
    ansi[slot] = normalizedHex(parts[2], label: "palette \(slot)")
  } else if parts.count >= 2,
            ["background", "foreground", "cursor-color", "selection-background"].contains(parts[0]) {
    fields[parts[0]] = normalizedHex(parts[1], label: parts[0])
  }
}

for slot in 0...15 where ansi[slot] == nil {
  fail("Ghostty theme has no palette slot \(slot)")
}
for field in ["background", "foreground", "selection-background"] where fields[field] == nil {
  fail("Ghostty theme has no \(field)")
}

guard let domain = UserDefaults.standard.persistentDomain(forName: "com.apple.Terminal"),
      let windowSettings = domain["Window Settings"] as? [String: Any] else {
  fail("cannot read Terminal.app profiles")
}
let templateName = options["--template"]
  ?? (domain["Default Window Settings"] as? String)
  ?? "Basic"
guard var profile = windowSettings[templateName] as? [String: Any] else {
  fail("Terminal.app profile not found: \(templateName)")
}

func archivedColor(_ raw: String, label: String) -> Data {
  let hex = normalizedHex(raw, label: label)
  let rgb = UInt32(hex, radix: 16)!
  // NSCalibratedRGBColorSpace is Terminal.app's compact native representation.
  // NSColor(srgbRed:...) embeds an ICC profile in every field (~3.6 KB/color).
  let color = NSColor(
    calibratedRed: CGFloat((rgb >> 16) & 0xff) / 255,
    green: CGFloat((rgb >> 8) & 0xff) / 255,
    blue: CGFloat(rgb & 0xff) / 255,
    alpha: 1
  )
  do {
    return try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false)
  } catch {
    fail("cannot archive \(label): \(error)")
  }
}

let terminalKeys = [
  "ANSIBlackColor", "ANSIRedColor", "ANSIGreenColor", "ANSIYellowColor",
  "ANSIBlueColor", "ANSIMagentaColor", "ANSICyanColor", "ANSIWhiteColor",
  "ANSIBrightBlackColor", "ANSIBrightRedColor", "ANSIBrightGreenColor",
  "ANSIBrightYellowColor", "ANSIBrightBlueColor", "ANSIBrightMagentaColor",
  "ANSIBrightCyanColor", "ANSIBrightWhiteColor",
]
for (slot, key) in terminalKeys.enumerated() {
  profile[key] = archivedColor(ansi[slot]!, label: "palette \(slot)")
}
profile["BackgroundColor"] = archivedColor(fields["background"]!, label: "background")
profile["TextColor"] = archivedColor(fields["foreground"]!, label: "foreground")
profile["TextBoldColor"] = archivedColor(boldHex, label: "bold")
profile["CursorColor"] = archivedColor(fields["cursor-color"] ?? fields["foreground"]!, label: "cursor")
profile["SelectionColor"] = archivedColor(fields["selection-background"]!, label: "selection")
profile["UseBrightBold"] = false
profile["name"] = profileName
profile["type"] = "Window Settings"

let outputURL = URL(fileURLWithPath: outputPath)
do {
  let data = try PropertyListSerialization.data(fromPropertyList: profile, format: .xml, options: 0)
  try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  try data.write(to: outputURL, options: .atomic)
  print("wrote \(outputPath) from \(ghosttyPath) (template: \(templateName))")
} catch {
  fail("cannot write \(outputPath): \(error)")
}
