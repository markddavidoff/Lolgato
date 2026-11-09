import SettingsAccess
import SwiftUI

struct DeviceRow: View {
    @ObservedObject var device: ElgatoDevice

    var body: some View {
        Text(device.name)
            .font(.subheadline)
    }
}

struct LolgatoMenu: View {
    @ObservedObject var appState: AppState
    @ObservedObject var deviceManager: ElgatoDeviceManager
    @ObservedObject var cameraMonitor: CameraMonitor
    let updateChecker = GitHubUpdateChecker()

    var readyDevices: [ElgatoDevice] {
        deviceManager.devices.filter { !$0.macAddress.isEmpty }
    }

    private func isConnected(_ camera: StoredCameraInfo) -> Bool {
        cameraMonitor.availableCameras.contains { $0.id == camera.id }
    }

    private var triggerCameraTitle: String {
        guard let camera = appState.triggerCamera else {
            return "Camera: Any camera"
        }
        return isConnected(camera) ? "Camera: \(camera.name)" : "⚠ \(camera.name) (not connected)"
    }

    private var deskCameraTitle: String {
        guard let camera = appState.selectedCamera else {
            return "⚠ Back on only at desk: no camera chosen"
        }
        return isConnected(camera)
            ? "Back on only at desk: \(camera.name)"
            : "⚠ Back on only at desk: \(camera.name) (not connected)"
    }

    private var triggerCameraSelection: Binding<String> {
        Binding(
            get: { appState.triggerCamera?.id ?? "" },
            set: { newId in
                if let selected = cameraMonitor.availableCameras.first(where: { $0.id == newId }) {
                    appState.triggerCamera = StoredCameraInfo(id: selected.id, name: selected.name)
                } else if newId.isEmpty {
                    appState.triggerCamera = nil
                }
            }
        )
    }

    private var deskCameraSelection: Binding<String> {
        Binding(
            get: { appState.selectedCamera?.id ?? "" },
            set: { newId in
                if let selected = cameraMonitor.availableCameras.first(where: { $0.id == newId }) {
                    appState.selectedCamera = StoredCameraInfo(id: selected.id, name: selected.name)
                }
            }
        )
    }

    /// A setting that belongs to the toggle above it: indented under a corner and dimmed.
    private func subsettingLabel(_ title: String) -> some View {
        Text("   └ \(title)")
            .foregroundStyle(.secondary)
    }

    /// Cameras to list in a picker: the connected ones, plus the chosen one if it is unplugged.
    @ViewBuilder
    private func cameraOptions(chosen: StoredCameraInfo?) -> some View {
        ForEach(cameraMonitor.availableCameras) { camera in
            Text(camera.name).tag(camera.id)
        }
        if let chosen, !isConnected(chosen) {
            Text("\(chosen.name) (not connected)").tag(chosen.id)
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Devices:")
                .font(.headline)
            if readyDevices.isEmpty {
                Text("No devices found")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(readyDevices, id: \.id) { device in
                    DeviceRow(device: device)
                }
            }

            Divider()

            Toggle("Lights on with Camera", isOn: $appState.lightsOnWithCamera)
            if appState.lightsOnWithCamera {
                Menu {
                    Picker("Camera", selection: triggerCameraSelection) {
                        Text("Any camera").tag("")
                        cameraOptions(chosen: appState.triggerCamera)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } label: {
                    subsettingLabel(triggerCameraTitle)
                }
            }

            Toggle("Lights off on Sleep", isOn: $appState.lightsOffOnSleep)
            if appState.lightsOffOnSleep, appState.wakeOnCameraDetectionEnabled {
                Menu {
                    Picker("Desk camera", selection: deskCameraSelection) {
                        cameraOptions(chosen: appState.selectedCamera)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()

                    Divider()

                    Button("Always turn back on") {
                        appState.wakeOnCameraDetectionEnabled = false
                        appState.selectedCamera = nil
                    }
                } label: {
                    subsettingLabel(deskCameraTitle)
                }
            }
            Toggle("Sync with Night Shift", isOn: $appState.syncWithNightShift)

            Divider()

            Button("Check for Updates...", action: checkForUpdates)
            Group {
                if #available(macOS 14.0, *) {
                    SettingsLink {
                        Text("Settings...")
                    } preAction: {
                        NSApp.activate(ignoringOtherApps: true)
                    } postAction: {}
                } else {
                    Button(action: {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    }, label: {
                        Text("Settings...")
                    })
                }
            }
            .keyboardShortcut(",", modifiers: .command)
            Button("Export Debug Logs", action: exportLogs)

            Divider()

            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                .foregroundColor(.secondary)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("Q", modifiers: .command)
        }
        .padding()
        .frame(width: 250)
    }

    func checkForUpdates() {
        updateChecker.checkForNewRelease { isNewVersionAvailable, latestVersion in
            DispatchQueue.main.async {
                if isNewVersionAvailable, let version = latestVersion {
                    updateChecker.promptForUpdate(newVersion: version)
                } else {
                    updateChecker.promptForNoUpdate()
                }
            }
        }
    }

    func exportLogs() {
        if let fileURL = writeLogsToTemp() {
            NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: "")
        }
    }
}
