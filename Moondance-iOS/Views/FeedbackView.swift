import SwiftUI
import MessageUI
import MachO

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    // Current app state for debugging
    let selectedTarget: Target?
    let selectedLocation: Location?
    let startDate: Date
    let observationTime: Date
    let screenshot: UIImage?
    var targetCount: Int = 0
    var maxTargets: Int = 0
    var dateRangeDays: Int = 0
    var calculationDays: Int = 0

    @State private var problemDescription = ""
    @State private var showMailComposer = false
    @State private var showMailError = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $problemDescription)
                        .frame(minHeight: 120)
                } header: {
                    Text("Describe the problem")
                } footer: {
                    Text("Please provide as much detail as you can.")
                }

                if let screenshot = screenshot {
                    Section("Screenshot Preview") {
                        Image(uiImage: screenshot)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Debug info included:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(deviceInfoSummary)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    sendFeedback()
                } label: {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Send Report")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(problemDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Report a Problem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showMailComposer) {
                MailComposerView(
                    subject: "Moondance Bug Report",
                    body: emailBody,
                    attachments: mailAttachments,
                    recipient: "seetheshow87@gmail.com",
                    onFinish: { dismiss() }
                )
            }
            .alert("Cannot Send Email", isPresented: $showMailError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please configure an email account in Settings to send bug reports.")
            }
        }
    }

    // MARK: - Device Info

    private var deviceInfoSummary: String {
        let mem = appMemoryUsage
        return "\(deviceModelName) • iOS \(UIDevice.current.systemVersion) • Mem: \(mem.footprint) • \(selectedTarget?.name ?? "No target") • \(selectedLocation?.name ?? "No location")"
    }

    private var deviceInfo: String {
        let device = UIDevice.current
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        let mem = appMemoryUsage

        let totalRAM = ProcessInfo.processInfo.physicalMemory
        let totalGB = String(format: "%.1f GB", Double(totalRAM) / 1_073_741_824)

        return """
        Device: \(deviceModelName)
        iOS Version: \(device.systemVersion)
        App Version: \(appVersion) (\(buildNumber))
        Device RAM: \(totalGB)
        Memory Used: \(mem.used)
        Memory Footprint: \(mem.footprint)
        Max Date Range: \(DeviceLimits.maxDateRange) days
        """
    }

    /// Returns the app's current memory usage via Mach task info
    private var appMemoryUsage: (used: String, footprint: String) {
        // Resident memory (phys_footprint is the most accurate for "real" usage)
        var info = mach_task_basic_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info_data_t>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        let usedMB: String
        if result == KERN_SUCCESS {
            usedMB = String(format: "%.1f MB", Double(info.resident_size) / 1_048_576)
        } else {
            usedMB = "unavailable"
        }

        // Task memory footprint (phys_footprint — more accurate on iOS)
        var taskInfo = task_vm_info_data_t()
        var taskCount = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size) / 4
        let vmResult = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(taskCount)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &taskCount)
            }
        }

        let footprintMB: String
        if vmResult == KERN_SUCCESS {
            footprintMB = String(format: "%.1f MB", Double(taskInfo.phys_footprint) / 1_048_576)
        } else {
            footprintMB = "unavailable"
        }

        return (usedMB, footprintMB)
    }

    private var deviceModelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        return modelCode ?? UIDevice.current.model
    }

    // MARK: - Settings Info

    private var settingsInfo: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        return """
        Target: \(selectedTarget?.name ?? "None")
        Target RA: \(selectedTarget?.ra ?? 0)°
        Target Dec: \(selectedTarget?.dec ?? 0)°
        Targets Selected: \(targetCount) of \(maxTargets) max
        Date Range: \(dateRangeDays) days
        Days Calculated: \(calculationDays)
        Location: \(selectedLocation?.name ?? "None")
        Latitude: \(selectedLocation?.lat ?? 0)°
        Longitude: \(selectedLocation?.lon ?? 0)°
        Elevation: \(selectedLocation?.elevation ?? 0)m
        Timezone: \(selectedLocation?.timezone ?? "Unknown")
        Start Date: \(dateFormatter.string(from: startDate))
        Observation Time: \(timeFormatter.string(from: observationTime))
        """
    }

    // MARK: - Email

    private var emailBody: String {
        let description = problemDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let userNote = description.isEmpty ? "(No description provided)" : description

        return """
        Problem Description:
        \(userNote)

        ─────────────────────
        DEBUG INFORMATION
        ─────────────────────

        \(deviceInfo)

        \(settingsInfo)
        """
    }

    private var mailAttachments: [(Data, String, String)] {
        var attachments: [(Data, String, String)] = []

        if let screenshot = screenshot, let imageData = screenshot.jpegData(compressionQuality: 0.8) {
            attachments.append((imageData, "image/jpeg", "screenshot.jpg"))
        }

        return attachments
    }

    private func sendFeedback() {
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
        } else {
            showMailError = true
        }
    }
}

// MARK: - Mail Composer

struct MailComposerView: UIViewControllerRepresentable {
    let subject: String
    let body: String
    let attachments: [(Data, String, String)] // (data, mimeType, filename)
    let recipient: String
    var onFinish: () -> Void = {}

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients([recipient])
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)

        for (data, mimeType, filename) in attachments {
            composer.addAttachmentData(data, mimeType: mimeType, fileName: filename)
        }

        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true) {
                self.onFinish()
            }
        }
    }
}
