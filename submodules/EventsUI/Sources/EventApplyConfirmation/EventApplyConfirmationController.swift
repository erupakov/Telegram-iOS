//
//  EventApplyConfirmationController.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 26.05.2026.
//

import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AlertUI
import AppBundle
import TelegramBaseController
import DivoUIKit
import DivoCore

public final class EventApplyConfirmationController: TelegramBaseController {
    
    private var controllerNode: EventApplyConfirmationNode {
        return self.displayNode as! EventApplyConfirmationNode
    }

    private let context: AccountContext
    private let eventId: Int
    private let eventData: EventFullDetailData
    
    public var onApplySuccess: (() -> Void)?

    public init(context: AccountContext, eventId: Int, eventData: EventFullDetailData) {
        self.context = context
        self.eventId = eventId
        self.eventData = eventData
        super.init(context: context, navigationBarPresentationData: nil)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        self.displayNode = EventApplyConfirmationNode(context: self.context)
        
        self.controllerNode.onBackTapped = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        
        self.controllerNode.onCancelTapped = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        
        self.controllerNode.onSubmitTapped = { [weak self] in
            self?.performSubmitApplication()
        }
        
        self.controllerNode.onRetryTapped = { [weak self] in
            guard let self = self else { return }
            self.controllerNode.resetToLoading()
            self.fetchUserAndCompare()
        }

        self.displayNodeDidLoad()
        
        fetchUserAndCompare()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }

    private func fetchUserAndCompare() {
        Task {
            do {
                // Получаем профиль текущего авторизованного пользователя (модели)
                let userResponse: UserDetailResponse = try await DivoAPIClient.shared.request(
                    path: "/user/info",
                    method: "GET"
                )
                
                // Проводим сверку параметров
                let (matches, hasMismatch, isMultiple, single) = self.compareParameters(user: userResponse.data, event: self.eventData)
                
                await MainActor.run {
                    self.controllerNode.update(
                        user: userResponse.data,
                        event: self.eventData,
                        matches: matches,
                        hasMismatch: hasMismatch,
                        isMultipleMismatches: isMultiple,
                        singleMismatch: single
                    )
                }
            } catch {
                await MainActor.run {
                    self.controllerNode.markFailed(networkError: self.isNetworkError(error))
                }
            }
        }
    }

    // Алгоритм сопоставления параметров модели и требований события
    private func compareParameters(user: UserDetail, event: EventFullDetailData) -> (
        matches: [ParameterMatch],
        hasMismatch: Bool,
        isMultipleMismatches: Bool,
        singleMismatch: ParameterMatch?
    ) {
        var matches: [ParameterMatch] = []
        
        let eventAttrs = event.modelAttributes
        let userModel = user.model
        let userApp = userModel?.appearance
        
        // Безопасное приведение любого числового типа (Int, Double, Float) к Float
        func convertToFloat(_ anyVal: Any?) -> Float? {
            if let floatVal = anyVal as? Float { return floatVal }
            if let doubleVal = anyVal as? Double { return Float(doubleVal) }
            if let intVal = anyVal as? Int { return Float(intVal) }
            if let int64Val = anyVal as? Int64 { return Float(int64Val) }
            return nil
        }
        
        // Форматирование чисел: убирает лишнюю дробную часть .0 (180.0 -> "180"), оставляет дробную часть у дробных (37.5 -> "37.5")
        func formatValue(_ val: Float?) -> String? {
            guard let val = val else { return nil }
            let isInteger = val.truncatingRemainder(dividingBy: 1) == 0
            return isInteger ? "\(Int(val))" : String(format: "%.1f", val)
        }
        
        // Универсальная функция сравнения числовых диапазонов
        func checkRange(title: String, userValue: Float?, range: EventFullRange?, suffix: String) {
            guard let range = range else { return } // Если диапазона нет в требованиях события — пропускаем
            
            let valueStr: String
            let isMatched: Bool
            
            let fromStr = formatValue(range.from)
            let toStr = formatValue(range.to)
            
            if let f = fromStr, let t = toStr {
                valueStr = f == t ? "\(f) \(suffix)" : "\(f)-\(t) \(suffix)"
            } else if let f = fromStr {
                valueStr = "From \(f) \(suffix)"
            } else if let t = toStr {
                valueStr = "Up to \(t) \(suffix)"
            } else {
                valueStr = DivoStrings.tbd
            }
            
            if let userValue = userValue {
                let from = range.from ?? -Float.infinity
                let to = range.to ?? Float.infinity
                isMatched = userValue >= from && userValue <= to
            } else {
                isMatched = false // У пользователя не заполнено, значит не совпадает
            }
            
            matches.append(ParameterMatch(title: title, value: valueStr, isMatched: isMatched))
        }
        
        // Универсальная функция сравнения списков опций (цвет волос, глаз, кожи и т.д.)
        func checkOptions(title: String, userValueId: Any?, allowedOptions: [EventFullIdTitle]?, userValueTitle: String?) {
            guard let allowed = allowedOptions, !allowed.isEmpty else { return }
            
            func unwrap(_ any: Any) -> Any? {
                let mirror = Mirror(reflecting: any)
                guard mirror.displayStyle == .optional else { return any }
                if mirror.children.isEmpty { return nil }
                return unwrap(mirror.children.first!.value)
            }
            
            let isMatched: Bool
            if let rawUserId = userValueId, let unwrappedUser = unwrap(rawUserId) {
                let userIdStr = String(describing: unwrappedUser).lowercased()
                
                isMatched = allowed.contains { allowedItem in
                    if let rawAllowedId = allowedItem.id, let unwrappedAllowed = unwrap(rawAllowedId) {
                        let allowedIdStr = String(describing: unwrappedAllowed).lowercased()
                        return allowedIdStr == userIdStr
                    }
                    return false
                }
            } else {
                isMatched = false
            }
            
            // Выводим требования эвента через запятую
            let valueStr = allowed.compactMap { $0.title }.joined(separator: ", ")
            matches.append(ParameterMatch(
                title: title,
                value: valueStr.isEmpty ? (userValueTitle ?? DivoStrings.tbd) : valueStr,
                isMatched: isMatched
            ))
        }
        
        // --- 1. Роль (Role) ---
        if let requiredRoles = eventAttrs?.role, !requiredRoles.isEmpty,
           let userRoleId = user.role {
            
            let roleOptions: [FilterOptionItem] = [
                FilterOptionItem(id: "model", title: DivoStrings.debugModel),
                FilterOptionItem(id: "new_face", title: DivoStrings.debugNewTalent)
            ]
            
            let isMatched = requiredRoles.contains { $0.lowercased() == userRoleId.lowercased() }
            
            let requiredTitles = requiredRoles.compactMap { roleId in
                roleOptions.first(where: { $0.id == roleId })?.title
            }.joined(separator: ", ")
            
            let userRoleTitle = roleOptions.first(where: { $0.id == userRoleId })?.title ?? userRoleId
            
            matches.append(ParameterMatch(
                title: DivoStrings.debugRole,
                value: requiredTitles.isEmpty ? userRoleTitle : requiredTitles,
                isMatched: isMatched
            ))
        }
        
        // --- 2. Пол (Gender) ---
        if let requiredGenders = eventAttrs?.gender, !requiredGenders.isEmpty,
           let userGender = user.gender {
            let isMatched = requiredGenders.contains { $0.id?.lowercased() == userGender.id.lowercased() }
            
            let requiredTitles = requiredGenders.compactMap { $0.title }.joined(separator: ", ")
            matches.append(ParameterMatch(
                title: DivoStrings.attrGender,
                value: requiredTitles.isEmpty ? userGender.title : requiredTitles,
                isMatched: isMatched
            ))
        }
        
        // --- 3. Возраст (Age) ---
        if let range = eventAttrs?.age {
            var userAge: Float? = nil
            
            if let birthdayString = user.birthday {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                
                if let birthdayDate = formatter.date(from: birthdayString) {
                    let calendar = Calendar.current
                    let ageComponents = calendar.dateComponents([.year], from: birthdayDate, to: Date())
                    if let years = ageComponents.year {
                        userAge = Float(years)
                    }
                }
            }
            
            checkRange(title: DivoStrings.ageYo, userValue: userAge, range: range, suffix: DivoStrings.yearsOld)
        }
        
        // --- 4. Рост (Height) ---
        if let range = eventAttrs?.height {
            let userHeight = convertToFloat(userApp?.height)
            checkRange(title: DivoStrings.heightCm, userValue: userHeight, range: range, suffix: DivoStrings.unitCm)
        }
        
        // --- 5. Вес (Weight) ---
        if let range = eventAttrs?.weight {
            let userWeight = convertToFloat(userApp?.weight)
            checkRange(title: DivoStrings.weightKg, userValue: userWeight, range: range, suffix: DivoStrings.unitKg)
        }
        
        // --- 6. Талия (Waist) ---
        if let range = eventAttrs?.waist {
            let userWaist = convertToFloat(userApp?.waist)
            checkRange(title: DivoStrings.waistCm, userValue: userWaist, range: range, suffix: DivoStrings.unitCm)
        }
        
        // --- 7. Бедра (Hips) ---
        if let range = eventAttrs?.hips {
            let userHips = convertToFloat(userApp?.hips)
            checkRange(title: DivoStrings.hipsCm, userValue: userHips, range: range, suffix: DivoStrings.unitCm)
        }
        
        // --- 8. Размер обуви (Shoe Size) ---
        if let range = eventAttrs?.shoesSize {
            let userShoes = convertToFloat(userApp?.shoesSize)
            checkRange(title: DivoStrings.shoeSizeEU, userValue: userShoes, range: range, suffix: "")
        }
        
        // --- 9. Цвет волос (Hair Color) ---
        checkOptions(
            title: DivoStrings.attrHairColor,
            userValueId: userApp?.hairColor?.id,
            allowedOptions: eventAttrs?.hairColor,
            userValueTitle: userApp?.hairColor?.title
        )
        
        // --- 10. Длина волос (Hair Length) ---
        checkOptions(
            title: DivoStrings.attrHairLength,
            userValueId: userApp?.hairLength?.id,
            allowedOptions: eventAttrs?.hairLength,
            userValueTitle: userApp?.hairLength?.title
        )
        
        // --- 11. Цвет глаз (Eye Color) ---
        checkOptions(
            title: DivoStrings.eyeColor,
            userValueId: userApp?.eyeColor?.id,
            allowedOptions: eventAttrs?.eyeColor,
            userValueTitle: userApp?.eyeColor?.title
        )
        
        // --- 12. Цвет кожи (Skin Color) ---
        checkOptions(
            title: DivoStrings.skinColor,
            userValueId: userApp?.skinColor?.id,
            allowedOptions: eventAttrs?.skinColor,
            userValueTitle: userApp?.skinColor?.title
        )
        
        // Атомарно вычисляем несоответствия на основе готового массива
        let mismatches = matches.filter { !$0.isMatched }
        let hasMismatch = !mismatches.isEmpty
        let isMultipleMismatches = mismatches.count > 1
        let singleMismatch = mismatches.count == 1 ? mismatches.first : nil
        
        return (matches, hasMismatch, isMultipleMismatches, singleMismatch)
    }
    
    private func performSubmitApplication() {
        self.controllerNode.toggleSubmitLoading(active: true)
        
        let body = ApplyEventRequest(eventId: self.eventId)
        
        Task {
            do {
                let _: ApplyEventResponse = try await DivoAPIClient.shared.request(
                    path: "/event/apply",
                    method: "POST",
                    body: body
                )
                
                await MainActor.run {
                    self.controllerNode.toggleSubmitLoading(active: false)
                    
                    let deadlineText = self.formatDeadlineDate(self.eventData.applicationDeadline)
                    
                    self.controllerNode.showSuccessState(deadlineText: deadlineText)
                    
                    self.onApplySuccess?()
                }
            } catch {
                await MainActor.run {
                    self.controllerNode.toggleSubmitLoading(active: false)
                    self.controllerNode.showSnackbar(
                        message: DivoStrings.sendApplyRequestFail,
                        style: .error
                    )
                }
            }
        }
    }
    
    private func formatDeadlineDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return DivoStrings.tbd }
        let serverFormatter = DateFormatter()
        serverFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        serverFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        guard let date = serverFormatter.date(from: dateString) else { return dateString }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: DivoStrings.current.rawValue)
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func isNetworkError(_ error: Error) -> Bool {
        if let apiError = error as? DivoAPIError, case .noInternetConnection = apiError {
            return true
        }
        return false
    }
}
