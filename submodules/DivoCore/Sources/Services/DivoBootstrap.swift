import Foundation

private enum DivoBootstrapError: Error {
    case opNotHandled
}

public enum DivoBootstrap {
    public static func start() {
        divoLog("DivoBootstrap.start()", level: .info)

        // Единый executor очереди отложенных операций (слот один на очередь). registerExecutor
        // сам дёргает drain() — на каждом холодном старте докатываем накопленные op'ы.
        // Сейчас обрабатываем phone-link (страховка auth-флоу при обрыве сети). name-sync,
        // когда дойдёт, дописывает свою ветку В ЭТОТ ЖЕ switch, а не регистрирует свой executor.
        PendingTelegramOpsQueue.shared.registerExecutor { op in
            switch op {
            case let .phoneLink(phone):
                let outcome = await PhoneAuthLinker.linkAfterTeamgram(
                    phone: phone,
                    telegramUserId: nil,
                    role: DivoConfig.currentUserRole.rawValue
                )
                if case let .failed(error) = outcome {
                    // Не удалось (всё ещё нет сети / бэк лёг) — оставляем op в очереди,
                    // повторим на следующем старте.
                    throw error
                }
                divoLog("DivoBootstrap: отложенный phone-link довёл линк для \(phone)", level: .info)
            case .nameUpdate:
                // Не наш scope (post-onboarding name sync пока не подключён) — кидаем,
                // чтобы op остался в очереди нетронутым до своей реализации.
                throw DivoBootstrapError.opNotHandled
            }
        }
    }
}
