import SwiftUI
import CoreAudio
import KeyboardShortcuts

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            // SECCION 1: GRABACION (per D-01, D-02)
            Section {
                KeyboardShortcuts.Recorder("Atajo de grabación:", name: .toggleRecording)

                Picker("Micrófono:", selection: $viewModel.selectedMicID) {
                    Text("Predeterminado del sistema")
                        .tag(nil as AudioDeviceID?)
                    ForEach(viewModel.availableMics) { device in
                        Text(device.name)
                            .tag(device.id as AudioDeviceID?)
                    }
                }

                Toggle("Pausar reproducción al grabar", isOn: $viewModel.pausePlaybackEnabled)
                Toggle("Maximizar volumen del micrófono", isOn: $viewModel.maximizeMicVolumeEnabled)
            } header: {
                Label("Grabación", systemImage: "mic.fill")
            }

            // SECCION 2: API (per D-01, D-03, D-12)
            Section {
                Button("Configurar clave API...") {
                    viewModel.openAPIKey()
                }
            } header: {
                Label("API", systemImage: "key.fill")
            }

            // SECCION 3: VOCABULARIO (per D-01, D-04, D-07, D-08)
            Section {
                ForEach($viewModel.vocabularyEntries) { $entry in
                    HStack {
                        TextField("Incorrecto", text: $entry.wrong)
                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                        TextField("Correcto", text: $entry.correct)
                        Button {
                            let entryId = entry.id
                            Task { @MainActor in
                                viewModel.vocabularyEntries.removeAll { $0.id == entryId }
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button {
                    viewModel.vocabularyEntries.append(VocabularyEntry(wrong: "", correct: ""))
                } label: {
                    Label("Agregar corrección", systemImage: "plus")
                }
            } header: {
                Label("Vocabulario", systemImage: "textformat.abc")
            }

            // SECCION 4: SISTEMA (per D-01, D-05)
            Section {
                Toggle("Iniciar al arranque", isOn: $viewModel.launchAtLoginEnabled)
            } header: {
                Label("Sistema", systemImage: "gear")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 400)
    }
}
