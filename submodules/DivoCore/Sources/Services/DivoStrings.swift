import Foundation

// MARK: - DivoStrings
// Lightweight localization for DIVO screens only.
// Supported: English, Russian, Spanish, Portuguese, Chinese.
// Fallback: English for any unsupported device language.

public enum DivoStrings {

    public enum Language: String, CaseIterable {
        case en, ru, es, pt, zh

        public var displayName: String {
            switch self {
            case .en: return "English"
            case .ru: return "Русский"
            case .es: return "Español"
            case .pt: return "Português"
            case .zh: return "中文"
            }
        }

        /// Telegram server language pack code
        public var telegramCode: String {
            switch self {
            case .en: return "en"
            case .ru: return "ru"
            case .es: return "es"
            case .pt: return "pt-br"
            case .zh: return "zh-hans"
            }
        }

        /// Locale identifier for DateFormatter and other locale-sensitive APIs
        public var localeIdentifier: String {
            switch self {
            case .en: return "en_US"
            case .ru: return "ru_RU"
            case .es: return "es_ES"
            case .pt: return "pt_BR"
            case .zh: return "zh_Hans"
            }
        }
    }

    private static let overrideKey = "DivoStrings.languageOverride"

    public static let didChangeNotification = Notification.Name("DivoStrings.didChange")

    public static var deviceLanguage: Language {
        guard let preferred = Locale.preferredLanguages.first else { return .en }
        let code = String(preferred.prefix(2))
        return Language(rawValue: code) ?? .en
    }

    public static var current: Language {
        get {
            if let raw = UserDefaults.standard.string(forKey: overrideKey),
               let lang = Language(rawValue: raw) {
                return lang
            }
            return deviceLanguage
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: overrideKey)
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
    }

    public static var isOverridden: Bool {
        UserDefaults.standard.string(forKey: overrideKey) != nil
    }

    public static func resetToDeviceLanguage() {
        UserDefaults.standard.removeObject(forKey: overrideKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    private static func L(en: String, ru: String, es: String, pt: String, zh: String) -> String {
        switch current {
        case .en: return en
        case .ru: return ru
        case .es: return es
        case .pt: return pt
        case .zh: return zh
        }
    }

    // MARK: - Login

    public static var loginEulaAgreement: String { L(en: "By using DIVO, you agree to Apple's end User License Agreement and our Terms of Service and Privacy Policy.", ru: "Используя DIVO, вы соглашаетесь с Лицензионным соглашением Apple и нашими Условиями использования и Политикой конфиденциальности.", es: "Al usar DIVO, aceptas el Acuerdo de licencia de usuario final de Apple y nuestros Términos de servicio y Política de privacidad.", pt: "Ao usar o DIVO, você concorda com o Contrato de licença de usuário final da Apple e nossos Termos de serviço e Política de privacidade.", zh: "使用 DIVO 即表示您同意 Apple 的最终用户许可协议以及我们的服务条款和隐私政策。") }

    // MARK: - Tab Bar

    public static var tabModels: String { L(en: "Models", ru: "Модели", es: "Modelos", pt: "Modelos", zh: "模特") }
    public static var tabEvents: String { L(en: "Events", ru: "События", es: "Eventos", pt: "Eventos", zh: "活动") }
    public static var tabChats: String { L(en: "Chats", ru: "Чаты", es: "Chats", pt: "Chats", zh: "聊天") }
    public static var tabSettings: String { L(en: "Settings", ru: "Настройки", es: "Ajustes", pt: "Configurações", zh: "设置") }

    // MARK: - Nav Titles

    public static var navModels: String { L(en: "MODELS", ru: "МОДЕЛИ", es: "MODELOS", pt: "MODELOS", zh: "模特") }
    public static var navEvents: String { L(en: "EVENTS", ru: "СОБЫТИЯ", es: "EVENTOS", pt: "EVENTOS", zh: "活动") }
    public static var back: String { L(en: "Back", ru: "Назад", es: "Atrás", pt: "Voltar", zh: "返回") }
    public static var close: String { L(en: "Close", ru: "Закрыть", es: "Cerrar", pt: "Fechar", zh: "关闭") }
    public static var navCreateExperience: String { L(en: "CREATE EXPERIENCE", ru: "ДОБАВИТЬ ОПЫТ", es: "CREAR EXPERIENCIA", pt: "CRIAR EXPERIÊNCIA", zh: "创建经历") }
    public static var navEditExperience: String { L(en: "EDIT EXPERIENCE", ru: "РЕДАКТИРОВАТЬ ОПЫТ", es: "EDITAR EXPERIENCIA", pt: "EDITAR EXPERIÊNCIA", zh: "编辑经历") }
    public static var navCreateEvent: String { L(en: "CREATE EVENT", ru: "ДОБАВИТЬ СОБЫТИЕ", es: "CREAR EVENTO", pt: "CRIAR EVENTO", zh: "创建活动") }
    public static var navEditEvent: String { L(en: "EDIT EVENT", ru: "РЕДАКТИРОВАТЬ СОБЫТИЕ", es: "EDITAR EVENTO", pt: "EDITAR EVENTO", zh: "编辑活动") }

    // MARK: - Feed Segments

    public static var feedSubscribed: String { L(en: "MODELS", ru: "МОДЕЛИ", es: "MODELOS", pt: "MODELOS", zh: "模特") }
    public static var feedAllUsers: String { L(en: "NEW TALENTS", ru: "ТАЛАНТЫ", es: "NUEVOS TALENTOS", pt: "NOVOS TALENTOS", zh: "新人才") }
    public static var feedAgencies: String { L(en: "AGENCIES", ru: "АГЕНТСТВА", es: "AGENCIAS", pt: "AGÊNCIAS", zh: "经纪公司") }
    public static var addStory: String { L(en: "Add Story", ru: "Добавить", es: "Añadir", pt: "Adicionar", zh: "添加动态") }
    public static var feedSearchPlaceholder: String { L(en: "Search by name or @handle", ru: "Поиск по имени или @handle", es: "Buscar por nombre o @ identificador", pt: "Procurar por nome ou @ identificador", zh: "按名称或@handle搜索") }
    public static var feedSearchNoFound: String { L(en: "NO RESULTS FOUND", ru: "НИКАКИХ РЕЗУЛЬТАТОВ НАЙДЕНО НЕ БЫЛО", es: "NO SE HAN ENCONTRADO RESULTADOS", pt: "NÃO FORAM ENCONTRADOS RESULTADOS", zh: "未找到结果") }
    public static var feedSearchNoFilters: String { L(en: "Try adjusting your filters", ru: "Попробуйте настроить свои фильтры", es: "Intenta ajustar tus filtros", pt: "Tente ajustar seus filtros", zh: "尝试调整过滤器") }
    public static func feedSearchCount(_ totalCount: Int, _ query: String) -> String {
        L(en: "\(totalCount) results for \"\(query)\"", ru: "\(totalCount) результаты для \"\(query)\"", es: "\(totalCount) resultados para \"\(query)\"", pt: "\(totalCount) resultados para \"\(query)\"", zh: "\(totalCount) 结果为 \"\(query)\"")
    }
    public static func feedSearchCountNoQuery(_ totalCount: Int) -> String {
        L(en: "\(totalCount) results", ru: "\(totalCount) результатов", es: "\(totalCount) resultados", pt: "\(totalCount) resultados", zh: "\(totalCount)个结果")
    }
    public static var feedSearchFilter: String { L(en: "Filter", ru: "Фильтр", es: "Filtro", pt: "Filtro", zh: "过滤器") }
    public static var feedSearchReset: String { L(en: "Reset", ru: "Сбросить", es: "Restablecer", pt: "Redefinir", zh: "重置") }
    public static var feedSearchApplyFilter: String { L(en: "Apply filter", ru: "Применить фильтр", es: "Aplicar filtro", pt: "Aplicar filtro", zh: "应用筛选") }
    public static var feedSearchAllRoles: String { L(en: "All roles", ru: "Все роли", es: "Todos los roles", pt: "Todos as funções", zh: "所有角色") }
    public static var feedSearchAllGenders: String { L(en: "All genders", ru: "Все гендеры", es: "Todos los géneros", pt: "Todos os gêneros", zh: "所有性别") }
    public static var feedSearchCountry: String { L(en: "Search by country", ru: "Поиск по стране", es: "Buscar por país", pt: "Pesquisar por país", zh: "按国家搜索") }
    public static var feedSearchAllCountries: String { L(en: "All countries", ru: "Все страны", es: "Todos los países", pt: "Todos os países", zh: "所有国家") }
    public static var feedSearchResetParameter: String { L(en: "Reset parameter", ru: "Сбросить параметр", es: "Restablecer parámetro", pt: "Redefinir parâmetro", zh: "重置参数") }
    public static var feedSearchResetFilters: String { L(en: "Reset filters", ru: "Сбросить фильтры", es: "Restablecer filtros", pt: "Redefinir filtros", zh: "重置筛选") }
    public static var feedSearchMoreFilters: String { L(en: "More parameters", ru: "Больше параметров", es: "Más parámetros", pt: "Mais parâmetros", zh: "更多参数") }
    public static var feedSearchLessFilters: String { L(en: "Less parameters", ru: "Меньше параметров", es: "Menos parámetros", pt: "Menos parâmetros", zh: "更少参数") }
    public static var feedSearchFiltersLoadFailed: String { L(en: "Failed to load filters", ru: "Не удалось загрузить фильтры", es: "Error al cargar filtros", pt: "Falha ao carregar filtros", zh: "加载筛选器失败") }
    public static var feedSearchResultsLoadFailed: String { L(en: "Failed to load search results", ru: "Не удалось загрузить результаты поиска", es: "Error al cargar resultados", pt: "Falha ao carregar resultados", zh: "加载搜索结果失败") }

    // MARK: - Face Recognition

    public static var faceRecognitionSheetTitle: String { L(en: "Find similar profiles", ru: "Найти похожие профили", es: "Buscar perfiles similares", pt: "Encontrar perfis semelhantes", zh: "查找相似档案") }
    public static var faceRecognitionSheetSubtitle: String { L(en: "Upload a photo to find models with a similar appearance", ru: "Загрузите фото, чтобы найти моделей с похожей внешностью", es: "Sube una foto para encontrar modelos con una apariencia similar", pt: "Envie uma foto para encontrar modelos com aparência semelhante", zh: "上传照片以查找外貌相似的模特") }
    public static var faceRecognitionTakePhoto: String { L(en: "Take a photo", ru: "Сделать фото", es: "Tomar una foto", pt: "Tirar uma foto", zh: "拍照") }
    public static var faceRecognitionChooseFromLibrary: String { L(en: "Choose from library", ru: "Выбрать из галереи", es: "Elegir de la galería", pt: "Escolher da galeria", zh: "从相册选择") }
    public static var faceRecognitionUseDivoPhoto: String { L(en: "Use a DIVO profile photo", ru: "Использовать фото профиля DIVO", es: "Usar foto de perfil DIVO", pt: "Usar foto do perfil DIVO", zh: "使用DIVO头像") }
    public static var faceRecognitionProfileSearchPlaceholder: String { L(en: "Search by name or @handle", ru: "Поиск по имени или @handle", es: "Buscar por nombre o @handle", pt: "Buscar por nome ou @handle", zh: "按姓名或@handle 搜索") }
    public static var faceRecognitionProfilePhotoLoadFailed: String { L(en: "Couldn't load profile photo", ru: "Не удалось загрузить фото профиля", es: "No se pudo cargar la foto del perfil", pt: "Não foi possível carregar a foto do perfil", zh: "无法加载个人资料照片") }
    public static var faceSearchInfoTitle: String { L(en: "How face search works", ru: "Как работает поиск по фото", es: "Cómo funciona la búsqueda facial", pt: "Como funciona a busca facial", zh: "人脸搜索的工作原理") }
    public static var faceSearchInfoMessage: String { L(en: "We analyse your photo to find DIVO profiles with a similar appearance. Your photo is used for this search only and is not stored or shared.\n\nResults are ranked by visual similarity. Use the filters to narrow down by location, role, and other criteria.", ru: "Мы анализируем ваше фото, чтобы найти профили DIVO с похожей внешностью. Фото используется только для этого поиска и не сохраняется.\n\nРезультаты ранжируются по визуальному сходству. Используйте фильтры, чтобы уточнить по локации, роли и другим критериям.", es: "Analizamos tu foto para encontrar perfiles DIVO con apariencia similar. Tu foto se usa solo para esta búsqueda y no se almacena ni comparte.\n\nLos resultados se clasifican por similitud visual. Usa los filtros para refinar por ubicación, rol y otros criterios.", pt: "Analisamos sua foto para encontrar perfis DIVO com aparência semelhante. Sua foto é usada apenas para esta busca e não é armazenada ou compartilhada.\n\nOs resultados são classificados por similaridade visual. Use os filtros para refinar por localização, função e outros critérios.", zh: "我们分析您的照片以查找外貌相似的DIVO档案。您的照片仅用于此次搜索，不会被存储或分享。\n\n结果按视觉相似度排列。使用筛选器按位置、角色和其他条件缩小范围。") }
    public static var faceSearchInfoButton: String { L(en: "Got it, let's search", ru: "Понятно, начать поиск", es: "Entendido, buscar", pt: "Entendi, vamos buscar", zh: "明白了，开始搜索") }
    public static var faceSearchScreenTitle: String { L(en: "FACE SEARCH", ru: "ПОИСК ПО ФОТО", es: "BÚSQUEDA FACIAL", pt: "BUSCA FACIAL", zh: "人脸搜索") }
    public static var faceSearchChangePhoto: String { L(en: "Change photo", ru: "Изменить фото", es: "Cambiar foto", pt: "Alterar foto", zh: "更换照片") }
    public static var faceSearchTryDifferentPhoto: String { L(en: "Try a different photo", ru: "Попробовать другое фото", es: "Probar con otra foto", pt: "Tentar outra foto", zh: "尝试其他照片") }
    public static var faceSearchBrowseAllProfiles: String { L(en: "Browse all profiles", ru: "Смотреть все профили", es: "Ver todos los perfiles", pt: "Ver todos os perfis", zh: "浏览所有档案") }
    public static var faceSearchFindProfiles: String { L(en: "Find similar profiles", ru: "Найти похожие профили", es: "Buscar perfiles similares", pt: "Encontrar perfis semelhantes", zh: "查找相似档案") }
    public static var faceSearchSortedByScore: String { L(en: "Results are sorted by visual similarity score", ru: "Результаты отсортированы по степени сходства", es: "Resultados ordenados por similitud visual", pt: "Resultados ordenados por pontuação de similaridade", zh: "结果按视觉相似度排序") }
    public static var faceSearchNoFacesTitle: String { L(en: "No faces found", ru: "Лица не найдены", es: "No se encontraron rostros", pt: "Nenhum rosto encontrado", zh: "未找到人脸") }
    public static var faceSearchNoFacesMessage: String { L(en: "We couldn't detect any faces in this photo. Please try another one.", ru: "Не удалось распознать лица на этом фото. Попробуйте другое.", es: "No pudimos detectar rostros en esta foto. Intenta con otra.", pt: "Não conseguimos detectar rostos nesta foto. Tente outra.", zh: "未能在此照片中检测到人脸，请尝试其他照片。") }
    public static var faceSearchErrorTitle: String { L(en: "Search error", ru: "Ошибка поиска", es: "Error de búsqueda", pt: "Erro de busca", zh: "搜索错误") }
    public static var faceSearchResultsTitle: String { L(en: "Results", ru: "Результаты", es: "Resultados", pt: "Resultados", zh: "结果") }
    public static var faceSearchNoResults: String { L(en: "No matching profiles found", ru: "Подходящие профили не найдены", es: "No se encontraron perfiles coincidentes", pt: "Nenhum perfil correspondente encontrado", zh: "未找到匹配的档案") }
    public static var faceSearchMatchPercent: String { L(en: "match", ru: "сходство", es: "coincidencia", pt: "similaridade", zh: "匹配") }
    public static func faceSearchMatchPercentBadge(_ percent: Int) -> String { "\(percent)%" }
    public static var faceSearchScanning: String { L(en: "Analysing facial features...", ru: "Анализируем черты лица...", es: "Analizando rasgos faciales...", pt: "Analisando características faciais...", zh: "正在分析面部特征...") }
    public static var faceSearchNoFaceDetected: String { L(en: "No face detected", ru: "Лицо не обнаружено", es: "No se detectó rostro", pt: "Nenhum rosto detectado", zh: "未检测到人脸") }
    public static var faceSearchNoFaceTip: String { L(en: "Try a photo with a clearly visible face", ru: "Попробуйте фото с чётко видимым лицом", es: "Prueba con una foto donde el rostro sea visible", pt: "Tente uma foto com o rosto claramente visível", zh: "请尝试使用面部清晰可见的照片") }
    public static var faceSearchNoFaceDescription: String { L(en: "Please use a photo where a face is clearly visible — front-facing, well-lit, and unobstructed.", ru: "Используйте фото, на котором лицо чётко видно — анфас, хорошо освещённое, без перекрытий.", es: "Usa una foto donde el rostro sea claramente visible — de frente, bien iluminado y sin obstrucciones.", pt: "Use uma foto onde o rosto esteja claramente visível — de frente, bem iluminado e sem obstruções.", zh: "请使用面部清晰可见的照片——正面、光线充足且无遮挡。") }
    public static var faceSearchNoFaceBullet1: String { L(en: "Avoid sunglasses, masks, or heavy cropping.", ru: "Избегайте солнцезащитных очков, масок и сильной обрезки.", es: "Evita gafas de sol, mascarillas o recortes excesivos.", pt: "Evite óculos de sol, máscaras ou cortes excessivos.", zh: "避免佩戴太阳镜、口罩或过度裁剪。") }
    public static var faceSearchNoFaceBullet2: String { L(en: "Full-face photos work best — not side profiles.", ru: "Лучше всего подходят фото анфас, а не в профиль.", es: "Las fotos de frente funcionan mejor — no perfiles laterales.", pt: "Fotos de frente funcionam melhor — não perfis laterais.", zh: "正面照片效果最佳——不要侧面照。") }
    public static var faceSearchFaceSelected: String { L(en: "Face selected — ready to search", ru: "Лицо выбрано — готово к поиску", es: "Rostro seleccionado — listo para buscar", pt: "Rosto selecionado — pronto para buscar", zh: "已选择人脸 - 准备搜索") }
    public static func faceSearchMultipleFaces(_ count: Int) -> String { L(en: "\(count) faces detected — tap one to search", ru: "Обнаружено лиц: \(count) — нажмите для поиска", es: "\(count) rostros detectados — toca uno para buscar", pt: "\(count) rostos detectados — toque em um para buscar", zh: "检测到\(count)张人脸 - 点击选择") }
    public static var faceSearchRetry: String { L(en: "Retry", ru: "Повторить", es: "Reintentar", pt: "Tentar novamente", zh: "重试") }
    public static var faceSearchRetrySearch: String { L(en: "Retry search", ru: "Повторить поиск", es: "Reintentar búsqueda", pt: "Tentar busca novamente", zh: "重新搜索") }
    public static var faceSearchErrorNoInternet: String { L(en: "No internet connection", ru: "Нет подключения к интернету", es: "Sin conexión a internet", pt: "Sem conexão com a internet", zh: "无网络连接") }
    public static var faceSearchErrorGeneric: String { L(en: "Something went wrong", ru: "Что-то пошло не так", es: "Algo salió mal", pt: "Algo deu errado", zh: "出了点问题") }
    public static var faceSearchErrorTip: String { L(en: "Check your connection and try again", ru: "Проверьте соединение и попробуйте снова", es: "Verifica tu conexión e intenta de nuevo", pt: "Verifique sua conexão e tente novamente", zh: "请检查网络连接并重试") }
    public static var faceSearchInterruptedTitle: String { L(en: "Search interrupted", ru: "Поиск прерван", es: "Búsqueda interrumpida", pt: "Busca interrompida", zh: "搜索已中断") }
    public static var faceSearchInterruptedSubtitle: String { L(en: "Connection lost during analysis. Photo is ready — just retry", ru: "Соединение потеряно при анализе. Фото готово — просто повторите", es: "Se perdió la conexión durante el análisis. La foto está lista — solo reinténtalo", pt: "Conexão perdida durante a análise. A foto está pronta — é só tentar novamente", zh: "分析过程中连接中断。照片已就绪 — 请重试") }
    public static var faceSearchServerErrorTitle: String { L(en: "Server error", ru: "Ошибка сервера", es: "Error del servidor", pt: "Erro do servidor", zh: "服务器错误") }
    public static var faceSearchServerErrorSubtitle: String { L(en: "Something went wrong. Photo is ready — just retry", ru: "Что-то пошло не так. Фото готово — просто повторите", es: "Algo salió mal. La foto está lista — solo reinténtalo", pt: "Algo deu errado. A foto está pronta — é só tentar novamente", zh: "出了点问题。照片已就绪 — 请重试") }
    public static var faceSearchSimilarProfilesTitle: String { L(en: "Similar profiles", ru: "Похожие профили", es: "Perfiles similares", pt: "Perfis semelhantes", zh: "相似档案") }
    public static func faceSearchResultsCount(_ count: Int) -> String { L(en: "\(count) results", ru: "Результатов: \(count)", es: "\(count) resultados", pt: "\(count) resultados", zh: "\(count) 个结果") }
    public static func faceSearchSimilarityThreshold(_ percent: Int) -> String { L(en: "Similarity \(percent)%+", ru: "Сходство от \(percent)%", es: "Similitud \(percent)%+", pt: "Similaridade \(percent)%+", zh: "相似度 \(percent)%+") }
    public static func faceSearchProfilesFound(_ count: Int) -> String { L(en: "\(count) profiles found", ru: "Найдено профилей: \(count)", es: "\(count) perfiles encontrados", pt: "\(count) perfis encontrados", zh: "找到 \(count) 个档案") }
    public static var faceSearchSortedBy: String { L(en: "Sorted by:", ru: "Сортировка:", es: "Ordenado por:", pt: "Ordenado por:", zh: "排序依据：") }
    public static var faceSearchSortMatch: String { L(en: "match", ru: "сходство", es: "coincidencia", pt: "similaridade", zh: "匹配度") }
    public static var faceSearchNoResultsSubtitle: String { L(en: "We couldn't find profiles visually similar to this photo. Try a different photo with a clearer, front-facing face.", ru: "Мы не нашли профили, визуально похожие на это фото. Попробуйте другое фото — с чётко видимым лицом, смотрящим в камеру.", es: "No encontramos perfiles visualmente similares a esta foto. Prueba con otra foto que muestre un rostro más claro, mirando de frente.", pt: "Não encontramos perfis visualmente semelhantes a esta foto. Tente outra foto com o rosto mais nítido e voltado para a câmera.", zh: "未找到与此照片视觉上相似的档案。请尝试使用面部更清晰、正面朝向的其他照片。") }
    public static var faceSearchFilterTitle: String { L(en: "Filter results", ru: "Фильтр результатов", es: "Filtrar resultados", pt: "Filtrar resultados", zh: "筛选结果") }
    public static var faceSearchFilterSimilarity: String { L(en: "Minimum similarity", ru: "Минимальное сходство", es: "Similitud mínima", pt: "Similaridade mínima", zh: "最低相似度") }
    public static var faceSearchFilterSimilarityHint: String { L(en: "Higher values show fewer but closer matches", ru: "Чем выше значение, тем меньше, но ближе совпадений", es: "Valores más altos muestran menos coincidencias, pero más cercanas", pt: "Valores mais altos mostram menos correspondências, porém mais próximas", zh: "数值越高，匹配结果越少但越精准") }
    public static func faceSearchFallbackMessage(original: Int, actual: Int) -> String { L(en: "No results at \(original)% similarity — showing results at \(actual)% instead.", ru: "Нет результатов при \(original)% сходства — показываем результаты при \(actual)%.", es: "Sin resultados al \(original)% de similitud — mostrando resultados al \(actual)%.", pt: "Sem resultados com \(original)% de similaridade — mostrando resultados com \(actual)%.", zh: "在 \(original)% 相似度下无结果 — 改为显示 \(actual)% 的结果。") }
    public static var faceSearchAdjustFilters: String { L(en: "Adjust filters", ru: "Настроить", es: "Ajustar filtros", pt: "Ajustar filtros", zh: "调整筛选") }
    public static var faceSearchNoResultsWithFilters: String { L(en: "No results found — try adjusting your filters", ru: "Ничего не найдено — попробуйте изменить фильтры", es: "Sin resultados — intenta ajustar los filtros", pt: "Sem resultados — tente ajustar os filtros", zh: "未找到结果 — 请尝试调整筛选条件") }

    // MARK: - Face Search History

    public static var faceSearchHistoryTitle: String { L(en: "Recent face searches", ru: "Недавние поиски по фото", es: "Búsquedas faciales recientes", pt: "Buscas faciais recentes", zh: "最近的人脸搜索") }
    public static var faceSearchHistorySeeAll: String { L(en: "See all", ru: "Все", es: "Ver todo", pt: "Ver tudo", zh: "查看全部") }
    public static func faceSearchHistoryResultsFound(_ count: Int) -> String { L(en: "\(count) results found", ru: "Найдено результатов: \(count)", es: "\(count) resultados encontrados", pt: "\(count) resultados encontrados", zh: "找到 \(count) 个结果") }
    public static var faceSearchHistoryScreenTitle: String { L(en: "Face search history", ru: "История поиска по фото", es: "Historial de búsqueda facial", pt: "Histórico de busca facial", zh: "人脸搜索历史") }
    public static var faceSearchHistoryClearAll: String { L(en: "Clear All", ru: "Очистить", es: "Borrar todo", pt: "Limpar tudo", zh: "清除全部") }
    public static var faceSearchHistoryNoFilters: String { L(en: "No filters", ru: "Без фильтров", es: "Sin filtros", pt: "Sem filtros", zh: "无筛选") }
    public static func faceSearchHistorySimilarity(_ percent: Int) -> String { L(en: "Similarity \(percent)%", ru: "Сходство \(percent)%", es: "Similitud \(percent)%", pt: "Similaridade \(percent)%", zh: "相似度 \(percent)%") }
    public static var faceSearchHistoryNoSearchesTitle: String { L(en: "No searches yet", ru: "Поисков пока нет", es: "Sin búsquedas aún", pt: "Nenhuma busca ainda", zh: "暂无搜索") }
    public static var faceSearchHistoryNoSearchesSubtitle: String { L(en: "Your face match searches will appear here automatically.", ru: "Ваши поиски по фото появятся здесь автоматически.", es: "Tus búsquedas faciales aparecerán aquí automáticamente.", pt: "Suas buscas faciais aparecerão aqui automaticamente.", zh: "您的人脸搜索将自动显示在此处。") }
    public static var faceSearchHistoryStartSearch: String { L(en: "Start a face search", ru: "Начать поиск по фото", es: "Iniciar búsqueda facial", pt: "Iniciar busca facial", zh: "开始人脸搜索") }

    // MARK: - Roles

    public static var roleModel: String { L(en: "Model", ru: "Модель", es: "Modelo", pt: "Modelo", zh: "模特") }
    public static var roleNewFace: String { L(en: "New face", ru: "Новое лицо", es: "Cara nueva", pt: "Rosto novo", zh: "新面孔") }
    public static var roleAgency: String { L(en: "Agency", ru: "Агентство", es: "Agencia", pt: "Agência", zh: "经纪公司") }
    public static var statusModel: String { L(en: "♦️ model", ru: "♦️ модель", es: "♦️ modelo", pt: "♦️ modelo", zh: "♦️ 模特") }

    // MARK: - Profile Edit Menu

    public static var editProfile: String { L(en: "Edit Profile", ru: "Редактировать профиль", es: "Editar perfil", pt: "Editar perfil", zh: "编辑资料") }
    public static var changeBackground: String { L(en: "Change Profile Background", ru: "Сменить фон профиля", es: "Cambiar fondo de perfil", pt: "Alterar fundo do perfil", zh: "更换资料背景") }
    public static var editSocialLinksMenu: String { L(en: "Edit Social Links", ru: "Редактировать ссылки", es: "Editar redes sociales", pt: "Editar redes sociais", zh: "编辑社交链接") }
    public static var manageWorkExperience: String { L(en: "Manage Work Experience", ru: "Управление опытом работы", es: "Gestionar experiencia", pt: "Gerenciar experiência", zh: "管理工作经历") }
    public static var addPhoto: String { L(en: "Add new photo", ru: "Добавить новое фото", es: "Agregar nueva foto", pt: "Adicionar nova foto", zh: "添加新照片") }
    public static var addVideo: String { L(en: "Add new video", ru: "Добавить новое видео", es: "Agregar nuevo vídeo", pt: "Adicionar novo vídeo", zh: "添加新视频") }

    public static var findSimilar: String { L(en: "Find similar profiles", ru: "Найти похожие профили", es: "Encontrar perfiles similares", pt: "Encontrar perfis semelhantes", zh: "查找相似资料") }
    public static var reportProfile: String { L(en: "Report this profile", ru: "Пожаловаться на профиль", es: "Reportar este perfil", pt: "Denunciar este perfil", zh: "举报此资料") }
    public static var blockUser: String { L(en: "Block user", ru: "Заблокировать пользователя", es: "Bloquear usuario", pt: "Bloquear usuário", zh: "屏蔽用户") }

    // MARK: - Profile Counters & Actions

    public static var counterLike: String { L(en: "Like", ru: "Нравится", es: "Me gusta", pt: "Curtir", zh: "喜欢") }
    public static var counterViewed: String { L(en: "Viewed", ru: "Просмотры", es: "Visto", pt: "Visto", zh: "已查看") }
    public static var counterSave: String { L(en: "Save", ru: "Сохранить", es: "Guardar", pt: "Salvar", zh: "收藏") }
    public static var uploadYourPhotos: String { L(en: "Upload your photos", ru: "Загрузите фото", es: "Sube tus fotos", pt: "Envie suas fotos", zh: "上传您的照片") }
    public static var noPhotosYet: String { L(en: "No photos yet", ru: "Фото пока нет", es: "Aún no hay fotos", pt: "Ainda sem fotos", zh: "暂无照片") }
    public static var uploadYourVideos: String { L(en: "Upload your videos", ru: "Загрузите видео", es: "Sube tus videos", pt: "Envie seus vídeos", zh: "上传您的视频") }
    public static var noVideosYet: String { L(en: "No videos yet", ru: "Видео пока нет", es: "Sin videos aún", pt: "Sem vídeos ainda", zh: "暂无视频") }
    public static var noChannelsYet: String { L(en: "No channels yet", ru: "Каналов пока нет", es: "Sin canales aún", pt: "Sem canais ainda", zh: "暂无频道") }
    public static var noModelsYet: String { L(en: "No models yet", ru: "Моделей пока нет", es: "Sin modelos aún", pt: "Sem modelos ainda", zh: "暂无模特") }
    public static var noEventsYet: String { L(en: "No events yet", ru: "Событий пока нет", es: "Sin eventos aún", pt: "Sem eventos ainda", zh: "暂无活动") }
    public static var noUpcomingEventsSubtitle: String { L(en: "There are no upcoming events at the moment", ru: "На данный момент ближайших событий нет", es: "No hay eventos próximos en este momento", pt: "Não há eventos próximos no momento", zh: "目前没有即将举行的活动") }
    public static var addChannel: String { L(en: "Add channel", ru: "Добавить канал", es: "Agregar canal", pt: "Adicionar canal", zh: "添加频道") }
    public static var addModel: String { L(en: "Add model", ru: "Добавить модель", es: "Agregar modelo", pt: "Adicionar modelo", zh: "添加模特") }
    public static var addEvent: String { L(en: "Add event", ru: "Добавить событие", es: "Agregar evento", pt: "Adicionar evento", zh: "添加活动") }
    public static var uploadingPhotos: String { L(en: "Uploading Photos...", ru: "Загрузка фото...", es: "Subiendo fotos...", pt: "Enviando fotos...", zh: "上传照片中...") }
    public static var uploadingVideos: String { L(en: "Uploading Videos...", ru: "Загрузка видео...", es: "Subiendo videos...", pt: "Enviando vídeos...", zh: "上传视频中...") }
    public static var loadingChannels: String { L(en: "Loading channels...", ru: "Загрузка каналов...", es: "Cargando canales...", pt: "Carregando canais...", zh: "加载频道中...") }
    public static var loadingModels: String { L(en: "Loading models...", ru: "Загрузка моделей...", es: "Cargando modelos...", pt: "Carregando modelos...", zh: "加载模特中...") }
    public static var loadingEvents: String { L(en: "Loading events...", ru: "Загрузка событий...", es: "Cargando eventos...", pt: "Carregando eventos...", zh: "加载活动中...") }
    public static var noName: String { L(en: "No name", ru: "Без имени", es: "Sin nombre", pt: "Sem nome", zh: "无名") }
    public static var errorUploadingPhotos: String { L(en: "Couldn't add photo", ru: "Не удалось добавить фото", es: "No se pudo agregar la foto", pt: "Não foi possível adicionar a foto", zh: "无法添加照片") }
    public static var errorUploadingVideos: String { L(en: "Couldn't add video", ru: "Не удалось добавить видео", es: "No se pudo agregar el video", pt: "Não foi possível adicionar o vídeo", zh: "无法添加视频") }
    public static var errorUpdateBackground: String { L(en: "Couldn't update profile background", ru: "Не удалось обновить фон профиля", es: "No se pudo actualizar el fondo del perfil", pt: "Não foi possível atualizar o fundo do perfil", zh: "无法更新个人资料背景") }
    public static var errorLoadingSimilarProfiles: String { L(en: "Couldn't find similar profiles", ru: "Не удалось найти похожие профили", es: "No se pudieron encontrar perfiles similares", pt: "Não foi possível encontrar perfis semelhantes", zh: "无法找到相似的个人资料") }

    // MARK: - Units

    public static func ageString(_ age: Int) -> String {
        L(en: "\(age) y.o", ru: "\(age) \(pluralRu(age, "год", "года", "лет"))", es: "\(age) años", pt: "\(age) anos", zh: "\(age)岁")
    }
    public static var unitCm: String { "cm" }
    public static var unitKg: String { L(en: "kg", ru: "кг", es: "kg", pt: "kg", zh: "公斤") }
    public static var unitEU: String { "EU" }

    // MARK: - Appearance Attributes

    public static var attrGender: String { L(en: "Gender", ru: "Пол", es: "Género", pt: "Gênero", zh: "性别") }
    public static var attrHeight: String { L(en: "Height", ru: "Рост", es: "Altura", pt: "Altura", zh: "身高") }
    public static var attrWeight: String { L(en: "Weight", ru: "Вес", es: "Peso", pt: "Peso", zh: "体重") }
    public static var attrBust: String { L(en: "Bust", ru: "Грудь", es: "Busto", pt: "Busto", zh: "胸围") }
    public static var attrWaist: String { L(en: "Waist", ru: "Талия", es: "Cintura", pt: "Cintura", zh: "腰围") }
    public static var attrHips: String { L(en: "Hips", ru: "Бёдра", es: "Caderas", pt: "Quadris", zh: "臀围") }
    public static var attrShoes: String { L(en: "Shoes", ru: "Обувь", es: "Zapatos", pt: "Sapatos", zh: "鞋码") }
    public static var attrHairColor: String { L(en: "Hair Color", ru: "Цвет волос", es: "Color de cabello", pt: "Cor do cabelo", zh: "发色") }
    public static var attrHairLength: String { L(en: "Hair Length", ru: "Длина волос", es: "Largo del cabello", pt: "Comprimento do cabelo", zh: "头发长度") }
    public static var attrEyeColor: String { L(en: "Eye Color", ru: "Цвет глаз", es: "Color de ojos", pt: "Cor dos olhos", zh: "眼睛颜色") }
    public static var attrSkinColor: String { L(en: "Skin Color", ru: "Цвет кожи", es: "Color de piel", pt: "Cor da pele", zh: "肤色") }

    // MARK: - Settings

    public static var settings: String { L(en: "SETTINGS", ru: "НАСТРОЙКИ", es: "AJUSTES", pt: "CONFIGURAÇÕES", zh: "设置") }
    public static var settingsEdit: String { L(en: "Edit", ru: "Ред.", es: "Editar", pt: "Editar", zh: "编辑") }
    public static var settingsSetUsername: String { L(en: "Set Username", ru: "Установить имя", es: "Establecer nombre", pt: "Definir nome", zh: "设置用户名") }
    public static var settingsFillParameters: String { L(en: "Fill your parameters", ru: "Заполните параметры", es: "Complete sus parámetros", pt: "Preencha seus parâmetros", zh: "填写您的参数") }
    public static var settingsBannerTitle: String { L(en: "GET DISCOVERED IN THE FASHION WORLD", ru: "СТАНЬ ЗАМЕТНЫМ В МИРЕ МОДЫ", es: "HAZTE NOTAR EN EL MUNDO DE LA MODA", pt: "SEJA DESCOBERTO NO MUNDO DA MODA", zh: "在时尚界崭露头角") }
    public static var settingsBannerDescription: String { L(en: "Publish your profile as a model, join castings or add events as agency — be part of the global fashion network.", ru: "Опубликуйте профиль модели, участвуйте в кастингах или добавляйте события — станьте частью мировой fashion-сети.", es: "Publica tu perfil como modelo, únete a castings o añade eventos como agencia — forma parte de la red global de moda.", pt: "Publique seu perfil como modelo, participe de castings ou adicione eventos como agência — faça parte da rede global de moda.", zh: "发布您的模特资料，参加选角或作为经纪公司添加活动——成为全球时尚网络的一部分。") }
    public static var settingsLearnMore: String { L(en: "LEARN MORE", ru: "УЗНАТЬ БОЛЬШЕ", es: "MÁS INFORMACIÓN", pt: "SAIBA MAIS", zh: "了解更多") }

    // MARK: - Common

    public static var ok: String { L(en: "OK", ru: "OK", es: "OK", pt: "OK", zh: "好的") }
    public static var cancel: String { L(en: "Cancel", ru: "Отмена", es: "Cancelar", pt: "Cancelar", zh: "取消") }
    public static var save: String { L(en: "Save", ru: "Сохранить", es: "Guardar", pt: "Salvar", zh: "保存") }
    public static var saving: String { L(en: "Saving...", ru: "Сохранение...", es: "Guardando...", pt: "Salvando...", zh: "保存中...") }
    public static var nextStep: String { L(en: "Next Step", ru: "Следующий шаг", es: "Siguiente Paso", pt: "Próximo Passo", zh: "下一步") }
    public static var delete: String { L(en: "Delete", ru: "Удалить", es: "Eliminar", pt: "Excluir", zh: "删除") }
    public static var edit: String { L(en: "Edit", ru: "Редактировать", es: "Editar", pt: "Editar", zh: "编辑") }
    public static var error: String { L(en: "Error", ru: "Ошибка", es: "Error", pt: "Erro", zh: "错误") }
    public static var search: String { L(en: "Search", ru: "Поиск", es: "Buscar", pt: "Buscar", zh: "搜索") }
    public static var apply: String { L(en: "Apply", ru: "Подать заявку", es: "Aplicar", pt: "Aplicar", zh: "申请") }
    public static var create: String { L(en: "Create", ru: "Создать", es: "Crear", pt: "Criar", zh: "创建") }
    public static var loading: String { L(en: "Loading...", ru: "Загрузка...", es: "Cargando...", pt: "Carregando...", zh: "加载中...") }
    public static var continueButton: String { L(en: "Continue", ru: "Продолжить", es: "Continuar", pt: "Continuar", zh: "继续") }
    public static var notSet: String { L(en: "Not set", ru: "Не задано", es: "No establecido", pt: "Não definido", zh: "未设置") }

    public static func xOfY(_ x: Int, _ y: Int) -> String {
        L(en: "\(x) of \(y)", ru: "\(x) из \(y)", es: "\(x) de \(y)", pt: "\(x) de \(y)", zh: "\(x) / \(y)")
    }

    // MARK: - Profile

    public static var myProfile: String { L(en: "MY PROFILE", ru: "МОЙ ПРОФИЛЬ", es: "MI PERFIL", pt: "MEU PERFIL", zh: "我的个人资料") }
    public static var agencyProfile: String { L(en: "My Agency Profile", ru: "Мой профиль агентства", es: "Mi perfil de agencia", pt: "Meu perfil de agência", zh: "我的机构资料") }
    public static var noBiography: String { L(en: "No biography", ru: "Нет биографии", es: "Sin biografía", pt: "Sem biografia", zh: "暂无简介") }
    public static var fillInInfoAboutYou: String { L(en: "Fill in the information about you", ru: "Заполните информацию о себе", es: "Complete la información sobre usted", pt: "Preencha as informações sobre você", zh: "请填写您的信息") }
    public static var fillInInfoAboutAgency: String { L(en: "Fill in the information about the agency", ru: "Заполните информацию об агентстве", es: "Complete la información sobre la agencia", pt: "Preencha as informações sobre a agência", zh: "请填写经纪公司信息") }
    public static var biography: String { L(en: "BIOGRAPHY", ru: "БИОГРАФИЯ", es: "BIOGRAFÍA", pt: "BIOGRAFIA", zh: "简介") }
    public static var biographyTitle: String { L(en: "Biography", ru: "Биография", es: "Biografía", pt: "Biografia", zh: "简介") }
    public static var description_: String { L(en: "DESCRIPTION", ru: "ОПИСАНИЕ", es: "DESCRIPCIÓN", pt: "DESCRIÇÃO", zh: "描述") }
    public static var descriptionTitle: String { L(en: "Description", ru: "Описание", es: "Descripción", pt: "Descrição", zh: "描述") }
    public static var appearance: String { L(en: "APPEARANCE", ru: "ВНЕШНОСТЬ", es: "APARIENCIA", pt: "APARÊNCIA", zh: "外貌") }
    public static var appearanceTitle: String { L(en: "Appearance", ru: "Внешность", es: "Apariencia", pt: "Aparência", zh: "外貌") }
    public static var experienceTitle: String { L(en: "Experience", ru: "Опыт", es: "Experiencia", pt: "Experiência", zh: "经验") }
    public static var seeMore: String { L(en: "SEE MORE", ru: "ПОКАЗАТЬ ЕЩЁ", es: "VER MÁS", pt: "VER MAIS", zh: "查看更多") }
    public static var seeLess: String { L(en: "SEE LESS", ru: "СВЕРНУТЬ", es: "VER MENOS", pt: "VER MENOS", zh: "收起") }
    public static var editLinks: String { L(en: "EDIT LINKS", ru: "РЕД. ССЫЛКИ", es: "EDITAR ENLACES", pt: "EDITAR LINKS", zh: "编辑链接") }
    public static var myLinks: String { L(en: "My Links", ru: "Мои ссылки", es: "Mis enlaces", pt: "Meus links", zh: "我的链接") }
    public static var editSocialLinks: String { L(en: "EDIT SOCIAL LINKS", ru: "РЕДАКТИРОВАТЬ ССЫЛКИ", es: "EDITAR REDES SOCIALES", pt: "EDITAR REDES SOCIAIS", zh: "编辑社交链接") }
    public static var enterYourWebsite: String { L(en: "Enter your website", ru: "Введите ваш сайт", es: "Ingrese su sitio web", pt: "Insira seu site", zh: "输入您的网站") }
    public static var socialLinksUpdated: String { L(en: "Social links updated", ru: "Ссылки обновлены", es: "Enlaces actualizados", pt: "Links atualizados", zh: "社交链接已更新") }
    public static var failedLinksUpdated: String { L(en: "Couldn't update social links", ru: "Не удалось обновить ссылки на соцсети", es: "No se pudieron actualizar los enlaces sociales", pt: "Não foi possível atualizar os links sociais", zh: "无法更新社交链接") }
    public static var profileUpdated: String { L(en: "Profile updated", ru: "Профиль обновлён", es: "Perfil actualizado", pt: "Perfil atualizado", zh: "个人资料已更新") }
    public static var failedProfileUpdated: String { L(en: "Couldn't update profile", ru: "Не удалось обновить профиль", es: "No se pudo actualizar el perfil", pt: "Não foi possível atualizar o perfil", zh: "无法更新个人资料") }
    public static var failedToLoadAppearance: String { L(en: "Failed to load appearance options.", ru: "Не удалось загрузить параметры внешности.", es: "Error al cargar las opciones de apariencia.", pt: "Falha ao carregar as opções de aparência.", zh: "无法加载外观选项。") }
    public static var failedToUploadPhoto: String { L(en: "Failed to upload photo", ru: "Не удалось загрузить фото", es: "Error al subir la foto", pt: "Falha ao enviar a foto", zh: "上传照片失败") }
    public static var similarProfiles: String { L(en: "You may be interested in similar profiles", ru: "Вам могут быть интересны похожие профили", es: "Perfiles similares que podrían interesarle", pt: "Perfis semelhantes que podem interessar", zh: "您可能感兴趣的类似资料") }
    public static var addWorkHistory: String { L(en: "+  Add work history", ru: "+  Добавить опыт работы", es: "+  Agregar experiencia", pt: "+  Adicionar experiência", zh: "+  添加工作经历") }
    public static var fullName: String { L(en: "Full name", ru: "Полное имя", es: "Nombre completo", pt: "Nome completo", zh: "全名") }
    public static var agencyName: String { L(en: "Agency name", ru: "Название агентства", es: "Nombre de la agencia", pt: "Nome da agência", zh: "经纪公司名称") }
    public static var name: String { L(en: "Name", ru: "Имя", es: "Nombre", pt: "Nome", zh: "姓名") }
    public static var followersCount: String { L(en: "followers", ru: "подписчиков", es: "seguidores", pt: "seguidores", zh: "粉丝") }
    public static var videoUnavailable: String { L(en: "Video unavailable", ru: "Видео недоступно", es: "Video no disponible", pt: "Vídeo indisponível", zh: "视频不可用") }
    public static var failedToDelete: String { L(en: "Failed to delete", ru: "Не удалось удалить", es: "Error al eliminar", pt: "Falha ao excluir", zh: "删除失败") }
    public static var emptyPhoto: String { L(en: "Photo is missing", ru: "Фото отсутствует", es: "Falta la foto", pt: "Foto está faltando", zh: "照片缺失") }
    public static var workHistoryUpdated: String { L(en: "The work history has been updated", ru: "История работы обновлена", es: "El historial laboral ha sido actualizado", pt: "O histórico de trabalho foi atualizado", zh: "工作经历已更新") }
    public static var workHistoryFailedUpdated: String { L(en: "Couldn't update work history", ru: "Не удалось обновить историю работы", es: "No se pudo actualizar el historial laboral", pt: "Não foi possível atualizar o histórico de trabalho", zh: "无法更新工作经历") }
    public static var workHistoryCreate: String { L(en: "Work history added", ru: "История работы добавлена", es: "Historial laboral agregado", pt: "Histórico de trabalho adicionado", zh: "工作经历已添加") }
    public static var workHistoryFailedCreate: String { L(en: "Couldn't add work history", ru: "Не удалось добавить историю работы", es: "No se pudo agregar el historial laboral", pt: "Não foi possível adicionar o histórico de trabalho", zh: "无法添加工作经历") }
    public static var workHistoryDelete: String { L(en: "Work history deleted", ru: "История работы удалена", es: "Historial laboral eliminado", pt: "Histórico de trabalho excluído", zh: "工作经历已删除") }
    public static var workHistoryDeleteConfirmTitle: String { L(en: "Delete work experience?", ru: "Удалить опыт работы?", es: "¿Eliminar experiencia laboral?", pt: "Excluir experiência de trabalho?", zh: "删除工作经历？") }
    public static var workHistoryDeleteConfirmMessage: String { L(en: "This action cannot be undone", ru: "Это действие нельзя отменить", es: "Esta acción no se puede deshacer", pt: "Esta ação não pode ser desfeita", zh: "此操作无法撤消") }
    public static var failedToLoadWorkHistory: String { L(en: "Failed to load work history", ru: "Не удалось загрузить историю работы", es: "Error al cargar el historial laboral", pt: "Falha ao carregar o histórico de trabalho", zh: "无法加载工作经历") }
    public static var connectionProblem: String { L(en: "Connection problem", ru: "Проблема с соединением", es: "Problema de conexión", pt: "Problema de conexão", zh: "连接问题") }
    public static var searchError: String { L(en: "Search error", ru: "Ошибка поиска", es: "Error de búsqueda", pt: "Erro de pesquisa", zh: "搜索错误") }
    public static var deleting: String { L(en: "Deleting…", ru: "Удаление…", es: "Eliminando…", pt: "Excluindo…", zh: "删除中…") }

    // MARK: - Profile — Gender & Appearance

    public static var gender: String { L(en: "Gender", ru: "Пол", es: "Género", pt: "Gênero", zh: "性别") }
    public static var selectGender: String { L(en: "Select a Gender", ru: "Выберите пол", es: "Seleccione un género", pt: "Selecione um gênero", zh: "选择性别") }
    public static var ageYo: String { L(en: "Age (y.o)", ru: "Возраст (лет)", es: "Edad (años)", pt: "Idade (anos)", zh: "年龄（岁）") }
    public static var heightCm: String { L(en: "Height (cm)", ru: "Рост (см)", es: "Altura (cm)", pt: "Altura (cm)", zh: "身高（厘米）") }
    public static var weightKg: String { L(en: "Weight (kg)", ru: "Вес (кг)", es: "Peso (kg)", pt: "Peso (kg)", zh: "体重（公斤）") }
    public static var waistCm: String { L(en: "Waist (cm)", ru: "Талия (см)", es: "Cintura (cm)", pt: "Cintura (cm)", zh: "腰围（厘米）") }
    public static var hipsCm: String { L(en: "Hips (cm)", ru: "Бёдра (см)", es: "Caderas (cm)", pt: "Quadris (cm)", zh: "臀围（厘米）") }
    public static var shoeSizeEU: String { L(en: "Shoe size (EU)", ru: "Размер обуви (EU)", es: "Talla de zapato (EU)", pt: "Tamanho do sapato (EU)", zh: "鞋码（EU）") }
    public static var hairLength: String { L(en: "Length hair", ru: "Длина волос", es: "Largo del cabello", pt: "Comprimento do cabelo", zh: "头发长度") }
    public static var chooseHairLength: String { L(en: "Choose your length hair", ru: "Выберите длину волос", es: "Elija el largo de su cabello", pt: "Escolha o comprimento do cabelo", zh: "选择头发长度") }
    public static var hairColor: String { L(en: "Hair color", ru: "Цвет волос", es: "Color de cabello", pt: "Cor do cabelo", zh: "发色") }
    public static var chooseHairColor: String { L(en: "Choose your hair color", ru: "Выберите цвет волос", es: "Elija su color de cabello", pt: "Escolha a cor do cabelo", zh: "选择发色") }
    public static var eyeColor: String { L(en: "Eye color", ru: "Цвет глаз", es: "Color de ojos", pt: "Cor dos olhos", zh: "眼睛颜色") }
    public static var chooseEyeColor: String { L(en: "Choose your eye color", ru: "Выберите цвет глаз", es: "Elija su color de ojos", pt: "Escolha a cor dos olhos", zh: "选择眼睛颜色") }
    public static var skinColor: String { L(en: "Skin color", ru: "Цвет кожи", es: "Color de piel", pt: "Cor da pele", zh: "肤色") }
    public static var chooseSkinColor: String { L(en: "Choose your skin color", ru: "Выберите цвет кожи", es: "Elija su color de piel", pt: "Escolha a cor da pele", zh: "选择肤色") }

    // MARK: - Profile — Interaction Lists

    public static var likes: String { L(en: "LIKES", ru: "НРАВИТСЯ", es: "ME GUSTA", pt: "CURTIDAS", zh: "喜欢") }
    public static var viewed: String { L(en: "VIEWED", ru: "ПРОСМОТРЫ", es: "VISTOS", pt: "VISUALIZADOS", zh: "已查看") }
    public static var saved: String { L(en: "SAVED", ru: "СОХРАНЁННЫЕ", es: "GUARDADOS", pt: "SALVOS", zh: "已收藏") }
    public static var premiumLabel: String { L(en: "Premium", ru: "Премиум", es: "Premium", pt: "Premium", zh: "高级版") }
    public static var failedLoadInteractionList: String { L(en: "Couldn't load data", ru: "Не удалось загрузить данные", es: "No se pudieron cargar los datos", pt: "Não foi possível carregar os dados", zh: "无法加载数据") }
    public static var noLikesYet: String { L(en: "No likes yet.", ru: "Пока нет лайков.", es: "Aún no hay me gusta.", pt: "Ainda sem curtidas.", zh: "暂无点赞。") }
    public static var noLikesSubtitle: String { L(en: "Likes will show up here.", ru: "Здесь будут отображаться лайки.", es: "Los me gusta aparecerán aquí.", pt: "As curtidas aparecerão aqui.", zh: "点赞将显示在这里。") }
    public static var nothingSavedYet: String { L(en: "Nothing saved yet.", ru: "Пока ничего не сохранено.", es: "Aún no hay nada guardado.", pt: "Ainda nada salvo.", zh: "暂无保存内容。") }
    public static var nothingSavedSubtitle: String { L(en: "No one’s saved this profile yet.", ru: "Этот профиль пока никто не сохранил.", es: "Nadie ha guardado este perfil aún.", pt: "Ninguém salvou este perfil ainda.", zh: "尚未有人保存此资料。") }
    public static var noProfileViewedYet: String { L(en: "No profile views yet.", ru: "Пока нет просмотров профиля.", es: "Aún no hay visitas al perfil.", pt: "Ainda sem visualizações de perfil.", zh: "暂无资料浏览。") }
    public static var noProfileViewedSubtitle: String { L(en: "No one’s viewed this profile yet.", ru: "Этот профиль пока никто не просматривал.", es: "Nadie ha visto este perfil aún.", pt: "Ninguém visualizou este perfil ainda.", zh: "尚未有人浏览此资料。") }
    public static var noLikesYetMyProfile: String { L(en: "No likes yet.", ru: "Пока нет лайков.", es: "Aún no hay me gusta.", pt: "Ainda sem curtidas.", zh: "暂无点赞。") }
    public static var noLikesSubtitleMyProfile: String { L(en: "Here you’ll see everyone who liked you.", ru: "Здесь вы увидите всех, кому вы понравились.", es: "Aquí verás a todos los que te dieron me gusta.", pt: "Aqui você verá todos que curtiram você.", zh: "这里会显示所有点赞过你的人。") }
    public static var nothingSavedYetMyProfile: String { L(en: "Nothing saved yet.", ru: "Пока ничего не сохранено.", es: "Aún no hay nada guardado.", pt: "Ainda nada salvo.", zh: "暂无保存内容。") }
    public static var nothingSavedSubtitleMyProfile: String { L(en: "No one's saved your profile yet.", ru: "Ваш профиль пока никто не сохранил.", es: "Nadie ha guardado tu perfil aún.", pt: "Ninguém salvou seu perfil ainda.", zh: "尚未有人保存你的资料。") }
    public static var noProfileViewedYetMyProfile: String { L(en: "No profile views yet.", ru: "Пока нет просмотров профиля.", es: "Aún no hay visitas al perfil.", pt: "Ainda sem visualizações de perfil.", zh: "暂无资料浏览。") }
    public static var noProfileViewedSubtitleMyProfile: String { L(en: "No one’s viewed your profile yet.", ru: "Ваш профиль пока никто не просматривал.", es: "Nadie ha visto tu perfil aún.", pt: "Ninguém visualizou seu perfil ainda.", zh: "尚未有人浏览过你的资料。") }
    public static var noWorkExperienceYetProfile: String { L(en: "There is no work experience yet.", ru: "Опыт работы пока отсутствует.", es: "Aún no hay experiencia laboral.", pt: "Ainda não há experiência de trabalho.", zh: "暂无工作经历。") }
    public static var noBioYetProfile: String { L(en: "No bio yet.", ru: "Информация о себе пока не заполнена.", es: "Información personal aún no completada.", pt: "Informação pessoal ainda não preenchida.", zh: "尚未填写个人简介。") }
    public static var noAppearanceYetProfile: String { L(en: "Model parameters are not filled in", ru: "Параметры модели не заполнены", es: "Los parámetros de la modelo no están completados", pt: "Os parâmetros da modelo não foram preenchidos", zh: "模特参数未填写") }
    public static var addBioProfile: String { L(en: "Fill in bio", ru: "Заполнить информацию о себе", es: "Completar biografía", pt: "Preencher biografia", zh: "填写个人简介") }
    public static var addAppearanceProfile: String { L(en: "Add your parameters", ru: "Добавить параметры", es: "Añadir tus parámetros", pt: "Adicionar seus parâmetros", zh: "添加个人参数") }
    
    // MARK: - Work Experience

    public static var workExperience: String { L(en: "Work experience", ru: "Опыт работы", es: "Experiencia laboral", pt: "Experiência profissional", zh: "工作经历") }
    public static var noWorkExperienceYet: String { L(en: "There is no work\nexperience yet.", ru: "Опыта работы\nпока нет.", es: "Aún no hay\nexperiencia laboral.", pt: "Ainda não há\nexperiência.", zh: "暂无\n工作经历。") }
    public static var noWorkExperienceSubtitle: String { L(en: "Click the button below\nto add your work\nexperience", ru: "Нажмите кнопку ниже,\nчтобы добавить\nопыт работы", es: "Haga clic en el botón\npara agregar su\nexperiencia", pt: "Clique no botão abaixo\npara adicionar sua\nexperiência", zh: "点击下方按钮\n添加您的\n工作经历") }
    public static var addWorkExperience: String { L(en: "Add work history", ru: "Добавить опыт работы", es: "Agregar experiencia laboral", pt: "Adicionar experiência de trabalho", zh: "添加工作经历") }
    public static var workExperienceInfo: String { L(en: "Work experience info", ru: "Информация об опыте работы", es: "Información de experiencia", pt: "Informações da experiência", zh: "工作经历信息") }
    public static var enterAgencyName: String { L(en: "Enter agency name", ru: "Введите название агентства", es: "Ingrese el nombre de la agencia", pt: "Insira o nome da agência", zh: "输入经纪公司名称") }
    public static var startDate: String { L(en: "Start date", ru: "Дата начала", es: "Fecha de inicio", pt: "Data de início", zh: "开始日期") }
    public static var endDate: String { L(en: "End date", ru: "Дата окончания", es: "Fecha de fin", pt: "Data de término", zh: "结束日期") }
    public static var currentlyWorking: String { L(en: "I am currently working in this role", ru: "Я сейчас работаю на этой позиции", es: "Actualmente trabajo en este puesto", pt: "Estou atualmente nesta função", zh: "我目前在此职位工作") }
    public static var saveChanges: String { L(en: "Save changes", ru: "Сохранить изменения", es: "Guardar cambios", pt: "Salvar alterações", zh: "保存更改") }
    public static var createNewWorkExperience: String { L(en: "Create new work experience", ru: "Создать новый опыт работы", es: "Crear nueva experiencia laboral", pt: "Criar nova experiência profissional", zh: "创建新的工作经验") }
    public static var creatingNewWorkExperience: String { L(en: "Creating...", ru: "Создание...", es: "Creando...", pt: "Criando...", zh: "创建中...") }
    public static var pleaseFillStartDate: String { L(en: "Please fill in the start date", ru: "Пожалуйста, укажите дату начала", es: "Por favor, ingrese la fecha de inicio", pt: "Por favor, preencha a data de início", zh: "请填写开始日期") }
    public static var currentAgency: String { L(en: "Current Agency", ru: "Текущее агентство", es: "Agencia actual", pt: "Agência atual", zh: "当前经纪公司") }
    public static var seeHistory: String { L(en: "SEE HISTORY", ru: "ИСТОРИЯ", es: "VER HISTORIAL", pt: "VER HISTÓRICO", zh: "查看历史") }
    public static var unknownAgency: String { L(en: "UNKNOWN AGENCY", ru: "НЕИЗВЕСТНОЕ АГЕНТСТВО", es: "AGENCIA DESCONOCIDA", pt: "AGÊNCIA DESCONHECIDA", zh: "未知经纪公司") }
    public static var pastExperience: String { L(en: "Past Experience", ru: "Прошлый опыт", es: "Experiencia pasada", pt: "Experiência passada", zh: "过往经历") }
    public static var present: String { L(en: "Present", ru: "По настоящее время", es: "Presente", pt: "Presente", zh: "至今") }
    public static var chooseAnAction: String { L(en: "Choose an action", ru: "Выберите действие", es: "Elija una acción", pt: "Escolha uma ação", zh: "选择操作") }

    public static func yearsCount(_ n: Int) -> String {
        L(en: "\(n) year\(n > 1 ? "s" : "")", ru: "\(n) \(pluralRu(n, "год", "года", "лет"))", es: "\(n) año\(n > 1 ? "s" : "")", pt: "\(n) ano\(n > 1 ? "s" : "")", zh: "\(n)年")
    }

    public static func monthsCount(_ n: Int) -> String {
        L(en: "\(n) month\(n > 1 ? "s" : "")", ru: "\(n) \(pluralRu(n, "месяц", "месяца", "месяцев"))", es: "\(n) mes\(n > 1 ? "es" : "")", pt: "\(n) \(n > 1 ? "meses" : "mês")", zh: "\(n)个月")
    }

    public static var oneMonth: String { L(en: "1 month", ru: "1 месяц", es: "1 mes", pt: "1 mês", zh: "1个月") }

    public static func followersString(_ count: Int) -> String {
        L(
            en: "\(count) \(count == 1 ? "follower" : "followers")",
            ru: "\(count) \(pluralRu(count, "подписчик", "подписчика", "подписчиков"))",
            es: "\(count) \(count == 1 ? "seguidor" : "seguidores")",
            pt: "\(count) \(count == 1 ? "seguidor" : "seguidores")",
            zh: "\(count) 粉丝"
        )
    }

    // MARK: - Events

    public static var createEvent: String { L(en: "Create event", ru: "Создать событие", es: "Crear evento", pt: "Criar evento", zh: "创建活动") }
    public static var eventInfo: String { L(en: "Event info", ru: "Информация о событии", es: "Información del evento", pt: "Informações do evento", zh: "活动信息") }
    public static var nameEvent: String { L(en: "Name event", ru: "Название события", es: "Nombre del evento", pt: "Nome do evento", zh: "活动名称") }
    public static var enterNameEvent: String { L(en: "Enter name event", ru: "Введите название", es: "Ingrese el nombre", pt: "Insira o nome", zh: "输入活动名称") }
    public static var aboutEvent: String { L(en: "About event", ru: "О событии", es: "Sobre el evento", pt: "Sobre o evento", zh: "关于活动") }
    public static var eventType: String { L(en: "Event type", ru: "Тип события", es: "Tipo de evento", pt: "Tipo de evento", zh: "活动类型") }
    public static var chooseEventType: String { L(en: "Choose event type", ru: "Выберите тип", es: "Elija el tipo", pt: "Escolha o tipo", zh: "选择活动类型") }
    public static var eventDate: String { L(en: "Event Date", ru: "Дата события", es: "Fecha del evento", pt: "Data do evento", zh: "活动日期") }
    public static var eventTime: String { L(en: "Event Time", ru: "Время события", es: "Hora del evento", pt: "Hora do evento", zh: "活动时间") }
    public static var venueOfEvent: String { L(en: "Venue of the event", ru: "Место проведения", es: "Lugar del evento", pt: "Local do evento", zh: "活动地点") }
    public static var chooseCountry: String { L(en: "Choose a country", ru: "Выберите страну", es: "Elija un país", pt: "Escolha um país", zh: "选择国家") }
    public static var parametersForApplying: String { L(en: "Parameters for Applying", ru: "Параметры для заявки", es: "Parámetros de solicitud", pt: "Parâmetros para candidatura", zh: "申请参数") }
    public static var addParameters: String { L(en: "+ Add parameters", ru: "+ Добавить параметры", es: "+ Agregar parámetros", pt: "+ Adicionar parâmetros", zh: "+ 添加参数") }
    public static var createEventButton: String { L(en: "Create Event", ru: "Создать событие", es: "Crear evento", pt: "Criar evento", zh: "创建活动") }
    public static var pleaseFillAllFields: String { L(en: "Please fill in all fields", ru: "Пожалуйста, заполните все поля", es: "Por favor, complete todos los campos", pt: "Por favor, preencha todos os campos", zh: "请填写所有字段") }
    public static var eventAdded: String { L(en: "Event added", ru: "Событие добавлено", es: "Evento agregado", pt: "Evento adicionado", zh: "活动已添加") }
    public static var casting: String { L(en: "Casting", ru: "Кастинг", es: "Casting", pt: "Casting", zh: "选角") }
    public static var participants: String { L(en: "participants", ru: "участников", es: "participantes", pt: "participantes", zh: "参与者") }
    public static var views: String { L(en: "views", ru: "просмотров", es: "vistas", pt: "visualizações", zh: "浏览") }
    public static var online: String { L(en: "Online", ru: "В сети", es: "En línea", pt: "Online", zh: "在线") }
    public static var organizer: String { L(en: "Organizer", ru: "Организатор", es: "Organizador", pt: "Organizador", zh: "组织者") }
    public static var about: String { L(en: "About", ru: "О событии", es: "Acerca de", pt: "Sobre", zh: "关于") }
    public static var height: String { L(en: "Height", ru: "Рост", es: "Altura", pt: "Altura", zh: "身高") }
    public static var age: String { L(en: "Age", ru: "Возраст", es: "Edad", pt: "Idade", zh: "年龄") }
    public static var previousEvents: String { L(en: "PREVIOUS EVENTS", ru: "ПРОШЕДШИЕ МЕРОПРИЯТИЯ", es: "EVENTOS ANTERIORES", pt: "EVENTOS ANTERIORES", zh: "往期活动") }
    public static var filterBy: String { L(en: "Filter by:", ru: "Фильтр:", es: "Filtrar por:", pt: "Filtrar por:", zh: "筛选：") }
    public static var location: String { L(en: "Location", ru: "Местоположение", es: "Ubicación", pt: "Localização", zh: "位置") }
    public static var allTypes: String { L(en: "All Types", ru: "Все типы", es: "Todos los tipos", pt: "Todos os tipos", zh: "所有类型") }
    public static var dateRange: String { L(en: "Date Range", ru: "Диапазон дат", es: "Rango de fechas", pt: "Intervalo de datas", zh: "日期范围") }
    public static var from: String { L(en: "From", ru: "От", es: "Desde", pt: "De", zh: "从") }
    public static var to: String { L(en: "To", ru: "До", es: "Hasta", pt: "Até", zh: "到") }
    public static var applyFilter: String { L(en: "Apply filter", ru: "Применить фильтр", es: "Aplicar filtro", pt: "Aplicar filtro", zh: "应用筛选") }

    // MARK: - Models Feed

    public static var subscribed: String { L(en: "Subscribed!", ru: "Подписка оформлена!", es: "¡Suscrito!", pt: "Inscrito!", zh: "已订阅！") }
    public static var unsubscribed: String { L(en: "Unsubscribed", ru: "Подписка отменена", es: "Desuscrito", pt: "Desinscrito", zh: "已取消订阅") }
    public static var subscribeFailed: String { L(en: "Failed to subscribe", ru: "Не удалось подписаться", es: "Error al suscribirse", pt: "Falha ao inscrever", zh: "订阅失败") }
    public static var unsubscribeFailed: String { L(en: "Failed to unsubscribe", ru: "Не удалось отписаться", es: "Error al desuscribirse", pt: "Falha ao desinscrever", zh: "取消订阅失败") }
    public static var liked: String { L(en: "Liked!", ru: "Нравится!", es: "¡Me gusta!", pt: "Curtido!", zh: "已点赞！") }
    public static var unliked: String { L(en: "Like removed", ru: "Лайк убран", es: "Me gusta eliminado", pt: "Curtida removida", zh: "已取消点赞") }
    public static var likeFailed: String { L(en: "Failed to like", ru: "Не удалось поставить лайк", es: "Error al dar me gusta", pt: "Falha ao curtir", zh: "点赞失败") }
    public static var unlikeFailed: String { L(en: "Failed to unlike", ru: "Не удалось убрать лайк", es: "Error al quitar me gusta", pt: "Falha ao descurtir", zh: "取消点赞失败") }
    public static var genericError: String { L(en: "Something went wrong. Please try again.", ru: "Что-то пошло не так. Попробуйте ещё раз.", es: "Algo salió mal. Inténtalo de nuevo.", pt: "Algo deu errado. Tente novamente.", zh: "出了点问题，请重试。") }
    public static var noInternetConnection: String { L(en: "No internet connection. Please try again.", ru: "Нет подключения к интернету. Попробуйте ещё раз.", es: "Sin conexión a internet. Inténtalo de nuevo.", pt: "Sem conexão com a internet. Tente novamente.", zh: "无网络连接，请重试。") }
    public static var serverUnavailable: String { L(en: "Server Unavailable", ru: "Сервер недоступен", es: "Servidor no disponible", pt: "Servidor indisponível", zh: "服务器不可用") }
    public static var serverUnavailableSubtitle: String { L(en: "Unable to connect to the server.\nTry toggling your VPN on or off.", ru: "Не удалось подключиться к серверу.\nПопробуйте включить или выключить VPN.", es: "No se pudo conectar al servidor.\nIntente activar o desactivar su VPN.", pt: "Não foi possível conectar ao servidor.\nTente ativar ou desativar a VPN.", zh: "无法连接到服务器。\n请尝试开启或关闭VPN。") }
    public static var noSubscriptionsYet: String { L(en: "No Subscriptions Yet", ru: "Пока нет подписок", es: "Sin suscripciones aún", pt: "Sem inscrições ainda", zh: "暂无订阅") }
    public static var noSubscriptionsSubtitle: String { L(en: "Subscribe to models to see\nthem here.", ru: "Подпишитесь на модели,\nчтобы видеть их здесь.", es: "Suscríbase a modelos\npara verlos aquí.", pt: "Inscreva-se em modelos\npara vê-los aqui.", zh: "订阅模特\n即可在此查看。") }
    public static var noResults: String { L(en: "No Results", ru: "Нет результатов", es: "Sin resultados", pt: "Sem resultados", zh: "无结果") }
    public static var noResultsSubtitle: String { L(en: "No agencies or pro members\nfound at the moment.", ru: "Агентства и модели\nне найдены.", es: "No se encontraron agencias\nni miembros pro.", pt: "Nenhuma agência ou membro\npro encontrado.", zh: "暂未找到经纪公司\n或专业会员。") }
    public static var noUsersFound: String { L(en: "No Users Found", ru: "Пользователи не найдены", es: "No se encontraron usuarios", pt: "Nenhum usuário encontrado", zh: "未找到用户") }
    public static var noUsersFoundSubtitle: String { L(en: "There are no users\nto display right now.", ru: "Сейчас нет пользователей\nдля отображения.", es: "No hay usuarios\npara mostrar ahora.", pt: "Não há usuários\npara exibir agora.", zh: "当前没有\n可显示的用户。") }
    public static var sendDM: String { L(en: "Send DM", ru: "Написать", es: "Enviar MD", pt: "Enviar MD", zh: "发私信") }
    public static var loadingModelsList: String { L(en: "LOADING MODELS LIST...", ru: "ЗАГРУЗКА СПИСКА МОДЕЛЕЙ...", es: "CARGANDO LISTA DE MODELOS...", pt: "CARREGANDO LISTA DE MODELOS...", zh: "加载模特列表...") }
    public static var loadingTalentsList: String { L(en: "LOADING TALENTS...", ru: "ЗАГРУЗКА ТАЛАНТОВ...", es: "CARGANDO TALENTOS...", pt: "CARREGANDO TALENTOS...", zh: "加载新人才...") }
    public static var loadingAgenciesList: String { L(en: "LOADING AGENCIES...", ru: "ЗАГРУЗКА АГЕНТСТВ...", es: "CARGANDO AGENCIAS...", pt: "CARREGANDO AGÊNCIAS...", zh: "加载经纪公司...") }
    public static var retry: String { L(en: "Retry", ru: "Повторить", es: "Reintentar", pt: "Tentar novamente", zh: "重试") }
    public static var feedLoadErrorTitle: String { L(en: "Couldn't load models", ru: "Не удалось загрузить модели", es: "No se pudieron cargar modelos", pt: "Não foi possível carregar modelos", zh: "无法加载模特") }
    public static var feedLoadErrorSubtitle: String { L(en: "Something went wrong on our end.\nCheck your connection and try again.", ru: "Что-то пошло не так.\nПроверьте подключение и попробуйте снова.", es: "Algo salió mal de nuestro lado.\nVerifique su conexión e inténtelo de nuevo.", pt: "Algo deu errado do nosso lado.\nVerifique sua conexão e tente novamente.", zh: "我们这边出了点问题。\n请检查连接并重试。") }
    public static var feedPaginationError: String { L(en: "Failed to load more", ru: "Не удалось загрузить ещё", es: "Error al cargar más", pt: "Falha ao carregar mais", zh: "加载更多失败") }
    public static var profileSaved: String { L(en: "Saved", ru: "Сохранено", es: "Guardado", pt: "Salvo", zh: "已保存") }
    public static var viewAction: String { L(en: "View", ru: "Смотреть", es: "Ver", pt: "Ver", zh: "查看") }
    public static var yearsOld: String { L(en: "y.o", ru: "лет", es: "años", pt: "anos", zh: "岁") }
    public static var goToMyProfile: String { L(en: "Go to my profile", ru: "Перейти в мой профиль", es: "Ir a mi perfil", pt: "Ir para meu perfil", zh: "前往我的资料") }

    // MARK: - Onboarding
    
    public static var onboardingTitle1: String { L(en: "GET SEEN BY THE RIGHT PEOPLE.", ru: "ПОКАЖИТЕСЬ НУЖНЫМ ЛЮДЯМ.", es: "HAZTE VER POR LAS PERSONAS ADECUADAS.", pt: "SEJA VISTO PELAS PESSOAS CERTAS.", zh: "让对的人看到你。") }
    public static var onboardingSubTitle1: String { L(en: "A professional profile that puts you in front of agencies and brands actively looking for talent", ru: "Профессиональный профиль, который показывает вас агентствам и брендам, активно ищущим таланты", es: "Un perfil profesional que te pone frente a agencias y marcas que buscan talento activamente", pt: "Um perfil profissional que coloca você diante de agências e marcas que buscam talentos ativamente", zh: "打造专业档案，让正在寻找人才的机构和品牌主动找到你。") }
    public static var onboardingTitle2: String { L(en: "REAL CASTINGS.\nREAL OPPORTUNITIES.", ru: "РЕАЛЬНЫЕ КАСТИНГИ.\nРЕАЛЬНЫЕ ВОЗМОЖНОСТИ.", es: "CASTINGS REALES.\nOPORTUNIDADES REALES.", pt: "CASTINGS REAIS.\nOPORTUNIDADES REAIS.", zh: "真实的试镜。\n真实的机会。") }
    public static var onboardingSubTitle2: String { L(en: "Apply to verified jobs from agencies and brands — no middlemen, no guesswork.", ru: "Откликайтесь на проверенные вакансии от агентств и брендов — без посредников и догадок.", es: "Postula a trabajos verificados de agencias y marcas — sin intermediarios, sin conjeturas.", pt: "Candidate-se a vagas verificadas de agências e marcas — sem intermediários, sem adivinhações.", zh: "直接申请来自机构和品牌的已验证工作——没有中间商，不靠猜测。") }
    public static var onboardingTitle3: String { L(en: "DISCOVERED FASTER\nWITH AI.", ru: "НАХОДИТЕ БЫСТРЕЕ\nС ИИ.", es: "DESCUBIERTO MÁS RÁPIDO\nCON IA.", pt: "DESCOBERTO MAIS RÁPIDO\nCOM IA.", zh: "通过AI\n更快被发现。") }
    public static var onboardingSubTitle3: String { L(en: "DIVO's AI finds the best match between talent and brands — so opportunities come to you.", ru: "ИИ DIVO находит идеальное соответствие между талантами и брендами — и возможности приходят к вам сами.", es: "La IA de DIVO encuentra la mejor coincidencia entre el talento y las marcas — para que las oportunidades lleguen a ti.", pt: "A IA da DIVO encontra a melhor combinação entre talentos e marcas — para que as oportunidades cheguem até você.", zh: "DIVO的人工智能精准匹配才华与品牌——让机会主动找上你。") }

    // MARK: - Add Model Agency

    public static var linkModel: String { L(en: "Link on profile in Divo", ru: "Ссылка на профиль в Divo", es: "Enlace en el perfil en Divo", pt: "Link no perfil em Divo", zh: "Divo个人资料连结") }
    public static var titleAddModel: String { L(en: "ADD A NEW MODEL", ru: "ДОБАВЬТЕ НОВУЮ МОДЕЛЬ", es: "AGREGAR UN NUEVO MODELO", pt: "ADICIONAR UM NOVO MODELO", zh: "添加新模型") }
    public static var subTitleAddModel: String { L(en: "Fill out the model's details to add\nthem to your agency. You can\nupdate this information anytime.", ru: "Заполните данные модели, чтобы добавить\nих в свое агентство. Вы можете\nобновить эту информацию в любое время.", es: "Complete los detalles del modelo para agregarlos\na su agencia. Puede\nactualizar esta información en cualquier momento.", pt: "Preencha os detalhes do modelo para adicionar\nà sua agência. Você pode\natualizar essas informações a qualquer momento.", zh: "填写模型的详细信息以将\n添加到您的代理机构。您可以随时\n更新此信息。") }
    public static var parametersAddModel: String { L(en: "Your parameters", ru: "Ваши параметры", es: "Sus parámetros", pt: "Os seus parâmetros", zh: "您的参数") }
    public static var emptyTitleAddModel: String { L(en: "There are no models\nfrom your agency yet.", ru: "Текущих моделей\nот вашего агентства пока нет.", es: "No hay modelos\nde su agencia todavía.", pt: "Ainda não há modelos\nda sua agência.", zh: "目前还没有\n贵机构的模特。") }
    public static var emptySubTitleAddModel: String { L(en: "Click the button below\nto add your model", ru: "Нажмите кнопку ниже,\nчтобы добавить модель", es: "Haz clic en el botón de abajo\npara añadir tu modelo", pt: "Clique no botão abaixo\npara adicionar seu modelo", zh: "点击下方按钮\n添加您的模特") }

    // MARK: - Debug Screen

    public static var debug: String { "Debug" }
    public static var debugTools: String { L(en: "TOOLS", ru: "ИНСТРУМЕНТЫ", es: "HERRAMIENTAS", pt: "FERRAMENTAS", zh: "工具") }
    public static var debugAccessToken: String { L(en: "Access token", ru: "Токен доступа", es: "Token de acceso", pt: "Token de acesso", zh: "访问令牌") }
    public static var debugRequestLogs: String { L(en: "Request logs", ru: "Логи запросов", es: "Registros de solicitudes", pt: "Logs de requisições", zh: "请求日志") }
    public static var debugUser: String { L(en: "User", ru: "Пользователь", es: "Usuario", pt: "Usuário", zh: "用户") }
    public static var debugNetwork: String { L(en: "NETWORK", ru: "СЕТЬ", es: "RED", pt: "REDE", zh: "网络") }
    public static var debugNetworkOverlay: String { L(en: "Network overlay", ru: "Сетевой оверлей", es: "Superposición de red", pt: "Sobreposição de rede", zh: "网络覆盖层") }
    public static var debugNetworkDelay: String { L(en: "Network delay", ru: "Замедление сети", es: "Retraso de red", pt: "Atraso de rede", zh: "网络延迟") }
    public static var debugCache: String { L(en: "CACHE", ru: "КЕШ", es: "CACHÉ", pt: "CACHE", zh: "缓存") }
    public static var debugImageCache: String { L(en: "Image cache", ru: "Кеш изображений", es: "Caché de imágenes", pt: "Cache de imagens", zh: "图片缓存") }
    public static var debugInfo: String { L(en: "INFO", ru: "ИНФОРМАЦИЯ", es: "INFORMACIÓN", pt: "INFORMAÇÃO", zh: "信息") }
    public static var debugAgency: String { L(en: "Agency", ru: "Агентство", es: "Agencia", pt: "Agência", zh: "经纪公司") }
    public static var debugNewTalent: String { L(en: "New talent", ru: "Новый талант", es: "Nuevo talento", pt: "Novo talento", zh: "新人才") }
    public static var debugModel: String { L(en: "Model", ru: "Модель", es: "Modelo", pt: "Modelo", zh: "模特") }
    public static var debugCustom: String { L(en: "Custom", ru: "Свой", es: "Personalizado", pt: "Personalizado", zh: "自定义") }
    public static var debugOff: String { L(en: "Off", ru: "Выкл", es: "Apagado", pt: "Desligado", zh: "关闭") }
    public static var debugEmpty: String { L(en: "Empty", ru: "Пусто", es: "Vacío", pt: "Vazio", zh: "空") }
    public static var debugVersion: String { L(en: "Version", ru: "Версия", es: "Versión", pt: "Versão", zh: "版本") }
    public static var debugPlatform: String { L(en: "Platform", ru: "Платформа", es: "Plataforma", pt: "Plataforma", zh: "平台") }
    public static var debugDevice: String { L(en: "Device", ru: "Устройство", es: "Dispositivo", pt: "Dispositivo", zh: "设备") }
    public static var debugLocale: String { L(en: "Locale", ru: "Локализация", es: "Localización", pt: "Localização", zh: "语言设置") }
    public static var debugNetworkDelayTitle: String { L(en: "Network delay", ru: "Замедление сети", es: "Retraso de red", pt: "Atraso de rede", zh: "网络延迟") }
    public static var debugNetworkDelayMessage: String { L(en: "Artificial delay before each request", ru: "Искусственная задержка перед каждым запросом", es: "Retraso artificial antes de cada solicitud", pt: "Atraso artificial antes de cada requisição", zh: "每次请求前的人工延迟") }
    public static var debugClearCache: String { L(en: "Clear cache?", ru: "Очистить кеш?", es: "¿Limpiar caché?", pt: "Limpar cache?", zh: "清除缓存？") }
    public static var debugClear: String { L(en: "Clear", ru: "Очистить", es: "Limpiar", pt: "Limpar", zh: "清除") }
    public static var debugAll: String { L(en: "All", ru: "Все", es: "Todos", pt: "Todos", zh: "全部") }
    public static var debugAny: String { L(en: "Any", ru: "Любой", es: "Cualquiera", pt: "Qualquer", zh: "任意") }

    public static func debugCurrentSize(_ size: String) -> String {
        L(en: "Current size: \(size)", ru: "Текущий размер: \(size)", es: "Tamaño actual: \(size)", pt: "Tamanho atual: \(size)", zh: "当前大小：\(size)")
    }

    public static func debugDelayMs(_ ms: Int) -> String { "\(ms)\(L(en: "ms", ru: "мс", es: "ms", pt: "ms", zh: "毫秒"))" }
    public static func debugDelaySec(_ sec: Int) -> String {
        L(en: "\(sec) seconds", ru: "\(sec) \(pluralRu(sec, "секунда", "секунды", "секунд"))", es: "\(sec) segundos", pt: "\(sec) segundos", zh: "\(sec)秒")
    }

    // Debug Token
    public static var debugCurrentToken: String { L(en: "CURRENT TOKEN", ru: "ТЕКУЩИЙ ТОКЕН", es: "TOKEN ACTUAL", pt: "TOKEN ATUAL", zh: "当前令牌") }
    public static var debugCopy: String { L(en: "Copy", ru: "Скопировать", es: "Copiar", pt: "Copiar", zh: "复制") }
    public static var debugCopied: String { L(en: "Copied!", ru: "Скопировано!", es: "¡Copiado!", pt: "Copiado!", zh: "已复制！") }
    public static var debugPresets: String { L(en: "PRESETS", ru: "ПРЕСЕТЫ", es: "PREAJUSTES", pt: "PREDEFINIÇÕES", zh: "预设") }
    public static var debugCustomToken: String { L(en: "CUSTOM TOKEN", ru: "СВОЙ ТОКЕН", es: "TOKEN PERSONALIZADO", pt: "TOKEN PERSONALIZADO", zh: "自定义令牌") }
    public static var debugPasteToken: String { L(en: "Paste token...", ru: "Вставьте токен...", es: "Pegar token...", pt: "Cole o token...", zh: "粘贴令牌...") }
    public static var debugApplyCustomToken: String { L(en: "Apply custom token", ru: "Применить свой токен", es: "Aplicar token personalizado", pt: "Aplicar token personalizado", zh: "应用自定义令牌") }

    // Debug User Info
    public static var debugFailedToParse: String { L(en: "Failed to parse response", ru: "Не удалось распарсить ответ", es: "Error al analizar la respuesta", pt: "Falha ao analisar a resposta", zh: "解析响应失败") }
    public static var debugUserData: String { L(en: "USER DATA", ru: "ДАННЫЕ ПОЛЬЗОВАТЕЛЯ", es: "DATOS DEL USUARIO", pt: "DADOS DO USUÁRIO", zh: "用户数据") }
    public static var debugRawJson: String { L(en: "RAW JSON", ru: "RAW JSON", es: "JSON BRUTO", pt: "JSON BRUTO", zh: "原始JSON") }
    public static var debugCopyJson: String { L(en: "Copy JSON", ru: "Скопировать JSON", es: "Copiar JSON", pt: "Copiar JSON", zh: "复制JSON") }
    public static var debugId: String { "ID" }
    public static var debugPhone: String { L(en: "Phone", ru: "Телефон", es: "Teléfono", pt: "Telefone", zh: "电话") }
    public static var debugEmail: String { "Email" }
    public static var debugRole: String { L(en: "Role", ru: "Роль", es: "Rol", pt: "Função", zh: "角色") }
    public static var debugCity: String { L(en: "City", ru: "Город", es: "Ciudad", pt: "Cidade", zh: "城市") }
    public static var debugCountry: String { L(en: "Country", ru: "Страна", es: "País", pt: "País", zh: "国家") }
    public static var debugDateOfBirth: String { L(en: "Date of birth", ru: "Дата рождения", es: "Fecha de nacimiento", pt: "Data de nascimento", zh: "出生日期") }
    public static var debugWeight: String { L(en: "Weight", ru: "Вес", es: "Peso", pt: "Peso", zh: "体重") }
    public static var debugBust: String { L(en: "Bust", ru: "Грудь", es: "Busto", pt: "Busto", zh: "胸围") }
    public static var debugWaist: String { L(en: "Waist", ru: "Талия", es: "Cintura", pt: "Cintura", zh: "腰围") }
    public static var debugHips: String { L(en: "Hips", ru: "Бёдра", es: "Caderas", pt: "Quadris", zh: "臀围") }
    public static var debugShoes: String { L(en: "Shoes", ru: "Обувь", es: "Zapatos", pt: "Sapatos", zh: "鞋码") }

    // MARK: - Create/Edit Event

    public static var uploadPhoto: String { L(en: "Upload photo", ru: "Загрузить фото", es: "Subir foto", pt: "Enviar foto", zh: "上传照片") }
    public static var descriptionEvent: String { L(en: "Description event", ru: "Описание события", es: "Descripción del evento", pt: "Descrição do evento", zh: "活动描述") }
    public static var eventGallery: String { L(en: "Event Gallery", ru: "Галерея события", es: "Galería del evento", pt: "Galeria do evento", zh: "活动相册") }
    public static var parametersTitle: String { L(en: "PARAMETERS", ru: "ПАРАМЕТРЫ", es: "PARÁMETROS", pt: "PARÂMETROS", zh: "参数") }
    public static var chooseParametersForApplying: String { L(en: "Choose Parameters for Applying", ru: "Выберите параметры для подачи заявки", es: "Elija parámetros para la solicitud", pt: "Escolha parâmetros para candidatura", zh: "选择申请参数") }
    public static var allMembers: String { L(en: "All Members", ru: "Все участники", es: "Todos los miembros", pt: "Todos os membros", zh: "所有成员") }
    public static var breastCm: String { L(en: "Breast (cm)", ru: "Грудь (см)", es: "Pecho (cm)", pt: "Busto (cm)", zh: "胸围（厘米）") }
    public static var eventSuccessfullyCreated: String { L(en: "Event successfully created!", ru: "Событие успешно создано!", es: "¡Evento creado con éxito!", pt: "Evento criado com sucesso!", zh: "活动创建成功！") }
    public static var eventSuccessfullyUpdated: String { L(en: "Event successfully updated!", ru: "Событие успешно обновлено!", es: "¡Evento actualizado con éxito!", pt: "Evento atualizado com sucesso!", zh: "活动更新成功！") }
    public static var unknownError: String { L(en: "Unknown error", ru: "Неизвестная ошибка", es: "Error desconocido", pt: "Erro desconhecido", zh: "未知错误") }
    public static var failedToLoadEventData: String { L(en: "Failed to load event data", ru: "Не удалось загрузить данные события", es: "Error al cargar datos del evento", pt: "Falha ao carregar dados do evento", zh: "无法加载活动数据") }
    public static var failedToUploadCover: String { L(en: "Failed to upload cover photo", ru: "Не удалось загрузить обложку", es: "Error al subir la foto de portada", pt: "Falha ao enviar a foto de capa", zh: "上传封面照片失败") }
    public static var unknownCity: String { L(en: "Unknown city", ru: "Неизвестный город", es: "Ciudad desconocida", pt: "Cidade desconhecida", zh: "未知城市") }
    public static var tbd: String { L(en: "TBD", ru: "Уточняется", es: "Por definir", pt: "A definir", zh: "待定") }
    public static var eventFallbackName: String { L(en: "Event", ru: "Событие", es: "Evento", pt: "Evento", zh: "活动") }
    public static var roleFallbackUser: String { L(en: "User", ru: "Пользователь", es: "Usuario", pt: "Usuário", zh: "用户") }
    public static var failedToUpdateEvent: String { L(en: "Failed to update event", ru: "Не удалось обновить событие", es: "Error al actualizar el evento", pt: "Falha ao atualizar o evento", zh: "更新活动失败") }
    public static var failedToCreateEvent: String { L(en: "Failed to create event", ru: "Не удалось создать событие", es: "Error al crear el evento", pt: "Falha ao criar o evento", zh: "创建活动失败") }

    public static var addShort: String { L(en: "+ Add", ru: "+ Добавить", es: "+ Agregar", pt: "+ Adicionar", zh: "+ 添加") }
    public static var searchPlaceholder: String { L(en: "Search...", ru: "Поиск...", es: "Buscar...", pt: "Buscar...", zh: "搜索...") }

    public static func nSelected(_ n: Int) -> String {
        L(en: "\(n) selected", ru: "\(n) выбрано", es: "\(n) seleccionados", pt: "\(n) selecionados", zh: "已选\(n)项")
    }

    public static var emptyTitleAddEvent: String { L(en: "There are no upcoming\nevents at the moment.", ru: "Пока нет предстоящих\nсобытий", es: "No hay eventos\npróximos en este momento", pt: "Não há eventos\nfuturos no momento", zh: "目前暂无即将举行的活动") }
    public static var emptySubTitleAddEvent: String { L(en: "Check back later or create\na new one", ru: "Загляните позже или\nсоздайте новое", es: "Vuelve más tarde o\ncrea uno nuevo", pt: "Volte mais tarde ou\ncrie um novo", zh: "稍后再试或创建新活动") }

    // MARK: - Event Parameter Titles

    public static var paramGender: String { L(en: "Gender", ru: "Пол", es: "Género", pt: "Gênero", zh: "性别") }
    public static var paramAge: String { L(en: "Age", ru: "Возраст", es: "Edad", pt: "Idade", zh: "年龄") }
    public static var paramHeight: String { L(en: "Height", ru: "Рост", es: "Altura", pt: "Altura", zh: "身高") }
    public static var paramWeight: String { L(en: "Weight", ru: "Вес", es: "Peso", pt: "Peso", zh: "体重") }
    public static var paramBreast: String { L(en: "Breast", ru: "Грудь", es: "Busto", pt: "Busto", zh: "胸围") }
    public static var paramWaist: String { L(en: "Waist", ru: "Талия", es: "Cintura", pt: "Cintura", zh: "腰围") }
    public static var paramHips: String { L(en: "Hips", ru: "Бёдра", es: "Caderas", pt: "Quadris", zh: "臀围") }
    public static var paramShoeSize: String { L(en: "Shoe size", ru: "Размер обуви", es: "Talla de zapato", pt: "Número do sapato", zh: "鞋码") }
    public static var paramHairLength: String { L(en: "Hair length", ru: "Длина волос", es: "Largo del cabello", pt: "Comprimento do cabelo", zh: "发长") }
    public static var paramHairColor: String { L(en: "Hair color", ru: "Цвет волос", es: "Color de cabello", pt: "Cor do cabelo", zh: "发色") }
    public static var paramEyeColor: String { L(en: "Eye color", ru: "Цвет глаз", es: "Color de ojos", pt: "Cor dos olhos", zh: "眼色") }
    public static var paramSkinColor: String { L(en: "Skin color", ru: "Цвет кожи", es: "Color de piel", pt: "Cor da pele", zh: "肤色") }

    // MARK: - Helpers

    private static func pluralRu(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod10 == 1 && mod100 != 11 { return one }
        if mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20) { return few }
        return many
    }
}
