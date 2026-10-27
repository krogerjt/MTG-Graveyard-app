import AVFoundation
import SwiftUI
import VisionKit

/// Live camera text recognition that offers the card name it reads. Text recognition runs on
/// the device; nothing is sent to Scryfall until the user imports the finished decklist.
struct ScanCardView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (String) -> Void
    @State private var access = CameraAccess.checking
    @State private var detectedName: String?
    @State private var tappedName: String?
    @State private var editedName = ""
    @State private var addedCount = 0
    @State private var lastAdded: String?

    enum CameraAccess { case checking, granted, denied, unsupported }

    init(onAdd: @escaping (String) -> Void) { self.onAdd = onAdd }

    var body: some View {
        NavigationStack {
            Group {
                switch access {
                case .checking: ProgressView("Starting camera…")
                case .unsupported: ContentUnavailableView("Scanning Unavailable", systemImage: "camera.metering.unknown", description: Text("This device can't recognize text with the camera. Type the card name in the decklist instead."))
                case .denied: ContentUnavailableView { Label("Camera Access Needed", systemImage: "camera") } description: { Text("Allow camera access in Settings to scan card names.") } actions: { Button("Open Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } } }
                case .granted: scanner
                }
            }
            .navigationTitle("Scan Card").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { await checkAccess() }
        }
    }

    private var scanner: some View {
        CardTextScanner(onDetect: { detectedName = $0 }, onTap: { tappedName = CardNameExtractor.cleanedName($0) ?? $0 })
            .ignoresSafeArea(edges: .bottom)
            .overlay(alignment: .bottom) {
                VStack(spacing: 10) {
                    Text(tappedName == nil ? "Point at the card name, or tap the name to pick it." : "Using the text you tapped.").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        TextField("Card name", text: $editedName).textFieldStyle(.roundedBorder).autocorrectionDisabled().textInputAutocapitalization(.words).accessibilityLabel("Detected card name")
                        Button("Add") { add() }.buttonStyle(.borderedProminent).disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if let lastAdded { Text("Added \(lastAdded) · \(addedCount) scanned").font(.caption.bold()).foregroundStyle(.green) }
                }
                .padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)).padding()
            }
            .onChange(of: tappedName ?? detectedName) { _, name in if let name { editedName = name } }
    }

    private func add() {
        let name = editedName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        // Keep the name in the field so tapping Add again adds another copy, e.g. a second Forest.
        onAdd(name); addedCount += 1; lastAdded = name; tappedName = nil
    }

    private func checkAccess() async {
        guard DataScannerViewController.isSupported else { access = .unsupported; return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: access = .granted
        case .notDetermined: access = await AVCaptureDevice.requestAccess(for: .video) ? .granted : .denied
        default: access = .denied
        }
        if access == .granted, !DataScannerViewController.isAvailable { access = .denied }
    }
}

private struct CardTextScanner: UIViewControllerRepresentable {
    let onDetect: (String?) -> Void
    let onTap: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.text()], qualityLevel: .accurate, recognizesMultipleItems: true, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.parent = self
        if !scanner.isScanning { try? scanner.startScanning() }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) { scanner.stopScanning() }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: CardTextScanner
        private var lastCandidate: String?
        init(parent: CardTextScanner) { self.parent = parent }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            if case .text(let text) = item { parent.onTap(text.transcript) }
        }
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) { refresh(allItems) }
        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) { refresh(allItems) }
        func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) { refresh(allItems) }

        private func refresh(_ items: [RecognizedItem]) {
            let lines = items.compactMap { item -> ScannedText? in
                guard case .text(let text) = item else { return nil }
                let b = text.bounds
                let xs = [b.topLeft.x, b.topRight.x, b.bottomLeft.x, b.bottomRight.x], ys = [b.topLeft.y, b.topRight.y, b.bottomLeft.y, b.bottomRight.y]
                return ScannedText(text: text.transcript, frame: CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!))
            }
            // Keep the last good guess while the camera briefly loses the card.
            guard let candidate = CardNameExtractor.bestCandidate(from: lines), candidate != lastCandidate else { return }
            lastCandidate = candidate
            parent.onDetect(candidate)
        }
    }
}
