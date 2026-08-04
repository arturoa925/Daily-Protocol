//
//  SettingsView.swift
//  Launch Control
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("appAppearance") private var appearanceRaw: String = AppearanceMode.system.rawValue
    // used to dismiss the sheet
    @Environment(\.dismiss) private var dismiss

    private var appearance: Binding<AppearanceMode> {
        Binding(
            get: { AppearanceMode(rawValue: appearanceRaw) ?? .system },
            set: { appearanceRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Appearance", selection: appearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                    .accessibilityLabel("Appearance")
                    .accessibilityValue(appearance.wrappedValue.label)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Choose how Launch Control looks, or match your device's system setting.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Done")
                        .accessibilityHint("Closes settings.")
                }
            }
        }
        // Applied here too (not just at the app root) so the sheet itself updates
        // live as the picker changes — a sheet's hosting controller otherwise only
        // picks up a preferredColorScheme change set above it once it's re-presented.
        .preferredColorScheme(appearance.wrappedValue.colorScheme)
    }
}

#Preview {
    SettingsView()
}
