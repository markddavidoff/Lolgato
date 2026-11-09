import SwiftUI

struct AutomationSettingsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var cameraMonitor: CameraMonitor

    private var isSelectedCameraConnected: Bool {
        guard let selectedCameraID = appState.selectedCamera?.id else { return false }
        return cameraMonitor.availableCameras.contains { $0.id == selectedCameraID }
    }

    private var isTriggerCameraConnected: Bool {
        guard let triggerCameraID = appState.triggerCamera?.id else { return true }
        return cameraMonitor.availableCameras.contains { $0.id == triggerCameraID }
    }

    var body: some View {
        VStack(spacing: 20) {
            settingRow(label: "Camera:") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Lights on automatically", isOn: $appState.lightsOnWithCamera)

                    Picker("Trigger camera:", selection: Binding(
                        get: { appState.triggerCamera?.id ?? "" },
                        set: { newId in
                            if let selected = cameraMonitor.availableCameras.first(where: { $0.id == newId }) {
                                appState.triggerCamera = StoredCameraInfo(id: selected.id, name: selected.name)
                            } else if newId.isEmpty {
                                appState.triggerCamera = nil
                            }
                        }
                    )) {
                        Text("Any camera").tag("")
                        ForEach(cameraMonitor.availableCameras) { camera in
                            Text(camera.name).tag(camera.id)
                        }
                        if let triggerCamera = appState.triggerCamera, !isTriggerCameraConnected {
                            Text("\(triggerCamera.name) (not connected)").tag(triggerCamera.id)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())

                    if let triggerCamera = appState.triggerCamera, !isTriggerCameraConnected {
                        Text("Warning: '\(triggerCamera.name)' is not currently connected.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            } caption: {
                Text("Turn on lights when the trigger camera is in use. Pick a specific camera if another one is always running.")
            }

            settingRow(label: "Sleep:") {
                Toggle("Lights on and off automatically", isOn: $appState.lightsOffOnSleep)
            } caption: {
                Text("Turn off lights when system goes to sleep or is locked, and turn them back on when waking up.")
            }

            settingRow(label: "Wake condition:") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Only turn lights back on when at my desk", isOn: $appState.wakeOnCameraDetectionEnabled)
                        .disabled(!appState.lightsOffOnSleep)

                    if appState.wakeOnCameraDetectionEnabled {
                        if cameraMonitor.availableCameras.isEmpty {
                            Text("No cameras found.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Picker("Desk camera:", selection: Binding(
                                get: { appState.selectedCamera?.id ?? "" },
                                set: { newId in
                                    if let selected = cameraMonitor.availableCameras.first(where: { $0.id == newId }) {
                                        appState.selectedCamera = StoredCameraInfo(id: selected.id, name: selected.name)
                                    } else {
                                        appState.selectedCamera = nil
                                    }
                                }
                            )) {
                                Text("Choose your desk camera...").tag("")
                                ForEach(cameraMonitor.availableCameras) { camera in
                                    Text(camera.name).tag(camera.id)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .disabled(cameraMonitor.availableCameras.isEmpty)

                            if let selectedCamera = appState.selectedCamera, !isSelectedCameraConnected {
                                Text("Warning: Your desk camera '\(selectedCamera.name)' is not currently connected.")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding(.top, 2)
                            }
                        }

                        Text("Prevents lights from turning on when waking your laptop away from your desk (e.g., in another room).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } caption: {
                EmptyView()
            }

            settingRow(label: "Night Shift:") {
                Toggle("Sync with Night Shift", isOn: $appState.syncWithNightShift)
            } caption: {
                Text("Automatically adjust light temperature to match macOS Night Shift.")
            }

            Spacer()
            Divider()
            ResetButton(action: resetToDefaults)
        }
        .onChange(of: appState.wakeOnCameraDetectionEnabled) { _, newValue in
            if !newValue {
                appState.selectedCamera = nil
            }
        }
    }

    private func resetToDefaults() {
        appState.lightsOnWithCamera = false
        appState.triggerCamera = nil
        appState.lightsOffOnSleep = false
        appState.syncWithNightShift = false
        appState.wakeOnCameraDetectionEnabled = false
        appState.selectedCamera = nil
    }
}
