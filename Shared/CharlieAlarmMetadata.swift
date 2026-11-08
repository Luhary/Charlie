import Foundation
#if canImport(AlarmKit)
import AlarmKit

/// Данные будильника для AlarmKit (iOS 26+). Пока пустые: название и цвет хранятся в самом будильнике.
@available(iOS 26.0, *)
struct CharlieAlarmMetadata: AlarmMetadata {}
#endif
