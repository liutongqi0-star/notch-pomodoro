import CoreGraphics
import Foundation

// 调试辅助：列出指定进程的窗口编号和位置
guard CommandLine.arguments.count > 1, let pid = Int32(CommandLine.arguments[1]) else {
    FileHandle.standardError.write(Data("usage: windowid <pid>\n".utf8))
    exit(1)
}

let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []

for info in list {
    guard let ownerPID = info[kCGWindowOwnerPID as String] as? Int32, ownerPID == pid else { continue }
    let number = info[kCGWindowNumber as String] as? Int ?? 0
    let bounds = info[kCGWindowBounds as String] ?? [:]
    print("\(number)\t\(bounds)")
}
