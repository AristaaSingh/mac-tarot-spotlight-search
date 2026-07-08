import AppKit
import SwiftUI

// MARK: - Right-click capture
// NSHostingView consumes events before background NSViews see them, so we use
// a local NSEvent monitor that checks view bounds on every right-click.

struct RightClickable: NSViewRepresentable {
    let action: (NSPoint) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }
    func makeNSView(context: Context) -> NSView { context.coordinator.view }
    func updateNSView(_ nsView: NSView, context: Context) { context.coordinator.action = action }

    final class Coordinator {
        var action: (NSPoint) -> Void
        let view = NSView()
        private var monitor: Any?

        init(action: @escaping (NSPoint) -> Void) {
            self.action = action
            monitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
                guard let self,
                      self.view.window != nil,
                      let superview = self.view.superview else { return event }
                let loc = event.locationInWindow
                let frameInWindow = superview.convert(self.view.frame, to: nil)
                if frameInWindow.contains(loc) {
                    let screenPt = event.window?.convertPoint(toScreen: loc) ?? loc
                    DispatchQueue.main.async { self.action(screenPt) }
                }
                return event
            }
        }

        deinit { if let m = monitor { NSEvent.removeMonitor(m) } }
    }
}

// MARK: - Shared panel setup

private func makeHostingView<V: View>(_ content: V) -> (view: NSHostingView<V>, size: CGSize) {
    let hosting = NSHostingView(rootView: content)
    hosting.wantsLayer = true
    hosting.layout()
    return (hosting, hosting.fittingSize)
}

// MARK: - Context menu panel (no arrow, cursor-positioned)

final class ContextMenuPanel: NSObject, NSWindowDelegate {
    static let shared = ContextMenuPanel()
    private var panel: NSPanel?
    private var dismissMonitor: Any?

    static func show(at screenPoint: NSPoint, content: some View) {
        shared.showPanel(at: screenPoint, content: content)
    }

    static func dismiss() { shared.dismissPanel() }

    private func showPanel(at screenPoint: NSPoint, content: some View) {
        dismissPanel()

        let (hosting, size) = makeHostingView(content)
        let p = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = true
        p.level = .popUpMenu; p.contentView = hosting; p.delegate = self
        p.setFrameOrigin(NSPoint(x: screenPoint.x + 4, y: screenPoint.y - size.height))
        p.orderFront(nil)
        panel = p

        dismissMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if event.window !== self?.panel { self?.dismissPanel() }
            return event
        }
    }

    func dismissPanel() {
        if let m = dismissMonitor { NSEvent.removeMonitor(m); dismissMonitor = nil }
        let p = panel; panel = nil
        p?.close()
    }

    func windowWillClose(_ notification: Notification) { dismissPanel() }
}

// MARK: - Dialog panel (rename / confirm / folder picker)

// Borderless NSPanel doesn't become key by default — override so text fields work.
private final class KeyableDialogPanel: NSPanel {
    override var canBecomeKey:  Bool { true }
    override var canBecomeMain: Bool { false }
}

final class AppDialogPanel: NSObject, NSWindowDelegate {
    static let shared = AppDialogPanel()
    private var panel: KeyableDialogPanel?

    static func dismiss() { shared.close() }

    static func showRename(title: String, initial: String, placeholder: String,
                           onConfirm: @escaping (String) -> Void) {
        shared.showDialog(AppRenameDialog(
            title: title, initial: initial, placeholder: placeholder, onConfirm: onConfirm
        ))
    }

    static func showConfirm(title: String, message: String, destructiveLabel: String,
                            onConfirm: @escaping () -> Void) {
        shared.showDialog(AppConfirmDialog(
            title: title, message: message, destructiveLabel: destructiveLabel, onConfirm: onConfirm
        ))
    }

    static func showFolderPicker(title: String, folders: [Folder],
                                 onPick: @escaping (Folder) -> Void) {
        shared.showDialog(AppFolderPickerDialog(title: title, folders: folders, onPick: onPick))
    }

    private func showDialog(_ content: some View) {
        close()
        let (hosting, size) = makeHostingView(content)
        let p = KeyableDialogPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = true
        p.level = .modalPanel; p.contentView = hosting; p.delegate = self

        let anchor = NSApp.keyWindow?.frame ?? NSApp.mainWindow?.frame
                  ?? NSScreen.main?.visibleFrame ?? .zero
        p.setFrameOrigin(NSPoint(x: anchor.midX - size.width / 2, y: anchor.midY - size.height / 2))
        p.makeKeyAndOrderFront(nil)
        panel = p
    }

    func close() { let p = panel; panel = nil; p?.close() }
    func windowWillClose(_ notification: Notification) { close() }
}

// MARK: - Shared menu components

struct ContextMenuRow: View {
    let icon: String
    let label: String
    var isDestructive: Bool = false
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 11.5, weight: .medium))
                    .frame(width: 16, alignment: .center)
                Text(label).font(.app(13))
                Spacer()
            }
            .foregroundColor(isDestructive ? .red.opacity(0.8) : Theme.ink)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(isHovered ? Theme.ink.opacity(0.06) : Color.clear)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.1), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct MenuDivider: View {
    var body: some View { Theme.divider.frame(height: 1).padding(.horizontal, 8) }
}

// MARK: - Folder context menu

struct FolderContextMenuContent: View {
    let folder: Folder

    var body: some View {
        VStack(spacing: 0) {
            ContextMenuRow(icon: "pencil", label: "Rename") {
                ContextMenuPanel.dismiss()
                AppDialogPanel.showRename(
                    title: "Rename Folder", initial: folder.name, placeholder: "Folder name"
                ) { FolderStore.shared.rename(folder, to: $0) }
            }
            MenuDivider()
            ContextMenuRow(icon: "trash", label: "Delete", isDestructive: true) {
                ContextMenuPanel.dismiss()
                AppDialogPanel.showConfirm(
                    title: "Delete \"\(folder.name)\"?",
                    message: "All readings in this folder will also be deleted.",
                    destructiveLabel: "Delete"
                ) {
                    ReadingStore.shared.deleteAll(inFolders: [folder.id])
                    FolderStore.shared.delete(folder)
                }
            }
        }
        .frame(width: 180).background(Theme.bg).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Reading context menu

struct ReadingContextMenuContent: View {
    let entry: ReadingEntry
    let otherFolders: [Folder]   // snapshotted at init — cannot change while menu is open

    init(entry: ReadingEntry) {
        self.entry = entry
        self.otherFolders = FolderStore.shared.folders.filter { $0.id != entry.folderID }
    }

    var body: some View {
        VStack(spacing: 0) {
            ContextMenuRow(icon: "pencil", label: "Rename") {
                ContextMenuPanel.dismiss()
                AppDialogPanel.showRename(
                    title: "Rename Reading", initial: entry.title, placeholder: "Title"
                ) { name in
                    var updated = entry; updated.title = name
                    ReadingStore.shared.save(updated)
                }
            }
            if !otherFolders.isEmpty {
                MenuDivider()
                ContextMenuRow(icon: "arrow.right.circle", label: "Move to…") {
                    ContextMenuPanel.dismiss()
                    AppDialogPanel.showFolderPicker(title: "Move to…", folders: otherFolders) {
                        ReadingStore.shared.move([entry.id], toFolder: $0.id)
                    }
                }
                ContextMenuRow(icon: "doc.on.doc", label: "Copy to…") {
                    ContextMenuPanel.dismiss()
                    AppDialogPanel.showFolderPicker(title: "Copy to…", folders: otherFolders) {
                        ReadingStore.shared.copy([entry.id], toFolder: $0.id)
                    }
                }
            }
            MenuDivider()
            ContextMenuRow(icon: "trash", label: "Delete", isDestructive: true) {
                ContextMenuPanel.dismiss()
                AppDialogPanel.showConfirm(
                    title: "Delete this reading?", message: "", destructiveLabel: "Delete"
                ) { ReadingStore.shared.delete(entry) }
            }
        }
        .frame(width: 200).background(Theme.bg).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Dialog: Rename

struct AppRenameDialog: View {
    let title: String
    let placeholder: String
    let onConfirm: (String) -> Void

    @State private var text: String
    @State private var fieldFocused = false

    init(title: String, initial: String, placeholder: String, onConfirm: @escaping (String) -> Void) {
        self.title = title
        self.placeholder = placeholder
        self.onConfirm = onConfirm
        _text = State(initialValue: initial)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.app(14, weight: .semibold))
                .foregroundColor(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 20)
                .padding(.top, 18).padding(.bottom, 14)

            ThemedTextField(
                text: $text,
                placeholder: placeholder,
                nsFont: .didot(13),
                textColor: Theme.nsInk,
                cursorColor: Theme.nsInk,
                isFocused: fieldFocused,
                onSubmit: confirm,
                onEscape: AppDialogPanel.dismiss
            )
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Theme.ink.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 20).padding(.bottom, 16)

            Theme.divider.frame(height: 1)

            HStack(spacing: 0) {
                AppDialogButton("Cancel", action: AppDialogPanel.dismiss)
                    .keyboardShortcut(.cancelAction)
                Theme.divider.frame(width: 1)
                AppDialogButton("Rename", primary: true, action: confirm)
                    .keyboardShortcut(.defaultAction)
            }
            .frame(height: 44)
        }
        .frame(width: 300)
        .background(Theme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { fieldFocused = true }
        }
    }

    private func confirm() {
        let t = text.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { AppDialogPanel.dismiss(); onConfirm(t) }
    }
}

// MARK: - Dialog: Confirm / delete

struct AppConfirmDialog: View {
    let title: String
    let message: String
    let destructiveLabel: String
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: message.isEmpty ? 0 : 5) {
                Text(title)
                    .font(.app(14, weight: .semibold))
                    .foregroundColor(Theme.ink)
                if !message.isEmpty {
                    Text(message).font(.app(12)).foregroundColor(Theme.mid)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 16)

            Theme.divider.frame(height: 1)

            HStack(spacing: 0) {
                AppDialogButton("Cancel", action: AppDialogPanel.dismiss)
                    .keyboardShortcut(.cancelAction)
                Theme.divider.frame(width: 1)
                AppDialogButton(destructiveLabel, destructive: true) {
                    AppDialogPanel.dismiss(); onConfirm()
                }
            }
            .frame(height: 44)
        }
        .frame(width: 300)
        .background(Theme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Dialog: Folder picker (move / copy)

struct AppFolderPickerDialog: View {
    let title: String
    let folders: [Folder]
    let onPick: (Folder) -> Void

    var body: some View {
        let lastID = folders.last?.id
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.app(14, weight: .semibold))
                    .foregroundColor(Theme.ink)
                Spacer()
                Button(action: AppDialogPanel.dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.faint)
                        .frame(width: 20, height: 20)
                        .background(Theme.ink.opacity(0.07))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 12)

            Theme.divider.frame(height: 1)

            VStack(spacing: 0) {
                ForEach(folders) { folder in
                    PickerFolderRow(folder: folder) {
                        AppDialogPanel.dismiss(); onPick(folder)
                    }
                    if folder.id != lastID {
                        Theme.divider.frame(height: 1).padding(.horizontal, 12)
                    }
                }
            }
        }
        .frame(width: 260)
        .background(Theme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct PickerFolderRow: View {
    let folder: Folder
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "folder").font(.system(size: 12)).foregroundColor(Theme.ink)
                Text(folder.name).font(.app(13)).foregroundColor(Theme.ink)
                Spacer()
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(isHovered ? Theme.ink.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.1), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Dialog button (Cancel / Confirm / Destructive)

struct AppDialogButton: View {
    let label: String
    var destructive: Bool = false
    var primary: Bool = false
    let action: () -> Void
    @State private var isHovered = false

    init(_ label: String, destructive: Bool = false, primary: Bool = false, action: @escaping () -> Void) {
        self.label = label; self.destructive = destructive; self.primary = primary; self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.app(13, weight: primary || destructive ? .semibold : .regular))
                .foregroundColor(
                    destructive ? .red.opacity(0.8) :
                    primary     ? Theme.ink : Theme.mid
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(isHovered ? Theme.ink.opacity(0.05) : Color.clear)
                .contentShape(Rectangle())
                .animation(.easeOut(duration: 0.1), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
