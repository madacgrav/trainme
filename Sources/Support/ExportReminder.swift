import Foundation

/// PRD §9: export is the only backup, so nudge when it goes stale. Pure.
///
/// Never exported + nothing recorded is *not* due, so a fresh install is not
/// nagged before there is anything to lose.
func exportReminderDue(
    lastExportAt: Date?,
    now: Date,
    completedSinceExport: Int,
    dayThreshold: Int = 14,
    sessionThreshold: Int = 5
) -> Bool {
    guard let lastExportAt else { return completedSinceExport > 0 }
    let days = Calendar.current.dateComponents([.day], from: lastExportAt, to: now).day ?? 0
    return days >= dayThreshold || completedSinceExport >= sessionThreshold
}
