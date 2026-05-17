import SwiftUI
import AppKit

struct FilesTabView: View {
    @ObservedObject var vm: NotchViewModel
    var body: some View {
        if vm.droppedFiles.isEmpty {
            DropZone(targeted: vm.isDragTargeted)
        } else {
            VStack(spacing: 0) {
                HStack {
                    Text("파일 \(vm.droppedFiles.count)개").font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.35))
                    Spacer()
                    Button(action: vm.clearFiles) {
                        Text("모두 지우기").font(.system(size: 10)).foregroundColor(.white.opacity(0.3))
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 6)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 3) {
                        ForEach(vm.droppedFiles) { file in
                            FileRow(file: file, vm: vm)
                        }
                    }
                    .padding(.horizontal, 12).padding(.bottom, 8)
                }
            }
        }
    }
}

struct DropZone: View {
    let targeted: Bool
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(targeted ? Color.blue.opacity(0.8) : Color.white.opacity(0.15),
                                  style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .frame(width: 200, height: 80)
                VStack(spacing: 6) {
                    Image(systemName: targeted ? "arrow.down.circle.fill" : "square.and.arrow.down")
                        .font(.system(size: targeted ? 28 : 22))
                        .foregroundColor(targeted ? .blue.opacity(0.9) : .white.opacity(0.3))
                    Text(targeted ? "여기에 놓으세요" : "파일을 여기로 드래그")
                        .font(.system(size: 11))
                        .foregroundColor(targeted ? .blue.opacity(0.9) : .white.opacity(0.35))
                }
            }
            .animation(.spring(response: 0.25), value: targeted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FileRow: View {
    let file: DroppedFile
    @ObservedObject var vm: NotchViewModel
    @State private var hovered = false
    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let icon = file.icon {
                    Image(nsImage: icon).resizable().scaledToFit()
                } else {
                    Image(systemName: "doc").font(.system(size: 18)).foregroundColor(.white.opacity(0.4))
                }
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name).font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.85)).lineLimit(1)
                Text(file.sizeString).font(.system(size: 9)).foregroundColor(.white.opacity(0.3))
            }
            Spacer()
            if hovered {
                HStack(spacing: 4) {
                    FBtn("arrow.up.forward.app") { vm.openFile(file) }
                    FBtn("folder")              { vm.revealFile(file) }
                    FBtn("xmark")               { vm.removeFile(file) }
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(hovered ? Color.white.opacity(0.07) : Color.clear))
        .onHover { hovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: hovered)
        .onDrag {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { vm.removeFile(file) }
            return NSItemProvider(contentsOf: file.url) ?? NSItemProvider()
        }
    }

    private func FBtn(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 10.5)).foregroundColor(.white.opacity(0.55))
                .frame(width: 22, height: 22).background(Circle().fill(Color.white.opacity(0.08))).contentShape(Circle())
        }.buttonStyle(.plain)
    }
}
