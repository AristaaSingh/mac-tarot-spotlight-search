import AppKit
import SwiftUI

// MARK: - Direct multi-line editor

// Shared NSTextView subclass used as both a direct editor and field editor.
// Draws a 1px cursor and respects insertionPointColor for per-window theming.
class AppTextView: NSTextView {

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Only grab focus when used as a direct editor; field editors are managed by AppKit.
        if !isFieldEditor { window?.makeFirstResponder(self) }
    }

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        guard flag else { return }
        color.setFill()
        NSRect(x: rect.minX, y: rect.minY, width: 1, height: rect.height).fill()
    }

    override func setNeedsDisplay(_ rect: NSRect, avoidAdditionalLayout flag: Bool) {
        super.setNeedsDisplay(rect, avoidAdditionalLayout: flag)
    }
}

// MARK: - Single-line themed text field

// NSTextField subclass that injects cursor color into the shared field editor
// when it becomes first responder. Works inside SwiftUI hosting views.
class CursorNSTextField: NSTextField {
    var cursorColor: NSColor = .textColor

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result, let tv = window?.fieldEditor(false, for: self) as? NSTextView {
            tv.insertionPointColor = cursorColor
        }
        return result
    }
}

// MARK: - SwiftUI wrapper

struct ThemedTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String      = ""
    var nsFont: NSFont           = .systemFont(ofSize: 14)
    var textColor: NSColor       = .labelColor
    var placeholderColor: NSColor? = nil  // defaults to textColor at 45% opacity
    var cursorColor: NSColor     = .textColor
    var isFocused: Bool          = false
    var onSubmit: (() -> Void)?  = nil
    var onEscape: (() -> Void)?  = nil

    func makeNSView(context: Context) -> CursorNSTextField {
        let field = CursorNSTextField()
        field.cursorColor     = cursorColor
        field.font            = nsFont
        field.textColor       = textColor
        field.isBordered      = false
        field.drawsBackground = false
        field.focusRingType   = .none
        field.delegate        = context.coordinator
        setPlaceholder(on: field)
        return field
    }

    private func setPlaceholder(on field: NSTextField) {
        let color = placeholderColor ?? textColor.withAlphaComponent(0.45)
        field.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: color, .font: nsFont]
        )
    }

    func updateNSView(_ field: CursorNSTextField, context: Context) {
        if field.stringValue != text { field.stringValue = text }
        field.cursorColor = cursorColor
        // Trigger focus when isFocused flips to true
        if isFocused && !context.coordinator.wasFocused {
            DispatchQueue.main.async { field.window?.makeFirstResponder(field) }
        }
        context.coordinator.wasFocused = isFocused
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: ThemedTextField
        var wasFocused = false
        init(_ p: ThemedTextField) { parent = p }

        func controlTextDidChange(_ obj: Notification) {
            guard let f = obj.object as? NSTextField else { return }
            parent.text = f.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool {
            if sel == #selector(NSResponder.insertNewline(_:))   { parent.onSubmit?(); return true }
            if sel == #selector(NSResponder.cancelOperation(_:)) { parent.onEscape?(); return true }
            return false
        }
    }
}
