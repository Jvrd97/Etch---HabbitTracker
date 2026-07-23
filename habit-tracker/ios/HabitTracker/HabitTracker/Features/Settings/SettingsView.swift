// [review:need-review] PHASE-01/03-ios-scaffold-settings
// summary: Settings screen — server address + API key fields, connection check button with status indicator
import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("http://100.x.x.x:8000", text: $viewModel.serverAddress)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("API key", text: $viewModel.apiKey)
                }
                Section {
                    Button {
                        Task { await viewModel.checkConnection() }
                    } label: {
                        HStack {
                            Text("Check connection")
                            Spacer()
                            statusIndicator
                        }
                    }
                    .disabled(viewModel.connectionState == .checking)
                } footer: {
                    if case .failure(let message) = viewModel.connectionState {
                        Text(message)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch viewModel.connectionState {
        case .idle:
            EmptyView()
        case .checking:
            ProgressView()
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failure:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}
