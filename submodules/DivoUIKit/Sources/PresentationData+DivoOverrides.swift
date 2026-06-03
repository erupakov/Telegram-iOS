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

    /// Перекрашивает чат под фирменный стиль DIVO (PROJ-016): бабблы, галочки, имя автора,
    /// сервисные сообщения / pill даты и панель ввода. Цвета — из `DivoColorPalette`.
    ///
    /// Фон чата (wallpaper) здесь НЕ задаётся: тип `TelegramWallpaper` живёт в `TelegramCore`,
    /// который запрещён в DivoUIKit. Обои применяются в `SharedAccountContextImpl` через
    /// `.withUpdated(chatWallpaper: .color(DivoColorPalette.chatWallpaperValue))`.
    ///
    /// Применяется в той же точке, что и `withDivoActionSheetAccent()`.
    func withDivoChatTheme() -> PresentationData {
        let chat = self.theme.chat

        func patchBubble(_ bubble: PresentationThemeBubbleColor) -> PresentationThemeBubbleColor {
            func patch(_ components: PresentationThemeBubbleColorComponents) -> PresentationThemeBubbleColorComponents {
                components.withUpdated(
                    fill: [DivoColorPalette.chatBubbleFill],
                    highlightedFill: DivoColorPalette.chatBubbleHighlight,
                    stroke: DivoColorPalette.chatBubbleFill
                )
            }
            return bubble.withUpdated(withWallpaper: patch(bubble.withWallpaper), withoutWallpaper: patch(bubble.withoutWallpaper))
        }

        func patchParted(_ parted: PresentationThemePartedColors) -> PresentationThemePartedColors {
            parted.withUpdated(
                bubble: patchBubble(parted.bubble),
                primaryTextColor: DivoColorPalette.primaryText,
                secondaryTextColor: DivoColorPalette.chatBubbleTime,
                accentTextColor: DivoColorPalette.accentSecondary,
                accentControlColor: DivoColorPalette.accentSecondary,
                mediaActiveControlColor: DivoColorPalette.accentSecondary,
                mediaInactiveControlColor: DivoColorPalette.chatMediaInactiveControl,
                mediaControlInnerBackgroundColor: DivoColorPalette.chatBubbleFill,
                pendingActivityColor: DivoColorPalette.accentSecondary
            )
        }

        let message = chat.message.withUpdated(
            incoming: patchParted(chat.message.incoming),
            outgoing: patchParted(chat.message.outgoing),
            outgoingCheckColor: DivoColorPalette.accentSecondary
        )

        func patchService(_ components: PresentationThemeServiceMessageColorComponents) -> PresentationThemeServiceMessageColorComponents {
            components.withUpdated(
                fill: DivoColorPalette.chatServicePillFill,
                primaryText: DivoColorPalette.primaryTextOnDark,
                dateFillStatic: DivoColorPalette.chatServicePillFill,
                dateFillFloating: DivoColorPalette.chatServicePillFill
            )
        }
        let serviceMessage = chat.serviceMessage.withUpdated(
            components: chat.serviceMessage.components.withUpdated(
                withDefaultWallpaper: patchService(chat.serviceMessage.components.withDefaultWallpaper),
                withCustomWallpaper: patchService(chat.serviceMessage.components.withCustomWallpaper)
            ),
            dateTextColor: PresentationThemeVariableColor(color: DivoColorPalette.primaryTextOnDark)
        )

        let inputPanel = chat.inputPanel.withUpdated(
            panelControlAccentColor: DivoColorPalette.accentSecondary,
            panelControlColor: DivoColorPalette.chatInputControl,
            inputBackgroundColor: DivoColorPalette.cardBackground,
            inputPlaceholderColor: DivoColorPalette.chatInputPlaceholder,
            inputTextColor: DivoColorPalette.primaryText,
            inputControlColor: DivoColorPalette.chatInputPlaceholder,
            actionControlFillColor: DivoColorPalette.accentSecondary,
            actionControlForegroundColor: DivoColorPalette.primaryTextOnDark,
            mediaRecordingControl: chat.inputPanel.mediaRecordingControl.withUpdated(
                buttonColor: DivoColorPalette.chatInputControl,
                micLevelColor: DivoColorPalette.accentSecondary,
                activeIconColor: DivoColorPalette.primaryTextOnDark
            )
        )

        let patchedChat = chat.withUpdated(message: message, serviceMessage: serviceMessage, inputPanel: inputPanel)

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
            chat: patchedChat,
            actionSheet: self.theme.actionSheet,
            contextMenu: self.theme.contextMenu,
            inAppNotification: self.theme.inAppNotification,
            chart: self.theme.chart,
            preview: self.theme.preview
        )
        return self.withUpdated(theme: patchedTheme)
    }
}
