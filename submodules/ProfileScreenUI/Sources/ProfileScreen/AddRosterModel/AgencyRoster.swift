import Foundation
import DivoCore

/// Ростер агентства — единственный источник правды «модель в агентстве». `currentAgency` из
/// `/agency/search` этого не гарантирует (поле может указывать на агентство, в ростере которого
/// модели нет), поэтому статус «Уже добавлен» и успех добавления сверяем с ростером.
enum AgencyRoster {
    /// userId всех моделей агентства (`/agency/{agencyId}/models/list`, постранично).
    static func fetchUserIds(agencyId: Int) async throws -> Set<Int> {
        let pageSize = 100
        let maxPages = 20
        var userIds = Set<Int>()
        var offset = 0
        for _ in 0 ..< maxPages {
            let response: AgencyModelsResponse = try await DivoAPIClient.shared.request(
                path: "/agency/\(agencyId)/models/list",
                method: "POST",
                body: AgencyModelsListRequest(offset: offset, limit: pageSize)
            )
            let items = response.data?.items ?? []
            for item in items {
                if let userId = item.userId {
                    userIds.insert(userId)
                }
            }
            offset += items.count
            let totalCount = response.data?.pagination?.meta?.totalCount
            if items.count < pageSize || (totalCount.map { offset >= $0 } ?? false) {
                break
            }
        }
        return userIds
    }
}
