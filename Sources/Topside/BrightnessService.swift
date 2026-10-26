import CoreGraphics
import Darwin
import Foundation

/// Reads and sets the built-in display brightness.
///
/// macOS has no public API for this on Apple Silicon, so this loads Apple's private
/// DisplayServices framework at runtime. If a future macOS update changes it, the
/// brightness slider simply stops working; nothing else in the app is affected.
final class BrightnessService {
    private typealias GetBrightness = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (UInt32, Float) -> Int32

    private var getFunction: GetBrightness?
    private var setFunction: SetBrightness?
    private let displayID: CGDirectDisplayID

    init() {
        displayID = BrightnessService.builtInDisplay() ?? CGMainDisplayID()

        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        guard let handle = dlopen(path, RTLD_LAZY) else { return }
        if let symbol = dlsym(handle, "DisplayServicesGetBrightness") {
            getFunction = unsafeBitCast(symbol, to: GetBrightness.self)
        }
        if let symbol = dlsym(handle, "DisplayServicesSetBrightness") {
            setFunction = unsafeBitCast(symbol, to: SetBrightness.self)
        }
    }

    func read() -> Float? {
        guard let getFunction else { return nil }
        var value: Float = 0
        return getFunction(displayID, &value) == 0 ? value : nil
    }

    func write(_ newValue: Float) {
        guard let setFunction else { return }
        _ = setFunction(displayID, max(0, min(1, newValue)))
    }

    private static func builtInDisplay() -> CGDirectDisplayID? {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(16, &ids, &count) == .success else { return nil }
        return ids.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }
}
