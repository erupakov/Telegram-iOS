import UIKit
import TelegramPresentationData

public extension PresentationData {
    /// Подменяет accent в `actionSheet` темы на DIVO orange — для алертов и action sheets,
    /// которые Telegram-флоу создаёт сам (sendCode errors, network errors, password reset и т.п.).
    ///
    /// Применяется глобально через `|> map { $0.withDivoActionSheetAccent() }`
    /// в bootstrap PresentationData стрима (`SharedAccountContextImpl`).
    ///
    /// Изоляция DIVO от форка: правка делается в одной точке (map в SharedAccountContext),
    /// сам override живёт в DivoUIKit. Это исключает правки внутри
    /// `DefaultDayPresentationTheme.swift` и других системных файлов Telegram.
    func withDivoActionSheetAccent() -> PresentationData {
        let patchedActionSheet = self.theme.actionSheet.withUpdated(
            standardActionTextColor: DivoColorPalette.accent,
            controlAccentColor: DivoColorPalette.accent
        )
        let patchedTheme = PresentationTheme(
            name: self.theme.name,
            index: self.theme.index,
            referenceTheme: self.theme.referenceTheme,
            overallDarkAppearance: self.theme.overallDarkAppearance,
            intro: self.theme.intro,
            passcode: self.theme.passcode,
            rootController: self.theme.rootController,
            list: self.theme.list,
            chatList: self.theme.chatList,
            chat: self.theme.chat,
            actionSheet: patchedActionSheet,
            contextMenu: self.theme.contextMenu,
            inAppNotification: self.theme.inAppNotification,
            chart: self.theme.chart,
            preview: self.theme.preview
        )
        return self.withUpdated(theme: patchedTheme)
    }
}
