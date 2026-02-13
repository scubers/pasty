import SwiftUI

struct CloudSyncE2eePassphraseSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var passphrase = ""
    @State private var confirmPassphrase = ""
    @State private var isSettingNew = true
    
    var onSave: (String) -> Void
    
    init(onSave: @escaping (String) -> Void) {
        self.onSave = onSave
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("End-to-End Encryption")
                .font(.headline)
            
            Text("Enter a passphrase to encrypt your clipboard data before syncing. You must use the same passphrase on all devices.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                SecureField("Passphrase", text: $passphrase)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                
                if isSettingNew {
                    SecureField("Confirm Passphrase", text: $confirmPassphrase)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 300)
                }
            }
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Save") {
                    onSave(passphrase)
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(passphrase.isEmpty || (isSettingNew && passphrase != confirmPassphrase))
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}
