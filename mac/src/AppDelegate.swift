import AppKit

/// Delegate dell'applicazione: avvia il Controller e gestisce le modalità diagnostiche,
/// equivalente alla parte "non-diagnostica" di Program.Main in Program.cs.
class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: Controller!
    private let background: Bool
    private var showObserver: NSObjectProtocol?

    init(background: Bool) {
        self.background = background
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Nessuna icona nel Dock, nessuna voce nel menu Applicazioni: solo status bar (ShowInTaskbar=false).
        NSApp.setActivationPolicy(.accessory)
        Theme.apply()
        controller = Controller()

        showObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(SingleInstance.showNotificationName), object: nil, queue: .main
        ) { [weak self] _ in
            self?.controller.flyout.showFlyout()
        }

        guard !background else { return }
        // breve attesa: la status item riceve la sua posizione nella barra dei menu solo dopo
        // il primo ciclo di layout, e il pannello si ancora a quella
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.controller.flyout.showFlyout()
            if Program.debugOn { self.controller.demo(ProcessInfo.processInfo.environment["NETSWITCH_DEMO"]) }
            // NETSWITCH_SNAP=file.png: salva un'immagine del pannello ed esce
            if Program.debugOn, let snap = ProcessInfo.processInfo.environment["NETSWITCH_SNAP"], !snap.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    self.controller.snap(snap)
                    self.controller.exitApp()
                }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Riapertura dal Finder/Launchpad/`open` mentre l'app è già attiva: riapre il pannello
    /// (come rilanciare l'exe su Windows).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller.flyout.showFlyout()
        return false
    }

    deinit {
        if let o = showObserver { DistributedNotificationCenter.default().removeObserver(o) }
    }
}
