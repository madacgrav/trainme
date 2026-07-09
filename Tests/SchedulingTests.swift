import Foundation
import Testing
@testable import TrainMe

private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 7) -> Date {
    Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}

@Test func weeklyTueThuExpansion() {
    // 2026-07-14 is a Tuesday.
    let start = date(2026, 7, 14)
    let horizon = date(2026, 7, 28) // two weeks later (Tuesday)
    let rule = AppRecurrence(frequency: .weekly, interval: 1, weekdays: [3, 5], endDate: nil, occurrenceCount: nil)

    let dates = expandRecurrence(rule, from: start, to: horizon)

    let calendar = Calendar.current
    #expect(dates.count == 5) // Tue 14, Thu 16, Tue 21, Thu 23, Tue 28
    #expect(dates.allSatisfy { [3, 5].contains(calendar.component(.weekday, from: $0)) })
    #expect(dates.allSatisfy { calendar.component(.hour, from: $0) == 7 })
    #expect(dates == dates.sorted())
    #expect(dates.first == start)
}

@Test func weeklyExpansionRespectsOccurrenceCount() {
    let start = date(2026, 7, 14)
    let horizon = date(2026, 12, 31)
    let rule = AppRecurrence(frequency: .weekly, interval: 1, weekdays: [3, 5], endDate: nil, occurrenceCount: 6)

    #expect(expandRecurrence(rule, from: start, to: horizon).count == 6)
}

@Test func weeklyExpansionRespectsEndDate() {
    let start = date(2026, 7, 14)
    let rule = AppRecurrence(frequency: .weekly, interval: 1, weekdays: [3], endDate: date(2026, 7, 21, 23), occurrenceCount: nil)

    let dates = expandRecurrence(rule, from: start, to: date(2026, 12, 31))
    #expect(dates.count == 2) // Tue 14, Tue 21
}

@Test func dailyExpansionWithInterval() {
    let start = date(2026, 7, 14)
    let rule = AppRecurrence(frequency: .daily, interval: 2, weekdays: [], endDate: nil, occurrenceCount: nil)

    let dates = expandRecurrence(rule, from: start, to: date(2026, 7, 20))
    #expect(dates.count == 4) // 14, 16, 18, 20
}

@Test func weeklyWithNoWeekdaysUsesStartWeekday() {
    let start = date(2026, 7, 14) // Tuesday
    let rule = AppRecurrence(frequency: .weekly, interval: 1, weekdays: [], endDate: nil, occurrenceCount: nil)

    let dates = expandRecurrence(rule, from: start, to: date(2026, 7, 28))
    #expect(dates.count == 3)
    #expect(dates.allSatisfy { Calendar.current.component(.weekday, from: $0) == 3 })
}
