import SwiftUI

@main
enum Main {
    @MainActor
    static func main() {
        // Breather --snapshot <目录>：把各个界面渲染成 PNG，用于检查 UI
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "--snapshot"), index + 1 < args.count {
            Snapshot.run(outputDirectory: URL(fileURLWithPath: args[index + 1]))
            return
        }
        BreatherApp.main()
    }
}

struct BreatherApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
