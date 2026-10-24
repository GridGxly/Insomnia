// dispasleep: prints "asleep" when every online display is asleep, else "awake".
import CoreGraphics
var ids = [CGDirectDisplayID](repeating: 0, count: 16)
var count: UInt32 = 0
_ = CGGetOnlineDisplayList(16, &ids, &count)
let asleep = count > 0 && ids.prefix(Int(count)).allSatisfy { CGDisplayIsAsleep($0) != 0 }
print(asleep ? "asleep" : "awake", "(\(count) display(s))")
