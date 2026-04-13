//
//  FilterOptionItem.swift
//  DivoUIKit
//

import Foundation

/// Элемент списка для `FilterOptionsController`.
///
/// Используется как абстрактный пункт фильтра: `id` — стабильный идентификатор (для сравнения/сохранения),
/// `title` — отображаемое название. Доменных зависимостей нет, поэтому подходит и для фильтров поиска
/// моделей, и для любых других списков с множественным/одиночным выбором.
public struct FilterOptionItem: Equatable, Hashable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}
