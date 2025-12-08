#!/bin/bash
# Stop hook to send desktop notification when Claude finishes
# Works on Linux (notify-send), macOS (osascript), and WSL

message="${1:-Task completed}"
title="Claude Code"

# Try different notification methods based on platform
send_notification() {
  # Linux with notify-send (GNOME, KDE, etc.)
  if command -v notify-send &>/dev/null; then
    notify-send "$title" "$message" --urgency=normal --icon=terminal 2>/dev/null
    return 0
  fi

  # macOS
  if command -v osascript &>/dev/null; then
    osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null
    return 0
  fi

  # WSL - use powershell for Windows toast notification
  if grep -qi microsoft /proc/version 2>/dev/null; then
    powershell.exe -Command "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null; \$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02); \$template.SelectSingleNode('//text[@id=\"1\"]').InnerText = '$title'; \$template.SelectSingleNode('//text[@id=\"2\"]').InnerText = '$message'; [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude Code').Show([Windows.UI.Notifications.ToastNotification]::new(\$template))" 2>/dev/null
    return 0
  fi

  # Fallback: terminal bell
  echo -ne '\a'
  return 0
}

send_notification
exit 0
