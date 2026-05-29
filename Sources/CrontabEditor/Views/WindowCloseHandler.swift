import AppKit
import Foundation
import SwiftUI

struct WindowCloseHandler: NSViewRepresentable {
    @ObservedObject var viewModel: CrontabViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.delegate = context.coordinator
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.viewModel = viewModel
        DispatchQueue.main.async {
            nsView.window?.delegate = context.coordinator
        }
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        var viewModel: CrontabViewModel

        init(viewModel: CrontabViewModel) {
            self.viewModel = viewModel
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            guard viewModel.hasUnsavedChanges else {
                return true
            }

            let alert = NSAlert()
            alert.messageText = L10n.t("Save changes before closing?")
            alert.informativeText = L10n.t("You have unsaved jobs or changes. Save them before closing, discard them, or cancel closing.")
            alert.alertStyle = .warning
            alert.addButton(withTitle: L10n.t("Save"))
            alert.addButton(withTitle: L10n.t("Discard"))
            alert.addButton(withTitle: L10n.t("Cancel"))

            switch alert.runModal() {
            case .alertFirstButtonReturn:
                return viewModel.save()
            case .alertSecondButtonReturn:
                return true
            default:
                return false
            }
        }
    }
}
