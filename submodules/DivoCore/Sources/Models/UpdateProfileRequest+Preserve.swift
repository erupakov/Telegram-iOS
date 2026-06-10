import Foundation

public extension UpdateBiographyPageRequest {
    /// Полный payload для `/user/update-profile` на основе текущего профиля с переопределённым именем.
    /// Шлём ВСЕ известные поля (а не только имя), чтобы изменение имени не затёрло остальное —
    /// независимо от того, делает бэк merge или replace.
    init(preserving detail: UserDetail, fullName: String) {
        let appearance: Appearance? = detail.model?.appearance.map { app in
            Appearance(
                // Маркер единиц appearance-чисел пересылаем как есть; фолбэк на юзерскую
                // настройку (detail.measuringSystem) пометил бы метрические числа как имперские.
                measuringSystem: app.measuringSystem,
                height: app.height,
                weight: app.weight,
                breastSize: app.breastSize,
                waist: app.waist,
                hips: app.hips,
                shoesSize: app.shoesSize,
                hairColor: app.hairColor?.id,
                hairLength: app.hairLength?.id,
                eyeColor: app.eyeColor?.id,
                skinColor: app.skinColor?.id
            )
        }
        let model: ModelData? = (detail.model?.description != nil || appearance != nil)
            ? ModelData(description: detail.model?.description, appearance: appearance)
            : nil
        self.init(
            fullName: fullName,
            gender: detail.gender?.id,
            birthday: detail.birthday,
            model: model
        )
    }
}

public extension UpdateDescriptionAgencyRequest {
    /// Полный payload для `/agency/update` с переопределённым названием — остальные поля агентства
    /// сохраняем из текущего профиля.
    init(preserving detail: UserDetail, title: String) {
        self.init(
            agencyId: detail.agency?.id,
            title: title,
            description: detail.agency?.description,
            background: detail.agency?.background?.fileUuid.map { AvatarUuid(uuid: $0) },
            photo: detail.agency?.photo?.fileUuid.map { AvatarUuid(uuid: $0) },
            // Без города address не шлём: {"cityId": null} при replace затёр бы город на беке
            address: (detail.agency?.address?.city?.id).map { UpdateAgencyAddress(cityId: $0) }
        )
    }
}
