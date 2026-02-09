import Testing
import AppKit
@testable import Murmurix

private final class MockHotkeyEventMonitorManager: HotkeyEventMonitorManaging {
    var localAddCallCount = 0
    var globalAddCallCount = 0
    var removeCallCount = 0
    var removedMonitors: [AnyHashable] = []

    private let localToken: AnyHashable = "local-monitor-token"
    private let globalToken: AnyHashable = "global-monitor-token"

    func addLocalKeyDownMonitor(handler: @escaping (NSEvent) -> NSEvent?) -> Any? {
        localAddCallCount += 1
        return localToken
    }

    func addGlobalKeyDownMonitor(handler: @escaping (NSEvent) -> Void) -> Any? {
        globalAddCallCount += 1
        return globalToken
    }

    func removeMonitor(_ monitor: Any) {
        removeCallCount += 1
        if let hashableMonitor = monitor as? AnyHashable {
            removedMonitors.append(hashableMonitor)
        }
    }
}

struct HotkeyCaptureServiceTests {
    @Test func startCapturingRegistersBothMonitors() {
        let monitorManager = MockHotkeyEventMonitorManager()
        let service = HotkeyCaptureService(monitorManager: monitorManager)

        service.startCapturing { _ in }

        #expect(service.isCapturing == true)
        #expect(monitorManager.localAddCallCount == 1)
        #expect(monitorManager.globalAddCallCount == 1)
        #expect(monitorManager.removeCallCount == 0)
    }

    @Test func stopCapturingRemovesRegisteredMonitors() {
        let monitorManager = MockHotkeyEventMonitorManager()
        let service = HotkeyCaptureService(monitorManager: monitorManager)

        service.startCapturing { _ in }
        service.stopCapturing()

        #expect(service.isCapturing == false)
        #expect(monitorManager.removeCallCount == 2)
        #expect(monitorManager.removedMonitors.contains("local-monitor-token"))
        #expect(monitorManager.removedMonitors.contains("global-monitor-token"))
    }

    @Test func startCapturingTwiceDoesNotDuplicateMonitors() {
        let monitorManager = MockHotkeyEventMonitorManager()
        let service = HotkeyCaptureService(monitorManager: monitorManager)

        service.startCapturing { _ in }
        service.startCapturing { _ in }

        #expect(monitorManager.localAddCallCount == 1)
        #expect(monitorManager.globalAddCallCount == 1)
    }

    @Test func stopCapturingWithoutActiveSessionDoesNothing() {
        let monitorManager = MockHotkeyEventMonitorManager()
        let service = HotkeyCaptureService(monitorManager: monitorManager)

        service.stopCapturing()

        #expect(service.isCapturing == false)
        #expect(monitorManager.removeCallCount == 0)
    }
}
