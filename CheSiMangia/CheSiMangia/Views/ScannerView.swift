//
//  ScannerView.swift
//  CheSiMangia
//
//  Created by Matteo Costella on 25/09/25.
//

import SwiftUI
import VisionKit

struct ScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean8, .ean13, .upce, .code128])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true
        )
        vc.delegate = context.coordinator
        context.coordinator.controller = vc   // tieni un riferimento per fare stopScanning()
        return vc
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        // avvia lo scanner solo quando la view è pronta, evitando race con la presentazione dello sheet
        if !uiViewController.isScanning {
            try? uiViewController.startScanning()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        weak var controller: DataScannerViewController?
        private var didEmit = false          // debounce per evitare doppie rilevazioni ravvicinate

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            guard !didEmit else { return }
            for item in addedItems {
                if case let .barcode(b) = item, let code = b.payloadStringValue {
                    didEmit = true
                    // Fermiamo la sessione PRIMA di notificare il codice e chiudere lo sheet.
                    DispatchQueue.main.async { [weak self] in
                        _ = try? self?.controller?.stopScanning()
                        // Piccolissimo delay per assicurare che la camera abbia finito lo stop
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                            self?.onCode(code)
                        }
                    }
                    break
                }
            }
        }
    }
}
