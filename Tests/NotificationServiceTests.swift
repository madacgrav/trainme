import Testing
import UserNotifications
@testable import TrainMe

@Test func onlyAuthorizedOrProvisionalCanSchedule() {
    #expect(canScheduleAlerts(.authorized))
    #expect(canScheduleAlerts(.provisional))
    #expect(!canScheduleAlerts(.denied))
    #expect(!canScheduleAlerts(.notDetermined))
    #expect(!canScheduleAlerts(.ephemeral))
}
