import QtQuick
import qs.Common

// Blocks plugin activation when the QMLTermWidget module (qmltermwidget
// package) is not installed, so the plugin fails gracefully instead of
// rendering empty windows. Synchronous variant of the DMS startupCheck API.
QtObject {
    id: root

    function check() {
        let obj = null
        try {
            obj = Qt.createQmlObject('import QMLTermWidget 2.0; QMLTermSession {}', root, "qmltermwidget-probe")
        } catch (e) {
            obj = null
        }
        if (obj) {
            obj.destroy()
            return null
        }
        return {
            "title": "QMLTermWidget is required",
            "details": "The 'qmltermwidget' package provides the QMLTermWidget / QMLTermSession types this plugin renders.\n\nInstall it (on Arch: 'qmltermwidget' from the AUR), then re-enable the Dropdown Terminal plugin."
        }
    }
}
