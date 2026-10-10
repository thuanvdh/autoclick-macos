import AppKit
import CoreGraphics

enum MouseButton: String, Codable {
    case left, right
}

enum ClickType: String, Codable, CaseIterable, Identifiable {
    case left, right, double
    var id: Self { self }

    var title: String {
        switch self {
        case .left: "Trái"
        case .right: "Phải"
        case .double: "Double"
        }
    }
}

/// Gửi sự kiện chuột giả lập qua CoreGraphics. Toạ độ dùng hệ CG (gốc ở góc trên-trái màn hình chính).
enum Clicker {
    private static let source = CGEventSource(stateID: .hidSystemState)

    static var cursorLocation: CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    /// Dừng khẩn cấp khi con trỏ nằm ở góc trên-trái màn hình chính.
    static func isInStopCorner() -> Bool {
        let p = cursorLocation
        return p.x <= 2 && p.y <= 2
    }

    static func perform(_ type: ClickType, at point: CGPoint) {
        switch type {
        case .left:
            click(.left, at: point)
        case .right:
            click(.right, at: point)
        case .double:
            click(.left, at: point, clickState: 1)
            click(.left, at: point, clickState: 2)
        }
    }

    static func click(_ button: MouseButton, at point: CGPoint, clickState: Int64 = 1) {
        let down: CGEventType = button == .left ? .leftMouseDown : .rightMouseDown
        let up: CGEventType = button == .left ? .leftMouseUp : .rightMouseUp
        let cgButton: CGMouseButton = button == .left ? .left : .right

        for type in [down, up] {
            guard let event = CGEvent(mouseEventSource: source, mouseType: type,
                                      mouseCursorPosition: point, mouseButton: cgButton) else { continue }
            event.setIntegerValueField(.mouseEventClickState, value: clickState)
            event.post(tap: .cghidEventTap)
        }
    }
}
