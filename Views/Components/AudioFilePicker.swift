import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit

/// 端末のファイルアプリ（iCloud / ダウンロード等）から音楽・音声ファイルを選択するピッカー
public struct AudioFilePicker: UIViewControllerRepresentable {
    public let onFilePicked: (URL, String) -> Void
    @Environment(\.presentationMode) private var presentationMode
    
    public init(onFilePicked: @escaping (URL, String) -> Void) {
        self.onFilePicked = onFilePicked
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    public class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: AudioFilePicker
        
        init(_ parent: AudioFilePicker) {
            self.parent = parent
        }
        
        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            let fileName = url.deletingPathExtension().lastPathComponent
            parent.onFilePicked(url, fileName)
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
#endif
