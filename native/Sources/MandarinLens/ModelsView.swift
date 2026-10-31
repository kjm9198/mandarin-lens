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
            VStack(alignment: .leading,spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading,spacing: 7) { Text("Local AI").font(.system(size: 28,weight: .semibold,design: .rounded)); Text("Choose a model for your conversations and learning recaps.").font(.body).foregroundStyle(.secondary) }
                    Spacer()
                    if !embedded { Button("Done") { dismiss() }.controlSize(.small) }
                }
                HStack(spacing: 12) {
                    Image(systemName: "desktopcomputer").font(.title2).foregroundStyle(.teal)
                    VStack(alignment: .leading,spacing: 4) { Text(models.active?.displayName ?? "Choose a model to get started").font(.headline).lineLimit(2); Text(models.busy ? "Working on your Mac…" : models.workerModel != nil ? "Loaded in memory · ready for another question" : "Loads when you ask a question").font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    if models.workerModel != nil { Button("Unload") { models.unloadModel() }.disabled(models.busy).controlSize(.small).help("Release the resident model; keep its downloaded files") }
                }.padding(18).background(.teal.opacity(0.08),in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading,spacing: 12) {
                    HStack { Text("On this Mac").font(.title3.weight(.semibold)); Spacer(); Text(ByteCountFormatter.string(fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory),countStyle: .memory) + " memory").font(.caption).foregroundStyle(.secondary) }
                    modelCard(title: "Automatic",subtitle: models.automatic.map { "Uses the smallest installed model: \($0.displayName)" } ?? "Selects the smallest installed chat model",selected: models.selected == "auto",symbol: "sparkles") { models.selected = "auto" }
                    if installed.isEmpty { Label("No MLX chat model installed yet. Download one below, or add an existing folder.",systemImage: "arrow.down.circle").font(.callout).foregroundStyle(.secondary).padding(.vertical,8) }
                    ForEach(installed) { model in modelCard(title: model.displayName,subtitle: model.detail + (model.heavy ? " · needs more memory headroom" : ""),selected: models.selected == model.id,symbol: "cpu") { models.selected = model.id } }
                    HStack { Button("Find models") { Task { await models.scanFiles() } }; Button("Add folder…") { models.addFolder() }; Spacer() }.controlSize(.small)
                }
                VStack(alignment: .leading,spacing: 14) {
                    Text("Add a model").font(.title3.weight(.semibold))
                    if !models.runtimeAvailable {
                        HStack(alignment: .top,spacing: 12) { Image(systemName: "shippingbox").foregroundStyle(.teal); VStack(alignment: .leading,spacing: 5) { Text("Set up the local runtime").fontWeight(.medium); Text("One-time Python package download from PyPI. It stays separate from your model files.").font(.caption).foregroundStyle(.secondary); Button("Install local runtime") { Task { await models.installRuntime() } }.disabled(models.installing) } }.padding(16).background(.quaternary.opacity(0.45),in: RoundedRectangle(cornerRadius: 12))
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top,spacing: 12) { downloadCard("Light & quick",name: "Qwen 3.5 · 2B",size: "About 2 GB",id: "Qwen3.5-2B-4bit"); downloadCard("More room to think",name: "Qwen 3.5 · 4B",size: "About 3 GB",id: "Qwen3.5-4B-4bit") }
                        VStack(spacing: 12) { downloadCard("Light & quick",name: "Qwen 3.5 · 2B",size: "About 2 GB",id: "Qwen3.5-2B-4bit"); downloadCard("More room to think",name: "Qwen 3.5 · 4B",size: "About 3 GB",id: "Qwen3.5-4B-4bit") }
                    }
                    HStack { Image(systemName: "waveform").foregroundStyle(.teal); VStack(alignment: .leading,spacing: 3) { Text("Offline speaking practice").fontWeight(.medium); Text("Whisper small · about 500 MB").font(.caption).foregroundStyle(.secondary) }; Spacer(); if models.speechAvailable { Label("Installed",systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.teal) } else { Button("Download speech") { Task { await models.installModel("whisper-small-asr-fp16") } }.controlSize(.small).disabled(models.installing || !models.runtimeAvailable) } }.padding(16).background(.quaternary.opacity(0.4),in: RoundedRectangle(cornerRadius: 12))
                    if models.installing { HStack { ProgressView().controlSize(.small); Text("Download or setup in progress…").font(.caption); Spacer(); Button("Cancel") { models.installJob?.cancel() }.controlSize(.small) } }
                    Text("Model downloads come from Hugging Face. Your words and questions are not sent with them. Apple Translation works independently of these AI models.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false,vertical: true)
                }
                if !models.status.isEmpty { Label(models.status,systemImage: "info.circle").font(.callout).foregroundStyle(.secondary).textSelection(.enabled).fixedSize(horizontal: false,vertical: true) }
                DisclosureGroup(isExpanded: $advanced) {
                    VStack(alignment: .leading,spacing: 14) {
                        Text("Use a model served by LM Studio or Bionic on this Mac. Downloaded GGUF files need one of these servers.").font(.caption).foregroundStyle(.secondary)
                        HStack { Text("Local port").font(.callout); TextField("1234",value: $models.port,format: .number.grouping(.never)).frame(width: 90).textFieldStyle(.roundedBorder); Button("Connect") { Task { await models.refreshServer() } } }.controlSize(.small)
                        HStack { SecureField("Optional API token",text: $token).textFieldStyle(.roundedBorder); Button("Save token") { models.saveToken(token); token = "" } }.controlSize(.small)
                        ForEach(servers) { model in modelCard(title: model.displayName,subtitle: model.detail,selected: models.selected == model.id,symbol: model.id.hasPrefix("catalog:") ? "externaldrive" : "network") { models.selected = model.id }.disabled(model.id.hasPrefix("catalog:")) }
                        Text("Only 127.0.0.1 is accepted. Tokens stay in Keychain.").font(.caption).foregroundStyle(.secondary)
                    }.padding(.top,16)
                } label: { Label("Local server & advanced",systemImage: "network").fontWeight(.medium) }.padding(17).background(.quaternary.opacity(0.3),in: RoundedRectangle(cornerRadius: 13))
            }.padding(embedded ? 28 : 22).frame(maxWidth: 840,alignment: .leading).frame(maxWidth: .infinity,alignment: .topLeading)
        }.frame(width: embedded ? nil : 620,height: embedded ? nil : 650).tint(.teal).onExitCommand { if !embedded { dismiss() } }
    }
    private func modelCard(title: String,subtitle: String,selected: Bool,symbol: String,action: @escaping ()->Void) -> some View {
        Button(action: action) { HStack(alignment: .center,spacing: 12) { Image(systemName: symbol).font(.title3).foregroundStyle(.teal).frame(width: 32); VStack(alignment: .leading,spacing: 5) { Text(title).font(.system(size: 14,weight: .semibold)).foregroundStyle(.primary); Text(subtitle).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false,vertical: true) }; Spacer(minLength: 8); Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(selected ? Color.teal : .secondary) }.padding(15).frame(maxWidth: .infinity,alignment: .leading).background(selected ? Color.teal.opacity(0.09) : Color.primary.opacity(0.035),in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Color.teal.opacity(0.6) : Color.primary.opacity(0.07),lineWidth: 1)) }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
    private func downloadCard(_ label: String,name: String,size: String,id: String) -> some View {
        VStack(alignment: .leading,spacing: 9) { Text(label).font(.caption.weight(.semibold)).foregroundStyle(.teal); Text(name).font(.headline); Text(size).font(.caption).foregroundStyle(.secondary); Button("Download \(name)") { Task { await models.installModel(id) } }.controlSize(.small).disabled(models.installing || !models.runtimeAvailable) }.frame(maxWidth: .infinity,alignment: .leading).padding(17).background(.quaternary.opacity(0.45),in: RoundedRectangle(cornerRadius: 13))
    }
}
