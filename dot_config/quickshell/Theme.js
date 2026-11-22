.pragma library

// Colors and metrics shared by the bar. Keep these in sync with the old
// waybar style so the new bar looks like the old one.
var fontFamily = "JetBrainsMono Nerd Font"
var fontSize = 12

var fg = "#f2f2f2"
var red = "#f38ba8"
var cpuColor = "#fa8787"
var gpuColor = "#cba6f7"
var memoryColor = "#fab387"
var diskColor = "#28c9af"
var volumeColor = "#74c7ec"

var barBackground = "#80000000" // rgba(0, 0, 0, 0.5)
var barBorder = "#1affffff"     // rgba(255, 255, 255, 0.1)
var tooltipBackground = "#222222"
var tooltipForeground = "#cdd6f4"
var menuBackground = "#222222"

// Nerd Font glyphs, copied from the waybar config.
var iconWorkspaceActive = ""   // U+F111 filled circle
var iconWorkspaceOccupied = "" // U+F192 dot circle, workspace has windows
var iconWorkspaceEmpty = ""    // U+EBB5 hollow circle, no windows

var iconCpu = ""               // U+F4BC
var iconGpu = ""               // U+EBE2 (cod-graph_line)
var iconMemory = ""             // U+EFC5
var iconDisk = ""              // U+F0C7

var iconVolumeLow = "󰕿"         // U+F057F
var iconVolumeMedium = "󰖀"      // U+F0580
var iconVolumeHigh = "󰕾"        // U+F057E
var iconVolumeMuted = "󰝟"       // U+F075F
var iconHeadset = ""           // U+F025
var iconBluetooth = ""         // U+F294

var iconBell = ""              // U+F0A2
var iconBellSlash = ""         // U+F1F7
var iconPower = ""            // U+F011
