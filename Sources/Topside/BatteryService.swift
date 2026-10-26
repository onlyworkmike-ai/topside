import Foundation
import IOKit.ps

/// Battery level and charger state, with a callback when the power source changes.
final class BatteryService {
    var onChange: (() -> Void)?
    private var runLoopSource: CFRunLoopSource?

    func start() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { rawContext in
            guard let rawContext else { return }
            let service = Unmanaged<BatteryService>.fromOpaque(rawContext).takeUnretainedValue()
            DispatchQueue.main.async { service.onChange?() }
        }
        let source = IOPSNotificationCreateRunLoopSource(callback, context).takeRetainedValue()
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    func read() -> BatteryInfo? {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        guard let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)
                .takeUnretainedValue() as? [String: Any] else { continue }
            guard (description[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }

            let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maximum = description[kIOPSMaxCapacityKey] as? Int ?? 100
            let charging = description[kIOPSIsChargingKey] as? Bool ?? false
            let state = description[kIOPSPowerSourceStateKey] as? String

            let percent = maximum > 0
                ? Int((Double(current) / Double(maximum) * 100).rounded())
                : current

            return BatteryInfo(
                percent: min(100, max(0, percent)),
                isCharging: charging,
                isPluggedIn: state == kIOPSACPowerValue
            )
        }
        return nil
    }
}
