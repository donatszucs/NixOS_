//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import QtQuick

import "./elements"

Scope {
    IpcHandler {
        target: "vram"
        function toggle(): void { SharedState.toggleVramSavingMode() }
        function enable(): void { SharedState.enterVramSavingMode() }
        function disable(): void { SharedState.exitVramSavingMode() }
        function status(): bool { return SharedState.vramSavingMode }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Bar {}
        }
    }
}
