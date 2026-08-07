import QtQuick
import qs.Common
import qs.Modules.Plugins

PluginSettings {
    pluginId: "dropdownTerminal"

    SelectionSetting {
        settingKey: "slideEdge"
        label: I18n.tr("Slide edge")
        description: I18n.tr("Which screen edge the terminal slides in from")
        options: [
            { label: I18n.tr("Right"), value: "right" },
            { label: I18n.tr("Left"), value: "left" },
            { label: I18n.tr("Top"), value: "top" },
            { label: I18n.tr("Bottom"), value: "bottom" }
        ]
        defaultValue: "right"
    }

    SelectionSetting {
        settingKey: "defaultSize"
        label: I18n.tr("Default size")
        description: I18n.tr("Whether a freshly opened terminal starts small or large. F11 (or the header button) toggles it per session; changing this setting does not resize an already-open terminal.")
        options: [
            { label: I18n.tr("Small"), value: "small" },
            { label: I18n.tr("Large"), value: "large" }
        ]
        defaultValue: "small"
    }

    SliderSetting {
        settingKey: "smallWidth"
        label: I18n.tr("Small width")
        description: I18n.tr("Width when using the left or right edge; clamped to the active screen")
        minimum: 300
        maximum: 1200
        defaultValue: 520
        unit: " px"
    }

    SliderSetting {
        settingKey: "expandedWidth"
        label: I18n.tr("Expanded width")
        description: I18n.tr("Expanded width when using the left or right edge; never smaller than the configured small width")
        minimum: 400
        maximum: 1800
        defaultValue: 900
        unit: " px"
    }

    SliderSetting {
        settingKey: "smallHeight"
        label: I18n.tr("Small height")
        description: I18n.tr("Height when using the top or bottom edge; clamped to the active screen")
        minimum: 300
        maximum: 900
        defaultValue: 480
        unit: " px"
    }

    SliderSetting {
        settingKey: "expandedHeight"
        label: I18n.tr("Expanded height")
        description: I18n.tr("Expanded height when using the top or bottom edge; never smaller than the configured small height")
        minimum: 400
        maximum: 1400
        defaultValue: 760
        unit: " px"
    }

    ToggleSetting {
        settingKey: "showHeader"
        label: I18n.tr("Show header")
        description: I18n.tr("Show the Terminal title, expand button, and close button")
        defaultValue: true
    }

    SliderSetting {
        settingKey: "terminalOpacity"
        label: I18n.tr("Terminal opacity")
        description: I18n.tr("Background opacity. With the optional patched QMLTermWidget, terminal text remains fully opaque; the stock package fades the whole terminal.")
        minimum: 40
        maximum: 100
        defaultValue: 85
        unit: "%"
    }

    ToggleSetting {
        settingKey: "cursorBlink"
        label: I18n.tr("Blinking cursor")
        description: I18n.tr("Whether the terminal text cursor blinks")
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "copyOnSelect"
        label: I18n.tr("Copy on select")
        description: I18n.tr("Immediately copy selected terminal text to the clipboard")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "rightClickPaste"
        label: I18n.tr("Right-click paste")
        description: I18n.tr("Paste clipboard contents directly with the right mouse button")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "escapeToClose"
        label: I18n.tr("Escape closes the terminal")
        description: I18n.tr("Close the slideout with Escape while the shell prompt is idle. Running programs that use Escape (vim, less, ...) still receive it.")
        defaultValue: true
    }

    StringSetting {
        settingKey: "terminalColorScheme"
        label: I18n.tr("Terminal color scheme")
        description: I18n.tr("Name of a QMLTermWidget .colorscheme file. 'dankcolors' is generated from the DMS theme; if it is unavailable a built-in scheme is used instead.")
        placeholder: "dankcolors"
        defaultValue: "dankcolors"
    }

    StringSetting {
        settingKey: "terminalFont"
        label: I18n.tr("Terminal font family")
        description: I18n.tr("Fixed-width font for the terminal. Leave empty to use the DMS mono font.")
        placeholder: I18n.tr("DMS mono font (default)")
        defaultValue: ""
    }

    SliderSetting {
        settingKey: "terminalFontSize"
        label: I18n.tr("Terminal font size")
        description: I18n.tr("Terminal text size in points")
        minimum: 8
        maximum: 24
        defaultValue: 12
        unit: " pt"
    }

}
