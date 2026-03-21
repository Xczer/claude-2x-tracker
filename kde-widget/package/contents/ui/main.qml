import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore

Item {
    id: root

    // Preferred widget size — compact, matching tray app
    implicitWidth: 340
    implicitHeight: 140

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // ── Status state ──
    property int currentStatus: 0  // 0=active, 1=blocked, 2=weekend
    property string statusLabel: "2\u00d7 ACTIVE"
    property string statusSublabel: "smash those prompts"
    property string countdownText: ""
    property real nowFraction: 0.0
    property real glowPhase: 0.0
    property real pulseScale: 1.0
    property bool appeared: false

    // Calendar day model
    property var calendarDays: []

    // ── Colors ──
    readonly property color activeGreen: "#4ADE80"
    readonly property color activeGreenDark: "#22C55E"
    readonly property color blockedRed: "#F87171"
    readonly property color blockedRedDark: "#DC2626"
    readonly property color weekendGray: "#6B7280"
    readonly property color accentOrange: "#C96442"
    readonly property color baseBg: "#0F0D0B"
    readonly property color cardBg: Qt.rgba(0.071, 0.063, 0.055, 0.96)

    property color statusColor: activeGreen
    property color statusColorDark: activeGreenDark

    // ── Animated blob phases ──
    property real blobPhase1: 0.0
    property real blobPhase2: 0.5

    // ── Local timezone with ET-converted blocked window ──
    // Peak window: 8 AM - 2 PM ET. Convert to local timezone for display.
    // Weekday check uses local timezone (Monday is Monday for you).

    // Compute local blocked window (ET → local) on init
    property int localBlockStart: {
        var now = new Date();
        var utcOffsetMin = -now.getTimezoneOffset(); // local UTC offset in minutes
        var etOffsetMin = -4 * 60; // EDT = UTC-4 (March 2026)
        var diffMin = utcOffsetMin - etOffsetMin;
        return (480 + diffMin + 1440) % 1440; // 480 = 8*60 (8 AM ET)
    }
    property int localBlockEnd: {
        var now = new Date();
        var utcOffsetMin = -now.getTimezoneOffset();
        var etOffsetMin = -4 * 60;
        var diffMin = utcOffsetMin - etOffsetMin;
        return (840 + diffMin + 1440) % 1440; // 840 = 14*60 (2 PM ET)
    }

    function formatTimeLabel(minutes) {
        var h = Math.floor(minutes / 60);
        var m = minutes % 60;
        var suffix = h >= 12 ? "PM" : "AM";
        var h12 = h === 0 ? 12 : (h > 12 ? h - 12 : h);
        if (m === 0) return h12 + " " + suffix;
        return h12 + ":" + (m < 10 ? "0" : "") + m + " " + suffix;
    }

    function computeStatus() {
        var now = new Date(); // local time
        var minutesNow = now.getHours() * 60 + now.getMinutes() + now.getSeconds() / 60.0;
        var dayOfWeek = now.getDay(); // 0=Sun, 6=Sat (local)
        var isWeekend = (dayOfWeek === 0 || dayOfWeek === 6);

        // Now fraction in LOCAL time
        nowFraction = minutesNow / 1440.0;

        // Check blocked in local time
        var isBlocked = false;
        if (localBlockStart < localBlockEnd) {
            isBlocked = minutesNow >= localBlockStart && minutesNow < localBlockEnd;
        } else {
            isBlocked = minutesNow >= localBlockStart || minutesNow < localBlockEnd;
        }

        if (isWeekend) {
            currentStatus = 2;
            statusLabel = "WEEKEND";
            statusSublabel = "enjoy the weekend";
            statusColor = weekendGray;
            statusColorDark = "#4B5563";
        } else if (isBlocked) {
            currentStatus = 1;
            statusLabel = "BLOCKED";
            statusSublabel = "standard limits";
            statusColor = blockedRed;
            statusColorDark = blockedRedDark;
        } else {
            currentStatus = 0;
            statusLabel = "2\u00d7 ACTIVE";
            statusSublabel = "smash those prompts";
            statusColor = activeGreen;
            statusColorDark = activeGreenDark;
        }

        computeCountdown(minutesNow, dayOfWeek, isWeekend, isBlocked);
    }

    function computeCountdown(minutesNow, dayOfWeek, isWeekend, isBlocked) {
        var bs = localBlockStart;
        var be = localBlockEnd;

        if (isWeekend) {
            var toMidnight = 1440 - minutesNow;
            var total = (dayOfWeek === 6) ? toMidnight + 1440 : toMidnight;
            var h = Math.floor(total / 60);
            var m = Math.floor(total % 60);
            countdownText = h > 0 ? "Next 2\u00d7 in " + h + "h " + m + "m" : "Next 2\u00d7 in " + m + "m";
        } else if (isBlocked) {
            var rem;
            if (bs < be) {
                rem = be - minutesNow;
            } else {
                rem = (minutesNow >= bs) ? (1440 - minutesNow + be) : (be - minutesNow);
            }
            var h2 = Math.floor(rem / 60);
            var m2 = Math.floor(rem % 60);
            countdownText = h2 > 0 ? "Next 2\u00d7 in " + h2 + "h " + m2 + "m" : "Next 2\u00d7 in " + m2 + "m";
        } else {
            var rem2;
            if (bs < be) {
                rem2 = (minutesNow < bs) ? (bs - minutesNow) : (1440 - minutesNow + bs);
                if (dayOfWeek === 5 && minutesNow >= be) {
                    rem2 = 1440 - minutesNow; // Friday after block → weekend
                }
            } else {
                rem2 = bs - minutesNow;
            }
            var h3 = Math.floor(rem2 / 60);
            var m3 = Math.floor(rem2 % 60);
            countdownText = h3 > 0 ? "Active for " + h3 + "h " + m3 + "m" : "Active for " + m3 + "m";
        }
    }

    function fetchRemoteSchedule() {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var schedule = JSON.parse(xhr.responseText);
                    // Parse peak_start "HH:MM" to minutes
                    var parts = schedule.peak_start.split(":");
                    var etStart = parseInt(parts[0]) * 60 + parseInt(parts[1]);
                    parts = schedule.peak_end.split(":");
                    var etEnd = parseInt(parts[0]) * 60 + parseInt(parts[1]);
                    // Convert ET to local
                    var now = new Date();
                    var utcOffsetMin = -now.getTimezoneOffset();
                    var etOffsetMin = -4 * 60; // EDT
                    var diffMin = utcOffsetMin - etOffsetMin;
                    localBlockStart = (etStart + diffMin + 1440) % 1440;
                    localBlockEnd = (etEnd + diffMin + 1440) % 1440;
                } catch(e) { /* keep defaults */ }
            }
        };
        xhr.open("GET", "https://raw.githubusercontent.com/Xczer/claude-2x/main/schedule.json");
        xhr.send();
    }

    function generateCalendarDays() {
        var now = new Date(); // local time
        now.setHours(0, 0, 0, 0);
        var days = [];
        for (var i = 0; i < 8; i++) {
            var d = new Date(now.getTime() + i * 86400000);
            var dow = d.getDay();
            var isWe = (dow === 0 || dow === 6);
            days.push({
                dayNum: d.getDate().toString(),
                dayName: ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][dow],
                isWeekend: isWe,
                isToday: (i === 0)
            });
        }
        calendarDays = days;
    }

    Component.onCompleted: {
        computeStatus();
        generateCalendarDays();
        fetchRemoteSchedule();
        appearAnim.start();
    }

    // ── 1-second update timer ──
    Timer {
        id: updateTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: computeStatus()
    }

    // ── 16ms glow animation timer (~60fps) ──
    Timer {
        id: glowTimer
        interval: 16
        running: true
        repeat: true
        onTriggered: {
            glowPhase += 0.05;
            blobPhase1 += 0.004;
            blobPhase2 += 0.003;
            blobCanvas.requestPaint();
        }
    }

    // ── Appear animation ──
    Timer {
        id: appearAnim
        interval: 50
        running: false
        repeat: false
        onTriggered: appeared = true
    }

    // ── Re-fetch remote schedule every 6 hours ──
    Timer {
        id: scheduleFetchTimer
        interval: 6 * 60 * 60 * 1000 // 6 hours
        running: true
        repeat: true
        onTriggered: fetchRemoteSchedule()
    }

    // Regenerate calendar at midnight ET
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            var et = getETDate();
            if (et.getHours() === 0 && et.getMinutes() === 0) {
                generateCalendarDays();
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // VISUAL LAYER
    // ═══════════════════════════════════════════════════════════════════════

    Rectangle {
        id: outerFrame
        anchors.fill: parent
        radius: 22
        color: baseBg
        clip: true

        // ── Animated blobs via Canvas ──
        Canvas {
            id: blobCanvas
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                var w = width;
                var h = height;
                ctx.clearRect(0, 0, w, h);

                // Blob 1: orange radial gradient
                var cx1 = w / 2 + 60 * Math.cos(blobPhase1);
                var cy1 = h / 2 + 40 * Math.sin(blobPhase1 * 0.7);
                var grad1 = ctx.createRadialGradient(cx1, cy1, 0, cx1, cy1, 140);
                grad1.addColorStop(0, "rgba(201, 100, 66, 0.18)");
                grad1.addColorStop(1, "rgba(201, 100, 66, 0)");
                ctx.fillStyle = grad1;
                ctx.fillRect(0, 0, w, h);

                // Blob 2: purple radial gradient
                var cx2 = w / 2 - 50 * Math.cos(blobPhase2);
                var cy2 = h / 2 + 60 * Math.sin(blobPhase2 * 0.5);
                var grad2 = ctx.createRadialGradient(cx2, cy2, 0, cx2, cy2, 120);
                grad2.addColorStop(0, "rgba(139, 92, 246, 0.10)");
                grad2.addColorStop(1, "rgba(139, 92, 246, 0)");
                ctx.fillStyle = grad2;
                ctx.fillRect(0, 0, w, h);
            }
        }

        // ── Noise grain overlay (painted once) ──
        Canvas {
            id: noiseCanvas
            anchors.fill: parent
            opacity: 0.04
            renderStrategy: Canvas.Threaded
            onPaint: {
                var ctx = getContext("2d");
                var w = width;
                var h = height;
                ctx.clearRect(0, 0, w, h);
                var count = Math.floor(w * h * 0.12);
                for (var i = 0; i < count; i++) {
                    var px = Math.random() * w;
                    var py = Math.random() * h;
                    var g = 0.5 + Math.random() * 0.5;
                    ctx.fillStyle = Qt.rgba(g, g, g, 0.6);
                    ctx.fillRect(px, py, 1, 1);
                }
            }
        }

        // ── Card background with glassmorphism ──
        Rectangle {
            anchors.fill: parent
            radius: 22
            color: cardBg
            border.width: 0.8
            border.color: Qt.rgba(1, 1, 1, 0.12)
        }

        // ── Top highlight gradient ──
        Rectangle {
            anchors.fill: parent
            radius: 22
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.07) }
                GradientStop { position: 0.25; color: Qt.rgba(1, 1, 1, 0.015) }
                GradientStop { position: 0.6; color: "transparent" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // ── Main content column ──
        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            spacing: 7

            // ══════════════════════════════════════════════════════
            // ROW 1: Status orb + label + countdown
            // ══════════════════════════════════════════════════════
            RowLayout {
                Layout.fillWidth: true
                spacing: 9

                opacity: appeared ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

                // Status orb with glow
                Item {
                    width: 20
                    height: 20
                    Layout.alignment: Qt.AlignVCenter

                    // Soft glow behind dot (active only)
                    Rectangle {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        radius: 9
                        color: Qt.rgba(statusColor.r, statusColor.g, statusColor.b, 0.2)
                        visible: currentStatus === 0
                    }

                    // Dot
                    Rectangle {
                        anchors.centerIn: parent
                        width: 8
                        height: 8
                        radius: 4
                        color: statusColor

                        Rectangle {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            radius: 7
                            color: Qt.rgba(statusColor.r, statusColor.g, statusColor.b, currentStatus === 0 ? 0.3 : 0.1)
                            z: -1
                        }
                    }
                }

                // Status label + sublabel
                Column {
                    spacing: 1
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter

                    Row {
                        spacing: 8
                        Text {
                            text: statusLabel
                            font.pixelSize: 13
                            font.bold: true
                            color: Qt.rgba(1, 1, 1, 0.88)
                        }
                        // Status badge
                        Rectangle {
                            width: badgeText.implicitWidth + 12
                            height: badgeText.implicitHeight + 2
                            radius: 4
                            color: Qt.rgba(statusColor.r, statusColor.g, statusColor.b, 0.12)
                            anchors.verticalCenter: parent.children[0].verticalCenter

                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: currentStatus === 0 ? "LIVE" : currentStatus === 1 ? "OFF" : "WKD"
                                font.pixelSize: 8
                                font.bold: true
                                font.letterSpacing: 0.5
                                color: statusColor
                            }
                        }
                    }
                    Text {
                        text: statusSublabel
                        font.pixelSize: 10
                        color: Qt.rgba(1, 1, 1, 0.38)
                    }
                }

                // Countdown text
                Text {
                    text: countdownText
                    font.pixelSize: 10
                    font.family: "monospace"
                    color: Qt.rgba(1, 1, 1, 0.38)
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // ══════════════════════════════════════════════════════
            // ROW 2: Timeline Bar
            // ══════════════════════════════════════════════════════
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 53

                opacity: appeared ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 550; easing.type: Easing.OutCubic } }

                // The 40px bar
                Item {
                    id: barContainer
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 40

                    // Background track
                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.width: 0.5
                        border.color: Qt.rgba(1, 1, 1, 0.07)
                    }

                    // Colored segments (hidden on weekend)
                    Row {
                        anchors.fill: parent
                        anchors.margins: 1
                        spacing: 2
                        visible: currentStatus !== 2

                        // Active: 00:00-08:00 (33.3%)
                        Rectangle {
                            width: (parent.width - 4) * localBlockStart / 1440.0
                            height: parent.height
                            radius: 6
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(0.133, 0.773, 0.369, 0.85) }
                                GradientStop { position: 1.0; color: Qt.rgba(0.086, 0.639, 0.290, 0.55) }
                            }
                        }

                        // Blocked: 08:00-14:00 (25.0%)
                        Rectangle {
                            width: (parent.width - 4) * (localBlockEnd - localBlockStart) / 1440.0
                            height: parent.height
                            radius: 6
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(0.863, 0.149, 0.149, 0.50) }
                                GradientStop { position: 1.0; color: Qt.rgba(0.600, 0.106, 0.106, 0.28) }
                            }
                        }

                        // Active: 14:00-24:00 (41.7%)
                        Rectangle {
                            width: (parent.width - 4) * (1440 - localBlockEnd) / 1440.0
                            height: parent.height
                            radius: 6
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(0.133, 0.773, 0.369, 0.85) }
                                GradientStop { position: 1.0; color: Qt.rgba(0.086, 0.639, 0.290, 0.55) }
                            }
                        }
                    }

                    // Weekend placeholder text
                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        visible: currentStatus === 2

                        Text {
                            text: "\u263E"
                            font.pixelSize: 10
                            color: Qt.rgba(1, 1, 1, 0.2)
                        }
                        Text {
                            text: "NO 2\u00d7 ON WEEKENDS"
                            font.pixelSize: 9
                            font.bold: true
                            font.letterSpacing: 0.8
                            color: Qt.rgba(1, 1, 1, 0.2)
                        }
                    }

                    // Past-dimming overlay with soft right edge
                    Item {
                        visible: currentStatus !== 2
                        anchors.left: parent.left
                        anchors.top: parent.top
                        width: nowFraction * parent.width
                        height: parent.height
                        clip: true

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            width: Math.max(0, parent.width - 14)
                            height: parent.height
                            radius: 6
                            color: Qt.rgba(0, 0, 0, 0.28)
                        }
                    }

                    // Now indicator — clean white line
                    Rectangle {
                        visible: currentStatus !== 2
                        x: nowFraction * barContainer.width - 0.75
                        width: 1.5
                        height: barContainer.height
                        color: Qt.rgba(1, 1, 1, 0.85)

                        Behavior on x { NumberAnimation { duration: 1000; easing.type: Easing.Linear } }

                        // Subtle glow
                        Rectangle {
                            anchors.centerIn: parent
                            width: 5
                            height: parent.height
                            radius: 2.5
                            color: Qt.rgba(1, 1, 1, 0.3 + 0.1 * Math.sin(glowPhase))
                            z: -1
                        }
                    }
                }

                // ── Axis labels below bar — invisible on weekends, space reserved ──
                Item {
                    opacity: currentStatus !== 2 ? 1.0 : 0.0
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: barContainer.bottom
                    anchors.topMargin: 3
                    height: 10

                    Text {
                        text: formatTimeLabel(localBlockStart)
                        font.pixelSize: 7
                        color: Qt.rgba(1, 1, 1, 0.22)
                        x: parent.width * localBlockStart / 1440.0 - implicitWidth / 2
                    }
                    Text {
                        text: formatTimeLabel(localBlockEnd)
                        font.pixelSize: 7
                        color: Qt.rgba(1, 1, 1, 0.22)
                        x: parent.width * localBlockEnd / 1440.0 - implicitWidth / 2
                    }
                }
            }

            // ══════════════════════════════════════════════════════
            // ROW 3: Calendar Dots
            // ══════════════════════════════════════════════════════
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                spacing: 0

                opacity: appeared ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 550; easing.type: Easing.OutCubic } }

                Repeater {
                    model: calendarDays.length

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32

                        property var dayData: calendarDays[index]

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 3

                            // Day number
                            Text {
                                text: dayData ? dayData.dayNum : ""
                                font.pixelSize: 9
                                font.bold: dayData ? dayData.isToday : false
                                color: {
                                    if (!dayData) return Qt.rgba(1, 1, 1, 0.42);
                                    if (dayData.isToday) return accentOrange;
                                    if (dayData.isWeekend) return Qt.rgba(1, 1, 1, 0.2);
                                    return Qt.rgba(1, 1, 1, 0.42);
                                }
                                Layout.alignment: Qt.AlignHCenter
                            }

                            // Colored dot
                            Item {
                                width: 12
                                height: 12
                                Layout.alignment: Qt.AlignHCenter

                                // Glow behind dot
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 12
                                    height: 12
                                    radius: 6
                                    visible: dayData ? (dayData.isToday || !dayData.isWeekend) : false
                                    color: {
                                        if (!dayData) return "transparent";
                                        if (dayData.isToday) return Qt.rgba(accentOrange.r, accentOrange.g, accentOrange.b, 0.3);
                                        if (!dayData.isWeekend) return Qt.rgba(0.133, 0.773, 0.369, 0.15);
                                        return "transparent";
                                    }
                                }

                                // The dot itself
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 5
                                    height: 5
                                    radius: 2.5
                                    color: {
                                        if (!dayData) return "#374151";
                                        if (dayData.isWeekend) return "#374151";
                                        if (dayData.isToday) return accentOrange;
                                        return Qt.rgba(0.133, 0.773, 0.369, 0.75);
                                    }
                                }
                            }

                            // Day name
                            Text {
                                text: dayData ? dayData.dayName : ""
                                font.pixelSize: 7
                                color: dayData && dayData.isWeekend ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.28)
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
