import Foundation
import TelegramCore
import DivoCore

enum AgencyLogoFetcher {
    static func fetch(for items: [WorkHistoryItem], onLogoLoaded: @MainActor @escaping (Int, URL?) -> Void) {
        Task {
            await withTaskGroup(of: Void.self) { group in
                for item in items {
                    guard let agencyId = item.agencyId else { continue }

                    group.addTask {
                        var logoUrl: URL? = nil

                        do {
                            let response: AgencyDetailResponse = try await DivoAPIClient.shared.request(
                                path: "/agency/\(agencyId)"
                            )
                            if let urlString = response.data.photo?.fullUrl {
                                logoUrl = URL(string: urlString)
                            }
                        } catch {}

                        let finalUrl = logoUrl
                        let itemId = item.id
                        await MainActor.run {
                            onLogoLoaded(itemId, finalUrl)
                        }
                    }
                }
            }
        }
    }
}
