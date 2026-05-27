import UIKit
import TelegramPresentationData

public extension PresentationData {
    /// Подменяет accent-цвет Telegram-нативной темы на DIVO orange. Перекрашивает:
    /// - `actionSheet.controlAccentColor` / `standardActionTextColor` — алерты и action sheets
    ///   (sendCode errors, network errors, password reset и т.п.);
    /// - `list.itemAccentColor` — главные текстовые кнопки списков и модалок (Edit / Done /
    ///   Save в Settings, кнопка Edit в PhoneConfirmationController, акцентные текстовые
    ///   действия). Побочный эффект: ссылки/упоминания/счётчики непрочитанного в чатах
    ///   тоже окрасятся в оранжевый — Telegram использует одно поле для всего этого;
    /// - `list.itemCheckColors.fillColor` — фон круглых primary-кнопок `SolidRoundedButtonNode`
    ///   (Continue в PhoneConfirmationController, Done в auth и т.п.);
    /// - `rootController.navigationBar.accentTextColor` — accent в navigation bar
    ///   (кнопки «Done», «Edit» в navbar).
    ///
    /// Применяется глобально через `|> map { $0.withDivoActionSheetAccent() }`
    /// в bootstrap PresentationData стрима (`SharedAccountContextImpl`).
    ///
    /// Изоляция DIVO от форка: правка делается в одной точке (map в SharedAccountContext),
    /// сам override живёт в DivoUIKit. Это исключает правки внутри
    /// `DefaultDayPresentationTheme.swift` и других системных файлов Telegram.
    func withDivoActionSheetAccent() -> PresentationData {
        let accent = DivoColorPalette.accent

        let patchedActionSheet = self.theme.actionSheet.withUpdated(
            standardActionTextColor: accent,
            controlAccentColor: accent
        )
        let patchedItemCheckColors = self.theme.list.itemCheckColors.withUpdated(fillColor: accent)
        let patchedList = self.theme.list.withUpdated(
            itemAccentColor: accent,
            itemCheckColors: patchedItemCheckColors
        )
        let patchedNavigationBar = self.theme.rootController.navigationBar.withUpdated(accentTextColor: accent)
        let patchedRootController = self.theme.rootController.withUpdated(navigationBar: patchedNavigationBar)

        let patchedTheme = PresentationTheme(
            name: self.theme.name,
            index: self.theme.index,
            referenceTheme: self.theme.referenceTheme,
            overallDarkAppearance: self.theme.overallDarkAppearance,
            intro: self.theme.intro,
            passcode: self.theme.passcode,
            rootController: patchedRootController,
            list: patchedList,
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
