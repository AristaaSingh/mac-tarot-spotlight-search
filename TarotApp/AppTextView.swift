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
    var onTab:    (() -> Void)?  = nil

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
            if sel == #selector(NSResponder.insertTab(_:))       { parent.onTab?(); return true }
            return false
        }
    }
}

// MARK: - Auto-growing multi-line editor (no scroll view)

// Reports its natural height to SwiftUI via a Binding so the parent
// can size it with .frame(height:). Grows as the user types.
struct GrowingTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    var minHeight:     CGFloat  = 24
    var exclusionRect: CGRect   = .zero   // text wraps around this rect (e.g. a card image)
    var nsFont:        NSFont   = .systemFont(ofSize: 14)
    var textColor:     NSColor  = .labelColor
    var cursorColor:   NSColor  = .textColor

    func makeNSView(context: Context) -> AppTextView {
        let tv = AppTextView()
        tv.isFieldEditor = false
        tv.font = nsFont
        tv.textColor = textColor
        tv.insertionPointColor = cursorColor
        tv.drawsBackground = false
        tv.backgroundColor = .clear
        tv.isRichText = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.textContainerInset = .zero
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                                  height: CGFloat.greatestFiniteMagnitude)
        tv.autoresizingMask = [.width]
        if !exclusionRect.isEmpty {
            tv.textContainer?.exclusionPaths = [NSBezierPath(rect: exclusionRect)]
        }
        tv.delegate = context.coordinator
        tv.string = text
        return tv
    }

    func updateNSView(_ tv: AppTextView, context: Context) {
        if tv.string != text { tv.string = text }
        tv.font = nsFont
        tv.textColor = textColor
        tv.insertionPointColor = cursorColor
        let paths: [NSBezierPath] = exclusionRect.isEmpty ? [] : [NSBezierPath(rect: exclusionRect)]
        if tv.textContainer?.exclusionPaths.count != paths.count {
            tv.textContainer?.exclusionPaths = paths
        }
        recalc(tv)
    }

    private func recalc(_ tv: AppTextView) {
        guard let lm = tv.layoutManager, let tc = tv.textContainer else { return }
        lm.ensureLayout(for: tc)
        let natural = lm.usedRect(for: tc).height + tv.textContainerInset.height * 2
        let newH = max(natural, minHeight)
        let heightBinding = $height
        let current = height
        if abs(newH - current) > 0.5 {
            DispatchQueue.main.async { heightBinding.wrappedValue = newH }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: GrowingTextEditor
        init(_ p: GrowingTextEditor) { parent = p }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? AppTextView else { return }
            parent.text = tv.string
            parent.recalc(tv)
        }
    }
}

// MARK: - Multi-line themed text editor

struct ThemedTextEditor: NSViewRepresentable {
    @Binding var text: String
    var nsFont: NSFont       = .systemFont(ofSize: 14)
    var textColor: NSColor   = .labelColor
    var cursorColor: NSColor = .textColor

    func makeNSView(context: Context) -> NSScrollView {
        let tv = AppTextView()
        tv.isFieldEditor = false
        tv.font = nsFont
        tv.textColor = textColor
        tv.insertionPointColor = cursorColor
        tv.drawsBackground = false
        tv.backgroundColor = .clear
        tv.isRichText = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.textContainer?.widthTracksTextView = true
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.delegate = context.coordinator

        let sv = NSScrollView()
        sv.borderType = .noBorder
        sv.backgroundColor = .clear
        sv.drawsBackground = false
        sv.hasVerticalScroller = true
        sv.autohidesScrollers = true
        sv.documentView = tv
        return sv
    }

    func updateNSView(_ sv: NSScrollView, context: Context) {
        guard let tv = sv.documentView as? AppTextView else { return }
        if tv.string != text { tv.string = text }
        tv.font = nsFont
        tv.textColor = textColor
        tv.insertionPointColor = cursorColor
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ThemedTextEditor
        init(_ p: ThemedTextEditor) { parent = p }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }
    }
}
