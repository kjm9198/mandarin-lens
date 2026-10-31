import SwiftUI

struct ModelsView: View {
    var embedded = false
    @ObservedObject var models: LocalModels
    @Environment(\.dismiss) private var dismiss
    @State private var token = ""
    @State private var advanced = false
    private var installed: [LocalModel] { models.models.filter { !$0.server } }
    private var servers: [LocalModel] { models.models.filter { $0.server } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading,spacing: 26) {
                HStack(alignment: .top) { LensPageHeading(title: "Local models",detail: "For Chinese examples, conversations and learning recaps."); if !embedded { Button("Done") { dismiss() }.buttonStyle(LensButtonStyle(small: true)) } }
                HStack(spacing: 12) {
                    Circle().fill(Color.lensAccent).frame(width: 7,height: 7)
                    VStack(alignment: .leading,spacing: 5) { Text(models.active?.displayName ?? "No model selected").font(.system(size: 14,weight: .medium)); Text(models.busy ? "Working…" : models.workerModel != nil ? "Loaded and ready" : "Loads when needed").font(.system(size: 12)).foregroundStyle(.secondary) }
                    Spacer(minLength: 6)
                    if models.workerModel != nil { Button("Unload") { models.unloadModel() }.buttonStyle(LensButtonStyle(small: true)).disabled(models.busy).help("Release memory and keep downloaded files") }
                }.padding(.vertical,4)
                VStack(alignment: .leading,spacing: 12) {
                    HStack { Text("Available on this Mac").font(.system(size: 14,weight: .semibold)); Spacer(); Text(ByteCountFormatter.string(fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory),countStyle: .memory)+" memory").font(.system(size: 11)).foregroundStyle(.secondary) }
                    VStack(spacing: 2) {
                        modelRow("Automatic",detail: models.automatic.map { "Smallest installed model · \($0.displayName)" } ?? "Uses the smallest installed chat model",selected: models.selected == "auto") { models.selected = "auto" }
                        ForEach(installed) { model in modelRow(model.displayName,detail: model.detail+(model.heavy ? " · more memory required" : ""),selected: models.selected == model.id) { models.selected = model.id } }
                    }.lensSurface(padding: 7)
                    if installed.isEmpty { Text("Download a model below, or add a model folder you already have.").font(.system(size: 12)).foregroundStyle(.secondary) }
                    HStack { Button("Find models") { Task { await models.scanFiles() } }; Button("Add folder…") { models.addFolder() }; Spacer() }.buttonStyle(LensButtonStyle(small: true))
                }
                VStack(alignment: .leading,spacing: 14) {
                    Text("Downloads").font(.system(size: 14,weight: .semibold))
                    if !models.runtimeAvailable {
                        VStack(alignment: .leading,spacing: 10) { Label("Local runtime required",systemImage: "shippingbox").font(.system(size: 13,weight: .medium)); Text("One-time Python package setup from PyPI. Requires Python 3.10 or later.").font(.system(size: 12)).foregroundStyle(.secondary); Button("Install local runtime") { Task { await models.installRuntime() } }.buttonStyle(LensButtonStyle(small: true)).disabled(models.installing) }.frame(maxWidth: .infinity,alignment: .leading).lensSurface()
                    }
                    VStack(spacing: 0) {
                        downloadRow("Qwen 3.5 · 2B",detail: "About 2 GB · everyday examples and chat",id: "Qwen3.5-2B-4bit")
                        Divider()
                        downloadRow("Qwen 3.5 · 4B",detail: "About 3 GB · larger chat model",id: "Qwen3.5-4B-4bit")
                        Divider()
                        HStack(spacing: 12) { Image(systemName: "waveform").foregroundStyle(.secondary).frame(width: 22); VStack(alignment: .leading,spacing: 5) { Text("Whisper small").font(.system(size: 13,weight: .medium)); Text("About 500 MB · offline speech recognition").font(.system(size: 11)).foregroundStyle(.secondary) }; Spacer(minLength: 8); if models.speechAvailable { Label("Installed",systemImage: "checkmark").font(.system(size: 11)).foregroundStyle(Color.lensAccent) } else { Button("Download speech") { Task { await models.installModel("whisper-small-asr-fp16") } }.buttonStyle(LensButtonStyle(small: true)).disabled(models.installing || !models.runtimeAvailable) } }.padding(.vertical,17)
                    }.padding(.horizontal,18).lensSurface(padding: 0)
                    if models.installing { HStack { ProgressView().controlSize(.small); Text("Download or setup in progress…").font(.system(size: 12)); Spacer(); Button("Cancel") { models.installJob?.cancel() }.buttonStyle(LensButtonStyle(small: true)) } }
                    Text("Downloads use Hugging Face. Your words and questions stay on this Mac. Translation and games work without an AI model.").font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false,vertical: true).lineSpacing(3)
                }
                if !models.status.isEmpty { Label(models.status,systemImage: "info.circle").font(.system(size: 12)).foregroundStyle(.secondary).textSelection(.enabled).fixedSize(horizontal: false,vertical: true) }
                Divider()
                DisclosureGroup(isExpanded: $advanced) {
                    VStack(alignment: .leading,spacing: 16) {
                        Text("Connect LM Studio or Bionic running on this Mac. Downloaded GGUF models need a compatible server.").font(.system(size: 12)).foregroundStyle(.secondary)
                        HStack { Text("Local port").font(.system(size: 12)); TextField("1234",value: $models.port,format: .number.grouping(.never)).frame(width: 80).textFieldStyle(.roundedBorder); Spacer(); Button("Connect") { Task { await models.refreshServer() } }.buttonStyle(LensButtonStyle(small: true)) }
                        HStack { SecureField("Optional API token",text: $token).textFieldStyle(.roundedBorder); Button("Save token") { models.saveToken(token); token = "" }.buttonStyle(LensButtonStyle(small: true)) }
                        ForEach(servers) { model in modelRow(model.displayName,detail: model.detail,selected: models.selected == model.id) { models.selected = model.id }.disabled(model.id.hasPrefix("catalog:")) }
                        Text("Only 127.0.0.1 is accepted. Tokens stay in Keychain.").font(.system(size: 11)).foregroundStyle(.secondary)
                    }.padding(.top,18)
                } label: { Text("Local server & advanced").font(.system(size: 13,weight: .medium)) }
            }.padding(28).frame(maxWidth: 820,alignment: .leading).frame(maxWidth: .infinity,alignment: .topLeading)
        }.background(Color.lensCanvas).frame(width: embedded ? nil : 650,height: embedded ? nil : 660).tint(.lensAccent).onExitCommand { if !embedded { dismiss() } }
    }
    private func modelRow(_ title: String,detail: String,selected: Bool,action: @escaping ()->Void) -> some View {
        Button(action: action) { HStack(spacing: 12) { Image(systemName: selected ? "largecircle.fill.circle" : "circle").font(.system(size: 17)).foregroundStyle(selected ? Color.lensAccent : .secondary); VStack(alignment: .leading,spacing: 5) { Text(title).font(.system(size: 13,weight: .medium)); Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false,vertical: true) }; Spacer(minLength: 0) }.padding(12).frame(maxWidth: .infinity,alignment: .leading).contentShape(Rectangle()) }.buttonStyle(LensRowStyle(selected: selected)).accessibilityAddTraits(selected ? .isSelected : [])
    }
    private func downloadRow(_ name: String,detail: String,id: String) -> some View {
        HStack(spacing: 12) { Image(systemName: "cpu").foregroundStyle(.secondary).frame(width: 22); VStack(alignment: .leading,spacing: 5) { Text(name).font(.system(size: 13,weight: .medium)); Text(detail).font(.system(size: 11)).foregroundStyle(.secondary) }; Spacer(minLength: 8); Button("Download") { Task { await models.installModel(id) } }.buttonStyle(LensButtonStyle(small: true)).disabled(models.installing || !models.runtimeAvailable).accessibilityLabel("Download \(name)") }.padding(.vertical,17)
    }
}
