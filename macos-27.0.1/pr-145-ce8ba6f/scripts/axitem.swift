// axitem PID: prints the Accessibility tree of the app's status item
// (its extras menu bar), with role, title, description and value.
import ApplicationServices
import Foundation
let pid = pid_t(CommandLine.arguments[1])!
let app = AXUIElementCreateApplication(pid)
func attr(_ e: AXUIElement, _ name: String) -> AnyObject? {
    var v: AnyObject?
    return AXUIElementCopyAttributeValue(e, name as CFString, &v) == .success ? v : nil
}
func str(_ e: AXUIElement, _ name: String) -> String {
    guard let v = attr(e, name) else { return "" }
    return "\(v)"
}
func walk(_ e: AXUIElement, _ d: Int) {
    print(String(repeating: "  ", count: d) + [kAXRoleAttribute, kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute, kAXHelpAttribute].map { str(e, $0) }.joined(separator: " | "))
    if d > 10 { return }
    for c in (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { walk(c, d + 1) }
}
print("trusted:", AXIsProcessTrusted())
if CommandLine.arguments.count > 2 { print("set:", AXUIElementSetAttributeValue(app, CommandLine.arguments[2] as CFString, kCFBooleanTrue).rawValue); usleep(500_000) }
if let bar = attr(app, "AXExtrasMenuBar") { walk(bar as! AXUIElement, 0) } else { print("no AXExtrasMenuBar") }
