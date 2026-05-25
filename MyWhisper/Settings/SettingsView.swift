import SwiftUI
import CoreAudio
import KeyboardShortcuts

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var selectedSection: SettingsSection = .status

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selection: $selectedSection)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsStatusHeader(viewModel: viewModel)
                    selectedContent
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .onAppear {
            viewModel.refreshStatuses()
            viewModel.startRuntimeRefresh()
        }
        .onDisappear {
            viewModel.stopRuntimeRefresh()
        }
        .frame(minWidth: 760, idealWidth: 820, minHeight: 640, idealHeight: 720)
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedSection {
        case .status:
            statusScreen
        case .recording:
            recordingScreen
        case .model:
            modelScreen
        case .api:
            apiScreen
        case .vocabulary:
            vocabularyScreen
        case .diagnostics:
            diagnosticsScreen
        case .system:
            systemScreen
        }
    }

    private var statusScreen: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Estado y permisos", subtitle: "Revisa si MyWhisper puede grabar, limpiar y pegar texto en otras apps.")

            SettingsCard {
                VStack(spacing: 0) {
                    ForEach(viewModel.permissionItems) { item in
                        PermissionStatusRow(item: item)
                        if item.id != viewModel.permissionItems.last?.id {
                            Divider().padding(.leading, 38)
                        }
                    }
                }
            }

            SettingsCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Acciones rápidas")
                        .font(.headline)
                    HStack(spacing: 10) {
                        Button {
                            viewModel.openAccessibilitySettings()
                        } label: {
                            Label("Abrir Accesibilidad", systemImage: "figure.wave")
                        }

                        Button {
                            viewModel.openMicrophoneSettings()
                        } label: {
                            Label("Abrir Micrófono", systemImage: "mic")
                        }
                    }
                }
            }
        }
    }

    private var recordingScreen: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Grabación", subtitle: "Configura cómo empiezas a dictar y qué hace MyWhisper mientras grabas.")

            SettingsCard {
                VStack(spacing: 14) {
                    SettingsRow(label: "Atajo de grabación", detail: "Presiona una vez para grabar y otra vez para transcribir.") {
                        KeyboardShortcuts.Recorder("", name: .toggleRecording)
                            .labelsHidden()
                            .frame(width: 170, alignment: .trailing)
                    }

                    Divider()

                    SettingsRow(label: "Micrófono", detail: "Usa el predeterminado del sistema o elige una entrada fija.") {
                        Picker("", selection: $viewModel.selectedMicID) {
                            Text("Predeterminado del sistema")
                                .tag(nil as AudioDeviceID?)
                            ForEach(viewModel.availableMics) { device in
                                Text(device.name)
                                    .tag(device.id as AudioDeviceID?)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 280)
                    }

                    Divider()

                    ToggleRow(
                        title: "Pausar reproducción al grabar",
                        detail: "Pausa media activa y la reanuda al terminar el dictado.",
                        isOn: $viewModel.pausePlaybackEnabled
                    )

                    Divider()

                    ToggleRow(
                        title: "Maximizar volumen del micrófono",
                        detail: "Sube temporalmente la entrada para mejorar la captura.",
                        isOn: $viewModel.maximizeMicVolumeEnabled
                    )
                }
            }

            SettingsCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Prueba rápida de micrófono")
                                .font(.headline)
                            Text(viewModel.micTestStatus)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(viewModel.micTestInFlight ? "Probando…" : "Probar micrófono") {
                            viewModel.runMicTest()
                        }
                        .disabled(viewModel.micTestInFlight)
                    }

                    ProgressView(value: viewModel.micTestLevel)
                        .tint(.cyan)
                }
            }
        }
    }

    private var modelScreen: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Modelo Whisper", subtitle: "Gestiona el modelo local de transcripción. El audio se queda en tu Mac.")

            SettingsCard {
                VStack(spacing: 14) {
                    SettingsRow(label: "Modelo", detail: "Variante local cargada por WhisperKit.") {
                        Text(viewModel.whisperModelName)
                            .font(.callout.monospaced())
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                            .textSelection(.enabled)
                    }

                    Divider()

                    SettingsRow(label: "Assets", detail: "Estado de archivos descargados.") {
                        StatusPill(
                            viewModel.whisperAssetsStatus,
                            systemImage: viewModel.whisperReady ? "checkmark.circle.fill" : "arrow.down.circle",
                            tint: viewModel.whisperReady ? .green : .orange
                        )
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Carga")
                                .font(.headline)
                            Spacer()
                            Text(viewModel.whisperReady ? "Listo" : "\(Int(viewModel.whisperLoadProgress * 100))%")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(viewModel.whisperReady ? .green : .secondary)
                        }
                        ProgressView(value: viewModel.whisperLoadProgress)
                            .tint(.blue)
                    }

                    Divider()

                    PathValueRow(
                        title: "Ruta del modelo",
                        path: viewModel.whisperAssetsPath,
                        copyAction: viewModel.copyWhisperAssetsPathToClipboard,
                        openAction: viewModel.openWhisperAssetsFolder
                    )
                }
            }

            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Mantenimiento")
                        .font(.headline)
                    HStack(spacing: 10) {
                        Button(viewModel.whisperActionInFlight ? "Preparando…" : "Preparar modelo") {
                            viewModel.prepareWhisperModel()
                        }
                        .disabled(viewModel.whisperActionInFlight)

                        Button("Resetear modelo", role: .destructive) {
                            viewModel.resetWhisperModel()
                        }
                        .disabled(viewModel.whisperActionInFlight)
                    }
                }
            }
        }
    }

    private var apiScreen: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("API", subtitle: "Solo el texto transcrito se envía a Haiku para puntuación y limpieza.")

            SettingsCard {
                VStack(spacing: 14) {
                    SettingsRow(label: "Clave configurada", detail: "Guardada en Keychain de macOS.") {
                        StatusPill(
                            viewModel.apiKeyConfigured ? "Sí" : "No",
                            systemImage: viewModel.apiKeyConfigured ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                            tint: viewModel.apiKeyConfigured ? .green : .orange
                        )
                    }

                    Divider()

                    SettingsRow(label: "Última validación", detail: "Resultado de la prueba más reciente.") {
                        Text(viewModel.apiKeyConfigured ? viewModel.apiValidationStatus : "No configurada")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                            .textSelection(.enabled)
                    }

                    Divider()

                    HStack(spacing: 10) {
                        Button("Configurar clave API…") {
                            viewModel.openAPIKey()
                        }
                        Button(viewModel.apiValidationInFlight ? "Validando…" : "Probar conexión") {
                            viewModel.testAPIConnection()
                        }
                        .disabled(viewModel.apiValidationInFlight || !viewModel.apiKeyConfigured)
                    }
                }
            }
        }
    }

    private var vocabularyScreen: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Vocabulario", subtitle: "Corrige nombres, marcas o palabras que Whisper suele confundir.")

            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    if viewModel.vocabularyEntries.isEmpty {
                        EmptyVocabularyView {
                            viewModel.vocabularyEntries.append(VocabularyEntry(wrong: "", correct: ""))
                        }
                    } else {
                        ForEach($viewModel.vocabularyEntries) { $entry in
                            HStack(spacing: 10) {
                                TextField("Incorrecto", text: $entry.wrong)
                                    .textFieldStyle(.roundedBorder)
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(.secondary)
                                TextField("Correcto", text: $entry.correct)
                                    .textFieldStyle(.roundedBorder)
                                Button {
                                    let entryId = entry.id
                                    Task { @MainActor in
                                        viewModel.vocabularyEntries.removeAll { $0.id == entryId }
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Button {
                            viewModel.vocabularyEntries.append(VocabularyEntry(wrong: "", correct: ""))
                        } label: {
                            Label("Agregar corrección", systemImage: "plus")
                        }
                    }
                }
            }
        }
    }

    private var diagnosticsScreen: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Diagnóstico", subtitle: "Información útil para entender el estado actual o reportar problemas.")

            SettingsCard {
                VStack(spacing: 14) {
                    SettingsRow(label: "Versión", detail: "Build instalado.") {
                        Text(viewModel.diagnostics.appVersion)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    Divider()

                    SettingsRow(label: "Runtime", detail: "Estado actual de la app.") {
                        StatusPill(viewModel.runtimeState, systemImage: "bolt.horizontal.circle", tint: .blue)
                    }

                    Divider()

                    SettingsRow(label: "Modelo STT", detail: "Motor local de transcripción.") {
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(viewModel.diagnostics.sttModel)
                                .multilineTextAlignment(.trailing)
                            Text(viewModel.whisperReady ? "Listo" : "Cargando (\(Int(viewModel.whisperLoadProgress * 100))%)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .textSelection(.enabled)
                    }

                    Divider()

                    SettingsRow(label: "Limpieza", detail: "Proveedor de post-procesamiento.") {
                        Text(viewModel.diagnostics.cleanupProvider)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                            .textSelection(.enabled)
                    }

                    Divider()

                    SettingsRow(label: "Último error", detail: "Último problema de transcripción registrado.") {
                        Text(viewModel.diagnostics.lastTranscriptionError)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                            .textSelection(.enabled)
                    }
                }
            }

            Button {
                viewModel.copyDiagnosticsToClipboard()
            } label: {
                Label("Copiar diagnóstico", systemImage: "doc.on.doc")
            }
        }
    }

    private var systemScreen: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Sistema", subtitle: "Ajustes globales de la app de menubar.")

            SettingsCard {
                ToggleRow(
                    title: "Iniciar al arranque",
                    detail: "Abre MyWhisper automáticamente cuando inicias sesión en macOS.",
                    isOn: $viewModel.launchAtLoginEnabled
                )
            }
        }
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.weight(.semibold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Navigation

enum SettingsSection: String, CaseIterable, Identifiable {
    case status
    case recording
    case model
    case api
    case vocabulary
    case diagnostics
    case system

    var id: Self { self }

    var title: String {
        switch self {
        case .status: return "Estado"
        case .recording: return "Grabación"
        case .model: return "Modelo"
        case .api: return "API"
        case .vocabulary: return "Vocabulario"
        case .diagnostics: return "Diagnóstico"
        case .system: return "Sistema"
        }
    }

    var systemImage: String {
        switch self {
        case .status: return "checkmark.shield"
        case .recording: return "mic.fill"
        case .model: return "waveform"
        case .api: return "key.fill"
        case .vocabulary: return "textformat.abc"
        case .diagnostics: return "stethoscope"
        case .system: return "gearshape"
        }
    }
}

private struct SettingsSidebar: View {
    @Binding var selection: SettingsSection

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("MyWhisper")
                    .font(.title3.weight(.semibold))
                Text("Preferencias")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 24)

            VStack(spacing: 4) {
                ForEach(SettingsSection.allCases) { section in
                    Button {
                        selection = section
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: section.systemImage)
                                .font(.system(size: 15, weight: .medium))
                                .frame(width: 20)
                            Text(section.title)
                                .font(.callout.weight(selection == section ? .semibold : .regular))
                            Spacer()
                        }
                        .foregroundStyle(selection == section ? Color.accentColor : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background {
                            if selection == section {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.accentColor.opacity(0.16))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(width: 190)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Shared building blocks

private struct SettingsStatusHeader: View {
    let viewModel: SettingsViewModel

    private var permissionsReady: Bool {
        !viewModel.permissionItems.isEmpty && viewModel.permissionItems.allSatisfy(\.isGranted)
    }

    private var isReady: Bool {
        permissionsReady && viewModel.apiKeyConfigured && viewModel.whisperReady
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isReady ? Color.green.opacity(0.18) : Color.orange.opacity(0.18))
                    Image(systemName: isReady ? "checkmark" : "exclamationmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(isReady ? .green : .orange)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isReady ? "Listo para dictar" : "Revisa la configuración")
                        .font(.title2.weight(.semibold))
                    Text(statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    StatusPill(viewModel.runtimeState, systemImage: "bolt.horizontal.circle", tint: .blue)
                    StatusPill(viewModel.whisperReady ? "Whisper listo" : "Whisper cargando", systemImage: "waveform", tint: viewModel.whisperReady ? .green : .orange)
                }
            }

            VoiceTraceView()
                .frame(height: 22)
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var statusMessage: String {
        if !permissionsReady { return "Falta al menos un permiso para que MyWhisper pueda operar sin fricción." }
        if !viewModel.apiKeyConfigured { return "Configura la clave de API para limpiar el texto después de transcribir." }
        if !viewModel.whisperReady { return "El modelo local todavía no está listo para transcribir." }
        return "Hotkey, modelo local, API y permisos están preparados."
    }
}

private struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.07), lineWidth: 1)
            }
    }
}

private struct SettingsRow<Accessory: View>: View {
    let label: String
    let detail: String
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 16)
            accessory
                .frame(maxWidth: 340, alignment: .trailing)
        }
    }
}

private struct ToggleRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

private struct PermissionStatusRow: View {
    let item: PermissionItem

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: item.isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(item.isGranted ? .green : .orange)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.headline)
                Text(item.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            StatusPill(item.isGranted ? "OK" : "Pendiente", systemImage: item.isGranted ? "checkmark" : "clock", tint: item.isGranted ? .green : .orange)
        }
        .padding(.vertical, 8)
    }
}

private struct StatusPill: View {
    let text: String
    let systemImage: String
    let tint: Color

    init(_ text: String, systemImage: String, tint: Color) {
        self.text = text
        self.systemImage = systemImage
        self.tint = tint
    }

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14), in: Capsule())
            .lineLimit(1)
    }
}

private struct PathValueRow: View {
    let title: String
    let path: String
    let copyAction: () -> Void
    let openAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button {
                    copyAction()
                } label: {
                    Label("Copiar", systemImage: "doc.on.doc")
                }
                Button {
                    openAction()
                } label: {
                    Label("Abrir", systemImage: "folder")
                }
            }

            Text(path.isEmpty ? "Sin ruta disponible" : path)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.45), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

private struct EmptyVocabularyView: View {
    let addAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "text.badge.plus")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sin correcciones todavía")
                        .font(.headline)
                    Text("Agrega pares como “súper whisper” → “SuperWhisper” para pulir el texto final.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                addAction()
            } label: {
                Label("Agregar corrección", systemImage: "plus")
            }
        }
    }
}

private struct VoiceTraceView: View {
    private let bars: [CGFloat] = [0.25, 0.58, 0.36, 0.78, 0.44, 0.68, 0.32, 0.84, 0.48, 0.62, 0.28, 0.7, 0.38, 0.55, 0.22]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(bars.enumerated()), id: \.offset) { _, multiplier in
                Capsule()
                    .fill(LinearGradient(colors: [.cyan.opacity(0.45), .blue.opacity(0.55)], startPoint: .bottom, endPoint: .top))
                    .frame(width: 4, height: max(4, 22 * multiplier))
            }
            Rectangle()
                .fill(LinearGradient(colors: [.cyan.opacity(0.28), .clear], startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(0.8)
    }
}
