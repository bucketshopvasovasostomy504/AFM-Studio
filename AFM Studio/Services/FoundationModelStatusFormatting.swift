import Foundation
import FoundationModels

enum FoundationModelStatusFormatting {
    static func systemAvailabilityText(_ availability: SystemLanguageModel.Availability) -> (ModelAvailabilityState, String) {
        switch availability {
        case .available:
            return (.available, "Ready")
        case .unavailable(let reason):
            return (.unavailable, "Unavailable: \(String(describing: reason))")
        @unknown default:
            return (.unavailable, "Unavailable")
        }
    }

    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    static func privateCloudAvailabilityText(_ availability: PrivateCloudComputeLanguageModel.Availability) -> (ModelAvailabilityState, String) {
        switch availability {
        case .available:
            return (.available, "Ready")
        case .unavailable(let reason):
            return (.unavailable, "Unavailable: \(String(describing: reason))")
        @unknown default:
            return (.unavailable, "Unavailable")
        }
    }

    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    static func privateCloudQuotaText(_ quotaUsage: PrivateCloudComputeLanguageModel.QuotaUsage) -> String {
        if quotaUsage.isLimitReached {
            if let resetDate = quotaUsage.resetDate {
                return "Quota reached until \(resetDate.formatted(date: .abbreviated, time: .shortened))"
            }
            return "Quota reached"
        }

        switch quotaUsage.status {
        case .belowLimit(let belowLimit):
            return belowLimit.isApproachingLimit ? "Quota approaching daily limit" : "Quota available"
        case .limitReached:
            return "Quota reached"
        @unknown default:
            return "Quota status unknown"
        }
    }
}
