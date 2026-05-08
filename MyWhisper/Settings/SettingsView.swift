import SwiftUI
import CoreAudio
import KeyboardShortcuts

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                ForEach(viewModel.permissionItems) { item in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(item.title, systemImage: item.isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(item.isGranted ? .green : .orange)
                            Text(item.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.isGranted ? "OK" : "Pendiente")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(item.isGranted ? .green : .orange)
                    }
                    .padding(.vertical, 2)
                }

                HStack {
                    Button("Abrir Accesibilidad") {
                        viewModel.openAccessibilitySettings()
                    }
                    Button("Abrir Micrófono") {
                        viewModel.openMicrophoneSettings()
                    }
                }
            } header: {
                Label("Estado y permisos", systemImage: "checkmark.shield")
            }

            // SECCION 1: GRABACION
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

            Section {
                LabeledContent("Modelo") {
                    Text(viewModel.whisperModelName)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Assets") {
                    Text(viewModel.whisperAssetsStatus)
                        .foregroundStyle(viewModel.whisperReady ? .green : .secondary)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Ruta") {
                    Text(viewModel.whisperAssetsPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Carga") {
                    VStack(alignment: .trailing, spacing: 4) {
                        ProgressView(value: viewModel.whisperLoadProgress)
                            .frame(width: 160)
                        Text(viewModel.whisperReady ? "Listo" : "\(Int(viewModel.whisperLoadProgress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Runtime") {
                    Text(viewModel.runtimeState)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button(viewModel.whisperActionInFlight ? "Preparando..." : "Preparar modelo") {
                        viewModel.prepareWhisperModel()
                    }
                    .disabled(viewModel.whisperActionInFlight)

                    Button("Resetear modelo") {
                        viewModel.resetWhisperModel()
                    }
                    .disabled(viewModel.whisperActionInFlight)
                }
                Divider()
                LabeledContent("Prueba de micrófono") {
                    VStack(alignment: .trailing, spacing: 4) {
                        ProgressView(value: viewModel.micTestLevel)
                            .frame(width: 160)
                        Text(viewModel.micTestStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Button(viewModel.micTestInFlight ? "Probando..." : "Probar micrófono") {
                    viewModel.runMicTest()
                }
                .disabled(viewModel.micTestInFlight)
            } header: {
                Label("Whisper", systemImage: "waveform")
            }

            // SECCION 2: API
            Section {
                LabeledContent("Clave configurada") {
                    Text(viewModel.apiKeyConfigured ? "Sí" : "No")
                        .foregroundStyle(viewModel.apiKeyConfigured ? .green : .secondary)
                }

                LabeledContent("Última validación") {
                    Text(viewModel.apiValidationStatus)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Button("Configurar clave API...") {
                        viewModel.openAPIKey()
                    }
                    Button(viewModel.apiValidationInFlight ? "Validando..." : "Probar conexión") {
                        viewModel.testAPIConnection()
                    }
                    .disabled(viewModel.apiValidationInFlight || !viewModel.apiKeyConfigured)
                }
            } header: {
                Label("API", systemImage: "key.fill")
            }

            // SECCION 3: VOCABULARIO
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

            Section {
                LabeledContent("Versión") {
                    Text(viewModel.diagnostics.appVersion)
                }
                LabeledContent("Modelo STT") {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(viewModel.diagnostics.sttModel)
                        Text(viewModel.whisperReady ? "Listo" : "Cargando (\(Int(viewModel.whisperLoadProgress * 100))%)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Limpieza") {
                    Text(viewModel.diagnostics.cleanupProvider)
                }
                LabeledContent("Último error") {
                    Text(viewModel.diagnostics.lastTranscriptionError)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }

                Button("Copiar diagnóstico") {
                    viewModel.copyDiagnosticsToClipboard()
                }
            } header: {
                Label("Diagnóstico", systemImage: "stethoscope")
            }

            // SECCION 4: SISTEMA
            Section {
                Toggle("Iniciar al arranque", isOn: $viewModel.launchAtLoginEnabled)
            } header: {
                Label("Sistema", systemImage: "gear")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            viewModel.refreshStatuses()
            viewModel.startRuntimeRefresh()
        }
        .onDisappear {
            viewModel.stopRuntimeRefresh()
        }
        .frame(minWidth: 560, minHeight: 700)
    }
}
