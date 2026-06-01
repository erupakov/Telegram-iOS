import Foundation

private enum DivoBootstrapError: Error {
    case opNotHandled
}

public enum DivoBootstrap {
    public static func start() {
        divoLog("DivoBootstrap.start()", level: .info)
        // Ранний executor: обрабатывает только phone-link (чистый REST). nameUpdate требует
        // доступ к teamgram-аккаунту — TelegramUI ПЕРЕРЕГИСТРИРУЕТ executor с исполнителем имени,
        // когда поднимется авторизованный контекст (см. AppDelegate). До этого момента op
        // .nameUpdate просто лежит в очереди.
        PendingTelegramOpsQueue.shared.registerExecutor(makeExecutor(nameUpdate: nil))
    }

    /// Единый executor очереди отложенных операций (слот один на очередь).
    /// - phone-link: обрабатывается всегда (cold-start страховка auth-флоу, чистый REST).
    /// - nameUpdate: имя в teamgram после онбординга — требует аккаунт, исполнитель приходит
    ///   из TelegramUI; если `nameUpdate == nil`, op остаётся в очереди до авторизованного контекста.
    public static func makeExecutor(
        nameUpdate: ((_ firstName: String, _ lastName: String) async throws -> Void)?
    ) -> PendingTelegramOpsQueue.Executor {
        return { op in
            switch op {
            case let .phoneLink(phone):
                let outcome = await PhoneAuthLinker.linkAfterTeamgram(
                    phone: phone,
                    telegramUserId: nil,
                    role: DivoConfig.currentUserRole.rawValue
                )
                if case let .failed(error) = outcome {
                    // Не удалось (нет сети / бэк лёг) — оставляем op до следующего старта.
                    throw error
                }
                divoLog("DivoBootstrap: отложенный phone-link довёл линк для \(phone)", level: .info)
            case let .nameUpdate(firstName, lastName):
                guard let nameUpdate else {
                    // Нет исполнителя (ещё не авторизованы) — оставляем op в очереди.
                    throw DivoBootstrapError.opNotHandled
                }
                try await nameUpdate(firstName, lastName)
                divoLog("DivoBootstrap: teamgram-имя обновлено для \(firstName)", level: .info)
            case let .telegramLink(phone, divoUserId):
                // telegram-link допроводим, когда поднят authorized-контекст (есть telegramUserId).
                // Иначе оставляем op в очереди до следующего дренажа.
                guard let telegramUserId = DivoTeamgramSync.shared.telegramUserId else {
                    throw DivoBootstrapError.opNotHandled
                }
                let linked = try await AuthRestService.shared.telegramLink(
                    telegramUserId: telegramUserId, phone: phone, divoUserId: divoUserId
                )
                DivoConfig.accessToken = linked.accessToken
                divoLog("DivoBootstrap: telegram-link довёл сшивку для divoUserId=\(divoUserId)", level: .info)
            }
        }
    }
}
