import Foundation

func runCommand(_ path: String, args: [String]) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = args
    try? process.run()
    process.waitUntilExit()
}
