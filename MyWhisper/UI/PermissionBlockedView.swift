import SwiftUI
import AppKit

struct PermissionBlockedView: View {
    let reason: PermissionReason
    let permissionsManager: PermissionsManager

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: iconName)
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text(title)
                .font(.title2)
                .fontWeight(.semibold)

            Text(explanation)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button("Abrir Configuración del Sistema") {
                openSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(32)
        .frame(width: 420)
    }

    private var iconName: String {
        switch reason {
        case .accessibility: return "accessibility"
        case .microphone: return "mic.slash"
        }
    }

    private var title: String {
        switch reason {
        case .accessibility: return "Se necesita acceso de Accesibilidad"
        case .microphone: return "Se necesita acceso al Micrófono"
        }
    }

    private var explanation: String {
        switch reason {
        case .accessibility:
            return "MyWhisper necesita permiso de Accesibilidad para pegar texto automáticamente en otras apps. Sin este permiso, la app no puede funcionar.\n\nAbrí Configuración del Sistema → Privacidad y Seguridad → Accesibilidad y activá MyWhisper."
        case .microphone:
            return "MyWhisper necesita acceso al Micrófono para grabar tu voz. Sin este permiso, la grabación no puede iniciarse.\n\nAbrí Configuración del Sistema → Privacidad y Seguridad → Micrófono y activá MyWhisper."
        }
    }

    private func openSettings() {
        switch reason {
        case .accessibility: permissionsManager.openSystemSettingsForAccessibility()
        case .microphone: permissionsManager.openSystemSettingsForMicrophone()
        }
    }
}
