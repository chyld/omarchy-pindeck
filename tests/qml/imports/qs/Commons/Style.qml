pragma Singleton
import QtQuick
QtObject {
    function space(value) { return value }
    property QtObject font: QtObject {
        property string family: "sans-serif"
        property real body: 12
        property real bodySmall: 11
    }
}
