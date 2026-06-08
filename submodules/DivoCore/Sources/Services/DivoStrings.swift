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

        /// Дефолтный код страны для phone entry — берётся по языку, не по системному региону.
        public var defaultPhoneCountryCode: Int32 {
            switch self {
            case .en: return 1   // US
            case .ru: return 7   // RU
            case .es: return 34  // ES
            case .pt: return 55  // BR
            case .zh: return 86  // CN
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
    public static var roleFan: String { L(en: "Fan", ru: "Фанат", es: "Fan", pt: "Fã", zh: "粉丝") }
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
    public static var noUpcomingEventsTitle: String { L(en: "There are no upcoming events at the moment.", ru: "На данный момент предстоящих событий нет.", es: "No hay eventos próximos en este momento.", pt: "Não há eventos futuros no momento.", zh: "目前暂无即将举行的活动.") }
    public static var noUpcomingEventsSubtitle: String { L(en: "Check back later.", ru: "Загляните позже.", es: "Vuelve a consultar más tarde.", pt: "Volte mais tarde.", zh: "请稍后再来查看.") }
    public static var noUpcomingEventsAgencySubtitle: String { L(en: "Check back later or create a new one.", ru: "Загляните позже или создайте новое.", es: "Vuelve a consultar más tarde o crea uno nuevo.", pt: "Volte mais tarde ou crie um novo.", zh: "请稍后再来查看或创建一个新的.") }
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
    public static var deletePhoto: String { L(en: "Delete photo", ru: "Удалить фото", es: "Eliminar foto", pt: "Deletar foto", zh: "删除照片") }

    // MARK: - Units

    public static func ageString(_ age: Int) -> String {
        L(en: "\(age) y.o", ru: "\(age) \(pluralRu(age, "год", "года", "лет"))", es: "\(age) años", pt: "\(age) anos", zh: "\(age)岁")
    }
    public static var unitCm: String { "cm" }
    public static var unitKg: String { L(en: "kg", ru: "кг", es: "kg", pt: "kg", zh: "公斤") }
    public static var unitEU: String { "EU" }
    public static var unitYo: String { L(en: "y.o", ru: "лет", es: "años", pt: "anos", zh: "岁") }

    // MARK: - Appearance Attributes

    public static var attrGender: String { L(en: "Gender", ru: "Пол", es: "Género", pt: "Gênero", zh: "性别") }
    public static var attrAge: String { L(en: "Age", ru: "Возраст", es: "Edad", pt: "Idade", zh: "年龄") }
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
    public static var settingsBannerTitle: String { L(en: "Get Discovered in the Fashion World", ru: "Будьте замечены в мире моды", es: "Hazte notar en el mundo de la moda", pt: "Seja descoberto no mundo da moda", zh: "在时尚界被发现") }
    public static var settingsBannerDescription: String { L(en: "Publish your profile as a model, join castings or add events as agency — be part of the global fashion network.", ru: "Опубликуйте профиль модели, участвуйте в кастингах или добавляйте события — станьте частью мировой fashion-сети.", es: "Publica tu perfil como modelo, únete a castings o añade eventos como agencia — forma parte de la red global de moda.", pt: "Publique seu perfil como modelo, participe de castings ou adicione eventos como agência — faça parte da rede global de moda.", zh: "发布您的模特资料，参加选角或作为经纪公司添加活动——成为全球时尚网络的一部分。") }
    public static var settingsLearnMore: String { L(en: "Learn More", ru: "Узнать больше", es: "Más información", pt: "Saiba mais", zh: "了解更多") }
    public static var fillYourParameters: String { L(en: "Fill your parameters", ru: "Заполните параметры", es: "Completa tus parámetros", pt: "Preencha seus parâmetros", zh: "填写您的参数") }
    public static var savedMessages: String { L(en: "Saved Messages", ru: "Сохранённые сообщения", es: "Mensajes guardados", pt: "Mensagens salvas", zh: "已保存的消息") }
    public static var notificationsSounds: String { L(en: "Notifications and Sounds", ru: "Уведомления и звуки", es: "Notificaciones y sonidos", pt: "Notificações e sons", zh: "通知和声音") }
    public static var privacySecurity: String { L(en: "Privacy and Security", ru: "Конфиденциальность и безопасность", es: "Privacidad y seguridad", pt: "Privacidade e segurança", zh: "隐私与安全") }
    public static var dataStorage: String { L(en: "Data and Storage", ru: "Данные и хранилище", es: "Datos y almacenamiento", pt: "Dados e armazenamento", zh: "数据和存储") }
    public static var language: String { L(en: "Language", ru: "Язык", es: "Idioma", pt: "Idioma", zh: "语言") }
    public static var languageAuto: String { L(en: "System", ru: "Системный", es: "Sistema", pt: "Sistema", zh: "系统") }
    public static func languageSystemSubtitle(_ deviceName: String) -> String {
        L(en: "Follows device — \(deviceName)", ru: "Как на устройстве — \(deviceName)", es: "Sigue el dispositivo — \(deviceName)", pt: "Segue o dispositivo — \(deviceName)", zh: "跟随设备 — \(deviceName)")
    }
    public static var logOut: String { L(en: "Log out", ru: "Выйти", es: "Cerrar sesión", pt: "Sair", zh: "退出") }
    public static var logOutConfirmation: String { L(en: "Are you sure you want to log out?", ru: "Вы уверены, что хотите выйти?", es: "¿Estás seguro de que quieres cerrar sesión?", pt: "Tem certeza que deseja sair?", zh: "确定要退出登录吗？") }
    public static var settingsDebugLaunchOnboarding: String { L(en: "Launch onboarding (debug)", ru: "Запустить онбординг (debug)", es: "Iniciar onboarding (debug)", pt: "Iniciar onboarding (debug)", zh: "启动入门引导（调试）") }
    public static var measuringSystem: String { L(en: "Measuring System", ru: "Система измерения", es: "Sistema de medición", pt: "Sistema de medição", zh: "测量系统") }
    public static var myParameters: String { L(en: "My Parameters", ru: "Мои параметры", es: "Mis parámetros", pt: "Meus parâmetros", zh: "我的参数") }
    public static var saveParameters: String { L(en: "Save parameters", ru: "Сохранить параметры", es: "Guardar parámetros", pt: "Salvar parâmetros", zh: "保存参数") }
    public static var metric: String { L(en: "Metric", ru: "Метрическая", es: "Métrico", pt: "Métrico", zh: "公制") }
    public static var imperial: String { L(en: "Imperial", ru: "Имперская", es: "Imperial", pt: "Imperial", zh: "英制") }

    // MARK: - Auth Welcome

    public static var authWelcomeTitle: String { L(en: "Welcome to DIVO", ru: "Добро пожаловать в DIVO", es: "Bienvenido a DIVO", pt: "Bem-vindo à DIVO", zh: "欢迎来到 DIVO") }
    public static var authWelcomeSubtitle: String { L(en: "Sign in or create your account", ru: "Войдите или создайте аккаунт", es: "Inicia sesión o crea tu cuenta", pt: "Entre ou crie sua conta", zh: "登录或创建账户") }
    public static var authContinueWithPhone: String { L(en: "Continue with phone number", ru: "Продолжить с номером телефона", es: "Continuar con número de teléfono", pt: "Continuar com número de telefone", zh: "使用手机号继续") }
    public static var authSignInWithGoogle: String { L(en: "Sign In with Google", ru: "Войти через Google", es: "Iniciar sesión con Google", pt: "Entrar com Google", zh: "使用 Google 登录") }
    public static var authSignInWithApple: String { L(en: "Sign In with Apple", ru: "Войти через Apple", es: "Iniciar sesión con Apple", pt: "Entrar com Apple", zh: "使用 Apple 登录") }
    public static var authSeparatorOr: String { L(en: "or", ru: "или", es: "o", pt: "ou", zh: "或") }
    public static var authTermsAndPrivacyPrefix: String { L(en: "By continuing you agree to our", ru: "Продолжая, вы соглашаетесь с", es: "Al continuar aceptas nuestros", pt: "Ao continuar você concorda com", zh: "继续即表示您同意我们的") }
    public static var authTermsAndPrivacyConjunction: String { L(en: "and", ru: "и", es: "y", pt: "e", zh: "和") }
    public static var authTermsOfService: String { L(en: "Terms of Service", ru: "Условиями использования", es: "Términos de servicio", pt: "Termos de Serviço", zh: "服务条款") }
    public static var authPrivacyPolicy: String { L(en: "Privacy Policy", ru: "Политикой конфиденциальности", es: "Política de privacidad", pt: "Política de Privacidade", zh: "隐私政策") }
    public static var authComingSoon: String { L(en: "Coming soon", ru: "Скоро будет доступно", es: "Próximamente", pt: "Em breve", zh: "即将推出") }
    public static var authSignInFailed: String { L(en: "Sign-in failed. Please try again.", ru: "Не удалось войти. Попробуйте ещё раз.", es: "Error al iniciar sesión. Inténtalo de nuevo.", pt: "Falha ao entrar. Tente novamente.", zh: "登录失败，请重试。") }
    public static var onboardingChainFailed: String { L(en: "Couldn't finish setting up your account. Please sign in again.", ru: "Не удалось завершить регистрацию. Войдите ещё раз.", es: "No se pudo completar el registro. Inicia sesión de nuevo.", pt: "Não foi possível concluir o cadastro. Entre novamente.", zh: "无法完成注册，请重新登录。") }

    // MARK: - Auth Phone & Code Entry
    // Дублируем Telegram-овские Login_* строки локально: на teamgram-сервере не реализованы
    // langpack.getDifference/getLangPack, без них Telegram presentationData.strings остаётся
    // на en независимо от системного языка. См. FIXME DIVO в TelegramRootController.

    public static var authPhoneTitle: String { L(en: "Your phone", ru: "Ваш номер", es: "Tu teléfono", pt: "Seu telefone", zh: "您的电话号码") }
    public static var authPhoneConfirmation: String { L(en: "Is this the correct number?", ru: "Это правильный номер?", es: "¿Es este el número correcto?", pt: "Este é o número correto?", zh: "这是正确的号码吗？") }
    public static var authContinue: String { L(en: "Continue", ru: "Продолжить", es: "Continuar", pt: "Continuar", zh: "继续") }
    public static var authEdit: String { L(en: "Edit", ru: "Изменить", es: "Editar", pt: "Editar", zh: "编辑") }
    public static var authCodeTitle: String { L(en: "Enter code", ru: "Введите код", es: "Introduce el código", pt: "Insira o código", zh: "输入验证码") }
    public static var languageApplying: String { L(en: "Applying language…", ru: "Применяем язык…", es: "Aplicando idioma…", pt: "Aplicando idioma…", zh: "正在应用语言…") }

    // MARK: - OTP / Code entry
    /// Подзаголовок экрана ввода кода. %@ — номер телефона (выделяется жирным в UI).
    public static var otpCodeSentToFormat: String { L(en: "We sent a 6-digit code to %@", ru: "Мы отправили 6-значный код на %@", es: "Enviamos un código de 6 dígitos a %@", pt: "Enviamos um código de 6 dígitos para %@", zh: "我们已向 %@ 发送6位验证码") }
    public static var otpIncorrectCode: String { L(en: "Incorrect code. Try again.", ru: "Неверный код. Попробуйте ещё раз.", es: "Código incorrecto. Inténtalo de nuevo.", pt: "Código incorreto. Tente novamente.", zh: "验证码错误，请重试。") }
    public static var otpCodeExpired: String { L(en: "Code Expired", ru: "Срок действия кода истёк", es: "Código caducado", pt: "Código expirado", zh: "验证码已过期") }
    /// Текст таймера повторной отправки. %@ — оставшееся время в формате m:ss.
    public static var otpResendInFormat: String { L(en: "Resend in %@", ru: "Повторная отправка через %@", es: "Reenviar en %@", pt: "Reenviar em %@", zh: "%@后重新发送") }
    public static var otpResendCode: String { L(en: "Resend Code", ru: "Отправить код повторно", es: "Reenviar código", pt: "Reenviar código", zh: "重新发送验证码") }

    // MARK: - Common

    public static var ok: String { L(en: "OK", ru: "OK", es: "OK", pt: "OK", zh: "好的") }
    public static var cancel: String { L(en: "Cancel", ru: "Отмена", es: "Cancelar", pt: "Cancelar", zh: "取消") }
    public static var cameraAccessDeniedTitle: String { L(en: "No Camera Access", ru: "Нет доступа к камере", es: "Sin acceso a la cámara", pt: "Sem acesso à câmera", zh: "无法访问相机") }
    public static var cameraAccessDeniedMessage: String { L(en: "Allow camera access in Settings to use this feature", ru: "Разрешите доступ к камере в Настройках, чтобы использовать эту функцию", es: "Permite el acceso a la cámara en Ajustes para usar esta función", pt: "Permita o acesso à câmera em Configurações para usar este recurso", zh: "请在设置中允许访问相机以使用此功能") }
    public static var openSettings: String { L(en: "Settings", ru: "Настройки", es: "Ajustes", pt: "Configurações", zh: "设置") }
    public static var save: String { L(en: "Save", ru: "Сохранить", es: "Guardar", pt: "Salvar", zh: "保存") }
    public static var saving: String { L(en: "Saving...", ru: "Сохранение...", es: "Guardando...", pt: "Salvando...", zh: "保存中...") }
    public static var share: String { L(en: "Share", ru: "Поделиться", es: "Compartir", pt: "Compartilhar", zh: "分享") }
    public static var qrCodeTitle: String { L(en: "QR code", ru: "QR-код", es: "Código QR", pt: "Código QR", zh: "二维码") }
    public static var nextStep: String { L(en: "Next Step", ru: "Следующий шаг", es: "Siguiente Paso", pt: "Próximo Passo", zh: "下一步") }
    public static var delete: String { L(en: "Delete", ru: "Удалить", es: "Eliminar", pt: "Excluir", zh: "删除") }
    public static var edit: String { L(en: "Edit", ru: "Редактировать", es: "Editar", pt: "Editar", zh: "编辑") }
    public static var error: String { L(en: "Error", ru: "Ошибка", es: "Error", pt: "Erro", zh: "错误") }
    public static var search: String { L(en: "Search", ru: "Поиск", es: "Buscar", pt: "Buscar", zh: "搜索") }
    public static var apply: String { L(en: "Apply", ru: "Подать заявку", es: "Aplicar", pt: "Aplicar", zh: "申请") }
    public static var applied: String { L(en: "Applied", ru: "Заявка подана", es: "Solicitado", pt: "Inscrito", zh: "已申请") }
    public static var applying: String { L(en: "Sending...", ru: "Отправляем...", es: "Enviando...", pt: "Enviando...", zh: "申请中...") }
    public static var applyNow: String { L(en: "Apply now", ru: "Подать заявку сейчас", es: "Aplicar ahora", pt: "Candidatar-se agora", zh: "立即申请") }
    public static var viewApplications: String { L(en: "View applications", ru: "Посмотреть заявки", es: "Ver solicitudes", pt: "Ver inscrições", zh: "查看申请") }
    public static var create: String { L(en: "Create", ru: "Создать", es: "Crear", pt: "Criar", zh: "创建") }
    public static var loading: String { L(en: "Loading...", ru: "Загрузка...", es: "Cargando...", pt: "Carregando...", zh: "加载中...") }
    public static var continueButton: String { L(en: "Continue", ru: "Продолжить", es: "Continuar", pt: "Continuar", zh: "继续") }
    public static var notSet: String { L(en: "Not set", ru: "Не задано", es: "No establecido", pt: "Não definido", zh: "未设置") }
    public static var discardChanges: String { L(en: "Discard changes", ru: "Отменить изменения", es: "Descartar cambios", pt: "Descartar alterações", zh: "放弃更改") }
    
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
    public static var parametersUpdated: String { L(en: "Parameters updated", ru: "Параметры обновлены", es: "Parámetros actualizados", pt: "Parâmetros atualizados", zh: "参数已更新") }
    public static var failedLinksUpdated: String { L(en: "Couldn't update social links", ru: "Не удалось обновить ссылки на соцсети", es: "No se pudieron actualizar los enlaces sociales", pt: "Não foi possível atualizar os links sociais", zh: "无法更新社交链接") }
    public static var profileUpdated: String { L(en: "Profile updated", ru: "Профиль обновлён", es: "Perfil actualizado", pt: "Perfil atualizado", zh: "个人资料已更新") }
    public static var failedProfileUpdated: String { L(en: "Couldn't update profile", ru: "Не удалось обновить профиль", es: "No se pudo actualizar el perfil", pt: "Não foi possível atualizar o perfil", zh: "无法更新个人资料") }
    public static var failedParametersUpdated: String { L(en: "Couldn't update parameters", ru: "Не удалось обновить параметры", es: "No se pudieron actualizar los parámetros", pt: "Não foi possível atualizar os parâmetros", zh: "无法更新参数") }
    public static var failedMeasuringSystemUpdated: String { L(en: "Failed to update the measurement system", ru: "Не удалось обновить систему измерения", es: "Error al actualizar el sistema de medición", pt: "Falha ao atualizar o sistema de medição", zh: "更新测量系统失败") }
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
    public static var dateOfBirth: String { L(en: "Date of birth", ru: "Дата рождения", es: "Fecha de nacimiento", pt: "Data de nascimento", zh: "出生日期") }
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
    public static var noSearchResults: String { L(en: "Nothing found", ru: "Ничего не найдено", es: "No se encontró nada", pt: "Nada encontrado", zh: "未找到结果") }
    public static var noSearchResultsSubtitle: String { L(en: "Try a different search query", ru: "Попробуйте изменить запрос", es: "Prueba otra búsqueda", pt: "Tente uma busca diferente", zh: "试试其他搜索词") }
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
    public static var shareWithOrganiser: String { L(en: "We'll share with the organiser", ru: "Мы сообщим организатору", es: "Lo compartiremos con el organizador", pt: "Iremos partilhar com o organizador", zh: "我们将与组织者共享") }
    public static var about: String { L(en: "About", ru: "О событии", es: "Acerca de", pt: "Sobre", zh: "关于") }
    public static var height: String { L(en: "Height", ru: "Рост", es: "Altura", pt: "Altura", zh: "身高") }
    public static var age: String { L(en: "Age", ru: "Возраст", es: "Edad", pt: "Idade", zh: "年龄") }
    public static var previousEvents: String { L(en: "PREVIOUS EVENTS", ru: "ПРОШЕДШИЕ МЕРОПРИЯТИЯ", es: "EVENTOS ANTERIORES", pt: "EVENTOS ANTERIORES", zh: "往期活动") }
    public static var filterBy: String { L(en: "Filter by:", ru: "Фильтр:", es: "Filtrar por:", pt: "Filtrar por:", zh: "筛选：") }
    public static var location: String { L(en: "Location", ru: "Местоположение", es: "Ubicación", pt: "Localização", zh: "位置") }
    public static var allTypes: String { L(en: "All types", ru: "Все типы", es: "Todos los tipos", pt: "Todos os tipos", zh: "所有类型") }
    public static var dateRange: String { L(en: "Date Range", ru: "Диапазон дат", es: "Rango de fechas", pt: "Intervalo de datas", zh: "日期范围") }
    public static var from: String { L(en: "From", ru: "От", es: "Desde", pt: "De", zh: "从") }
    public static var to: String { L(en: "To", ru: "До", es: "Hasta", pt: "Até", zh: "到") }
    public static var applyFilter: String { L(en: "Apply filter", ru: "Применить фильтр", es: "Aplicar filtro", pt: "Aplicar filtro", zh: "应用筛选") }
    public static var whoCanApply: String { L(en: "Who can apply", ru: "Кто может подать заявку", es: "Quién puede aplicar", pt: "Quem pode se inscrever", zh: "谁可以申请") }
    public static var maxParticipants: String { L(en: "Max participants", ru: "Макс. участников", es: "Máx. participantes", pt: "Máx. participantes", zh: "最大参与人数") }
    public static var descriptionCreateEvent: String { L(en: "Description *", ru: "Описание *", es: "Descripción *", pt: "Descrição *", zh: "描述 *") }
    public static var placeholderDescriptionCreateEvent: String { L(en: "Description about event", ru: "Описание события", es: "Descripción del evento", pt: "Descrição do evento", zh: "活动描述") }
    public static var requirementsCreateEvent: String { L(en: "Requirements", ru: "Требования", es: "Requisitos", pt: "Requisitos", zh: "要求") }
    public static var placeholderRequirementsCreateEvent: String { L(en: "Description about requirements", ru: "Описание требований", es: "Descripción de requisitos", pt: "Descrição dos requisitos", zh: "要求描述") }
    public static var ndaRequiredCreateEvent: String { L(en: "NDA required", ru: "Требуется NDA", es: "NDA requerido", pt: "NDA obrigatório", zh: "需要保密协议") }
    public static var deadlineDate: String { L(en: "Application deadline date *", ru: "Дата окончания приема заявок *", es: "Fecha límite de solicitud *", pt: "Data limite para inscrição *", zh: "申请截止日期 *") }
    public static var deadlineTime: String { L(en: "Application deadline time *", ru: "Время окончания приема заявок *", es: "Hora límite de solicitud *", pt: "Horário limite para inscrição *", zh: "申请截止时间 *") }
    public static var rate: String { L(en: "Rate", ru: "Ставка", es: "Tarifa", pt: "Taxa", zh: "费率") }
    public static var rateTime: String { L(en: "Rate time", ru: "Время ставки", es: "Tiempo de tarifa", pt: "Tempo da taxa", zh: "费率时间") }
    public static var publicEvent: String { L(en: "Public event", ru: "Публичное мероприятие", es: "Evento público", pt: "Evento público", zh: "公开活动") }
    public static var visibleAllUsers: String { L(en: "Visible to all users", ru: "Видно всем пользователям", es: "Visible para todos los usuarios", pt: "Visível para todos os usuários", zh: "对所有用户可见") }
    public static var galleryCreateEvent: String { L(en: "Events Photo Gallery", ru: "Фотогалерея событий", es: "Galería de fotos de eventos", pt: "Galeria de fotos de eventos", zh: "活动照片画廊") }
    public static var eventName: String { L(en: "Event name *", ru: "Название события *", es: "Nombre del evento *", pt: "Nome do evento *", zh: "活动名称 *") }
    public static var addPhotoEvent: String { L(en: "Upload event photos", ru: "Загрузить фото события", es: "Subir fotos del evento", pt: "Carregar fotos do evento", zh: "上传活动照片") }
    public static var paidEvent: String { L(en: "Paid event", ru: "Платное мероприятие", es: "Evento de pago", pt: "Evento pago", zh: "付费活动") }
    public static var paid: String { L(en: "Paid", ru: "Платно", es: "De pago", pt: "Pago", zh: "付费") }
    public static var previewEvent: String { L(en: "Preview", ru: "Предпросмотр", es: "Vista previa", pt: "Pré-visualização", zh: "预览") }
    public static func stepCreateEvent(_ currentStep: Int) -> String { L(en: "Step \(currentStep)/3", ru: "Шаг \(currentStep)/3", es: "Paso \(currentStep)/3", pt: "Passo \(currentStep)/3", zh: "步骤 \(currentStep)/3") }
    public static func availableSeatsEvent(_ count: Int) -> String { L(en: "\(count) spots left", ru: "Осталось \(count) мест", es: "\(count) lugares disponibles", pt: "\(count) vagas restantes", zh: "剩余\(count)个名额") }

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
    public static var noModelsTitle: String { L(en: "No Models", ru: "Нет моделей", es: "Sin modelos", pt: "Sem modelos", zh: "暂无模特") }
    public static var noModelsSubtitle: String { L(en: "No models\nfound at the moment.", ru: "Модели\nне найдены.", es: "No se encontraron\nmodelos.", pt: "Nenhum modelo\nencontrado.", zh: "暂未找到\n模特。") }
    public static var noNewTalentsTitle: String { L(en: "No New Talents", ru: "Нет новых лиц", es: "Sin nuevos talentos", pt: "Sem novos talentos", zh: "暂无新人才") }
    public static var noNewTalentsSubtitle: String { L(en: "No new talents\nfound at the moment.", ru: "Новые лица\nне найдены.", es: "No se encontraron\nnuevos talentos.", pt: "Nenhum novo talento\nencontrado.", zh: "暂未找到\n新人才。") }
    public static var noAgenciesTitle: String { L(en: "No Agencies", ru: "Нет агентств", es: "Sin agencias", pt: "Sem agências", zh: "暂无经纪公司") }
    public static var noAgenciesSubtitle: String { L(en: "No agencies\nfound at the moment.", ru: "Агентства\nне найдены.", es: "No se encontraron\nagencias.", pt: "Nenhuma agência\nencontrada.", zh: "暂未找到\n经纪公司。") }

    // MARK: - Profile tab empty states

    public static var profileEmptyPhotosTitle: String { L(en: "There are no photos at the moment", ru: "Здесь пока нет фото", es: "Aún no hay fotos", pt: "Ainda não há fotos", zh: "暂时没有照片") }
    public static var profileEmptyPhotosSubtitleOwn: String { L(en: "You haven't uploaded any photos yet", ru: "Вы ещё не добавили фото", es: "Aún no has subido fotos", pt: "Você ainda não enviou fotos", zh: "您还没有上传任何照片") }
    public static var profileEmptyPhotosSubtitleOther: String { L(en: "This profile hasn't uploaded any photos yet", ru: "В этом профиле пока нет фото", es: "Este perfil aún no ha subido fotos", pt: "Este perfil ainda não enviou fotos", zh: "该资料尚未上传任何照片") }
    public static var profileEmptyPhotosCTA: String { L(en: "Add new photo", ru: "Добавить фото", es: "Añadir foto", pt: "Adicionar foto", zh: "添加新照片") }

    public static var profileEmptyVideosTitle: String { L(en: "There are no videos at the moment", ru: "Здесь пока нет видео", es: "Aún no hay videos", pt: "Ainda não há vídeos", zh: "暂时没有视频") }
    public static var profileEmptyVideosSubtitleOwn: String { L(en: "You haven't uploaded any videos yet", ru: "Вы ещё не добавили видео", es: "Aún no has subido videos", pt: "Você ainda não enviou vídeos", zh: "您还没有上传任何视频") }
    public static var profileEmptyVideosSubtitleOther: String { L(en: "This profile hasn't uploaded any videos yet", ru: "В этом профиле пока нет видео", es: "Este perfil aún no ha subido videos", pt: "Este perfil ainda não enviou vídeos", zh: "该资料尚未上传任何视频") }
    public static var profileEmptyVideosCTA: String { L(en: "Upload new video", ru: "Загрузить видео", es: "Subir video", pt: "Enviar vídeo", zh: "上传新视频") }

    public static var profileEmptyChannelsTitle: String { L(en: "There are no channels at the moment", ru: "Здесь пока нет каналов", es: "Aún no hay canales", pt: "Ainda não há canais", zh: "暂时没有频道") }
    public static var profileEmptyChannelsSubtitleOwn: String { L(en: "You haven't created any channels yet", ru: "Вы ещё не создали каналы", es: "Aún no has creado canales", pt: "Você ainda não criou canais", zh: "您还没有创建任何频道") }
    public static var profileEmptyChannelsSubtitleOther: String { L(en: "This profile hasn't created any channels yet", ru: "В этом профиле пока нет каналов", es: "Este perfil aún no ha creado canales", pt: "Este perfil ainda não criou canais", zh: "该资料尚未创建任何频道") }
    public static var profileEmptyChannelsCTA: String { L(en: "Create new channel", ru: "Создать канал", es: "Crear canal", pt: "Criar canal", zh: "创建新频道") }

    public static var profileEmptyModelsTitle: String { L(en: "There are no models at the moment", ru: "Здесь пока нет моделей", es: "Aún no hay modelos", pt: "Ainda não há modelos", zh: "暂时没有模特") }
    public static var profileEmptyModelsSubtitleOwn: String { L(en: "You haven't added any models yet", ru: "Вы ещё не добавили модели", es: "Aún no has añadido modelos", pt: "Você ainda não adicionou modelos", zh: "您还没有添加任何模特") }
    public static var profileEmptyModelsSubtitleOther: String { L(en: "This profile hasn't added any models yet", ru: "В этом профиле пока нет моделей", es: "Este perfil aún no ha añadido modelos", pt: "Este perfil ainda não adicionou modelos", zh: "该资料尚未添加任何模特") }
    public static var profileEmptyModelsCTA: String { L(en: "Add new model", ru: "Добавить модель", es: "Añadir modelo", pt: "Adicionar modelo", zh: "添加新模特") }

    public static var profileEmptyEventsTitle: String { L(en: "There are no events at the moment", ru: "Здесь пока нет событий", es: "Aún no hay eventos", pt: "Ainda não há eventos", zh: "暂时没有活动") }
    public static var profileEmptyEventsSubtitleOwn: String { L(en: "You haven't created any events yet", ru: "Вы ещё не создали события", es: "Aún no has creado eventos", pt: "Você ainda não criou eventos", zh: "您还没有创建任何活动") }
    public static var profileEmptyEventsSubtitleOther: String { L(en: "This profile hasn't created any events yet", ru: "В этом профиле пока нет событий", es: "Este perfil aún no ha creado eventos", pt: "Este perfil ainda não criou eventos", zh: "该资料尚未创建任何活动") }
    public static var profileEmptyEventsCTA: String { L(en: "Create new event", ru: "Создать событие", es: "Crear evento", pt: "Criar evento", zh: "创建新活动") }
    public static var sendDM: String { L(en: "Send DM", ru: "Написать", es: "Enviar MD", pt: "Enviar MD", zh: "发私信") }
    public static var loadingModelsList: String { L(en: "LOADING MODELS LIST...", ru: "ЗАГРУЗКА СПИСКА МОДЕЛЕЙ...", es: "CARGANDO LISTA DE MODELOS...", pt: "CARREGANDO LISTA DE MODELOS...", zh: "加载模特列表...") }
    public static var loadingTalentsList: String { L(en: "LOADING TALENTS...", ru: "ЗАГРУЗКА ТАЛАНТОВ...", es: "CARGANDO TALENTOS...", pt: "CARREGANDO TALENTOS...", zh: "加载新人才...") }
    public static var loadingAgenciesList: String { L(en: "LOADING AGENCIES...", ru: "ЗАГРУЗКА АГЕНТСТВ...", es: "CARGANDO AGENCIAS...", pt: "CARREGANDO AGÊNCIAS...", zh: "加载经纪公司...") }
    public static var retry: String { L(en: "Retry", ru: "Повторить", es: "Reintentar", pt: "Tentar novamente", zh: "重试") }
    public static var feedLoadErrorTitle: String { L(en: "Couldn't load models", ru: "Не удалось загрузить модели", es: "No se pudieron cargar modelos", pt: "Não foi possível carregar modelos", zh: "无法加载模特") }
    public static var feedLoadErrorSubtitle: String { L(en: "Something went wrong on our end.\nCheck your connection and try again.", ru: "Что-то пошло не так.\nПроверьте подключение и попробуйте снова.", es: "Algo salió mal de nuestro lado.\nVerifique su conexión e inténtelo de nuevo.", pt: "Algo deu errado do nosso lado.\nVerifique sua conexão e tente novamente.", zh: "我们这边出了点问题。\n请检查连接并重试。") }
    public static var feedPaginationError: String { L(en: "Failed to load more", ru: "Не удалось загрузить ещё", es: "Error al cargar más", pt: "Falha ao carregar mais", zh: "加载更多失败") }
    public static var profileTabErrorTitlePhoto: String { L(en: "Couldn't load photos", ru: "Не удалось загрузить фото", es: "No se pudieron cargar fotos", pt: "Não foi possível carregar fotos", zh: "无法加载照片") }
    public static var profileTabErrorTitleVideo: String { L(en: "Couldn't load videos", ru: "Не удалось загрузить видео", es: "No se pudieron cargar videos", pt: "Não foi possível carregar vídeos", zh: "无法加载视频") }
    public static var profileTabErrorTitleChannels: String { L(en: "Couldn't load channels", ru: "Не удалось загрузить каналы", es: "No se pudieron cargar canales", pt: "Não foi possível carregar canais", zh: "无法加载频道") }
    public static var profileTabErrorTitleModels: String { L(en: "Couldn't load models", ru: "Не удалось загрузить модели", es: "No se pudieron cargar modelos", pt: "Não foi possível carregar modelos", zh: "无法加载模特") }
    public static var profileTabErrorTitleEvents: String { L(en: "Couldn't load events", ru: "Не удалось загрузить события", es: "No se pudieron cargar eventos", pt: "Não foi possível carregar eventos", zh: "无法加载活动") }
    public static var eventDetailErrorTitle: String { L(en: "Couldn't load event", ru: "Не удалось загрузить событие", es: "No se pudo cargar el evento", pt: "Não foi possível carregar o evento", zh: "无法加载活动") }
    public static var profileTabErrorNetworkTitle: String { L(en: "No internet connection", ru: "Нет подключения к интернету", es: "Sin conexión a internet", pt: "Sem conexão com a internet", zh: "无网络连接") }
    public static var profileTabErrorSubtitle: String { L(en: "Check your connection\nand try again.", ru: "Проверьте подключение\nи попробуйте снова.", es: "Verifique su conexión\ne inténtelo de nuevo.", pt: "Verifique sua conexão\ne tente novamente.", zh: "请检查您的连接\n并重试。") }
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

    // MARK: - Onboarding — Buttons

    public static var onboardingButtonDone: String { L(en: "Done", ru: "Готово", es: "Listo", pt: "Concluído", zh: "完成") }
    public static var onboardingButtonSkip: String { L(en: "Skip for now", ru: "Пропустить", es: "Omitir por ahora", pt: "Pular por agora", zh: "暂时跳过") }
    public static var onboardingButtonLetsGo: String { L(en: "Let's go", ru: "Поехали", es: "¡Vamos!", pt: "Vamos lá", zh: "出发吧") }
    public static var onboardingResultButtonPrimary: String { L(en: "Sounds right — let's go", ru: "Звучит правильно — поехали", es: "Suena bien, ¡vamos!", pt: "Faz sentido — vamos lá", zh: "听起来不错 — 出发吧") }
    public static var onboardingResultButtonSecondary: String { L(en: "Choose a different role", ru: "Выбрать другую роль", es: "Elegir otro rol", pt: "Escolher outro papel", zh: "选择其他角色") }

    // MARK: - Onboarding — Quiz (top-level)

    public static var onboardingQuizTopLevelSubtitle: String { L(en: "We'll set up your profile based on your answer.\nYou can change this later.", ru: "Мы настроим ваш профиль на основе вашего ответа.\nВы сможете изменить это позже.", es: "Configuraremos tu perfil según tu respuesta.\nPuedes cambiar esto más tarde.", pt: "Configuraremos seu perfil com base na sua resposta.\nVocê pode alterar isso depois.", zh: "我们将根据您的回答设置您的个人资料。\n您可以稍后更改此设置。") }
    public static var onboardingQuizTopLevelOptionGetHiredTitle: String { L(en: "I WANT TO GET HIRED", ru: "ХОЧУ ПОЛУЧАТЬ ЗАКАЗЫ", es: "QUIERO QUE ME CONTRATEN", pt: "QUERO SER CONTRATADO", zh: "我想被雇用") }
    public static var onboardingQuizTopLevelOptionGetHiredSubtitle: String { L(en: "Model, performer, creative pro", ru: "Модель, исполнитель, креатор", es: "Modelo, intérprete, profesional creativo", pt: "Modelo, performer, criativo", zh: "模特、表演者、创意专业人士") }
    public static var onboardingQuizTopLevelOptionLookingForTalentTitle: String { L(en: "I'M LOOKING FOR TALENT", ru: "ИЩУ ТАЛАНТЫ", es: "ESTOY BUSCANDO TALENTO", pt: "ESTOU PROCURANDO TALENTOS", zh: "我在寻找人才") }
    public static var onboardingQuizTopLevelOptionLookingForTalentSubtitle: String { L(en: "Agency, brand, scout, booker", ru: "Агентство, бренд, скаут, букер", es: "Agencia, marca, scout, booker", pt: "Agência, marca, scout, booker", zh: "经纪公司、品牌、星探、预订员") }
    public static var onboardingQuizTopLevelOptionHereToFollowTitle: String { L(en: "I'M HERE TO FOLLOW", ru: "ХОЧУ СЛЕДИТЬ ЗА МОДОЙ", es: "VENGO A SEGUIR", pt: "ESTOU AQUI PARA ACOMPANHAR", zh: "我来关注") }
    public static var onboardingQuizTopLevelOptionHereToFollowSubtitle: String { L(en: "Fan of fashion and creators", ru: "Поклонник моды и креаторов", es: "Fan de la moda y los creadores", pt: "Fã de moda e criadores", zh: "时尚和创作者的粉丝") }

    // MARK: - Onboarding — Quiz (industry door)

    public static var onboardingQuizIndustryDoorTitle: String { L(en: "HOW DO YOU WORK?", ru: "КАК ВЫ РАБОТАЕТЕ?", es: "¿CÓMO TRABAJAS?", pt: "COMO VOCÊ TRABALHA?", zh: "您如何工作？") }
    public static var onboardingQuizIndustryDoorSubtitle: String { L(en: "This helps us tag your right profile", ru: "Это поможет настроить правильный профиль", es: "Esto nos ayuda a configurar tu perfil correcto", pt: "Isso nos ajuda a configurar o perfil certo", zh: "这有助于我们为您设置正确的资料") }
    public static var onboardingQuizIndustryDoorOptionRepresentCompanyTitle: String { L(en: "I REPRESENT A COMPANY", ru: "Я ПРЕДСТАВЛЯЮ КОМПАНИЮ", es: "REPRESENTO A UNA EMPRESA", pt: "REPRESENTO UMA EMPRESA", zh: "我代表一家公司") }
    public static var onboardingQuizIndustryDoorOptionRepresentCompanySubtitle: String { L(en: "Agency, brand, media or studio", ru: "Агентство, бренд, медиа или студия", es: "Agencia, marca, medio o estudio", pt: "Agência, marca, mídia ou estúdio", zh: "机构、品牌、媒体或工作室") }
    public static var onboardingQuizIndustryDoorOptionIndustryProTitle: String { L(en: "I'M AN INDIVIDUAL SPECIALIST", ru: "Я ИНДИВИДУАЛЬНЫЙ СПЕЦИАЛИСТ", es: "SOY UN ESPECIALISTA INDIVIDUAL", pt: "SOU UM ESPECIALISTA INDIVIDUAL", zh: "我是个人专家") }
    public static var onboardingQuizIndustryDoorOptionIndustryProSubtitle: String { L(en: "Scout, booker, casting director...", ru: "Скаут, букер, кастинг-директор...", es: "Scout, director de casting...", pt: "Scout, booker, diretor de elenco...", zh: "星探、经纪、选角导演...") }

    // MARK: - Onboarding — Quiz (sub-role pickers + experience)

    public static var onboardingQuizTalentPickerTitle: String { L(en: "WHAT KIND OF TALENT ARE YOU?", ru: "КАКОГО ТИПА ВЫ ТАЛАНТ?", es: "¿QUÉ TIPO DE TALENTO ERES?", pt: "QUE TIPO DE TALENTO VOCÊ É?", zh: "您是哪种类型的人才？") }
    public static var onboardingQuizTalentPickerSubtitle: String { L(en: "Be honest — this helps us show you the right opportunities", ru: "Будьте честны — это поможет нам показать подходящие возможности", es: "Sé honesto — esto nos ayuda a mostrarte las oportunidades adecuadas", pt: "Seja honesto — isso nos ajuda a mostrar as oportunidades certas", zh: "请如实回答 — 这有助于我们为您展示合适的机会") }
    public static var onboardingQuizTalentPickerSectionTalents: String { L(en: "Talents", ru: "Таланты", es: "Talentos", pt: "Talentos", zh: "人才") }
    public static var onboardingQuizTalentPickerSectionCreative: String { L(en: "Creative", ru: "Креативные", es: "Creativos", pt: "Criativos", zh: "创意") }
    public static var onboardingQuizIndustryProPickerTitle: String { L(en: "WHAT'S YOUR ROLE IN THE INDUSTRY?", ru: "ВАША РОЛЬ В ИНДУСТРИИ?", es: "¿CUÁL ES TU ROL EN LA INDUSTRIA?", pt: "QUAL É O SEU PAPEL NO MERCADO?", zh: "您在行业中的角色是什么？") }
    public static var onboardingQuizIndustryProPickerSubtitle: String { L(en: "Choose the option that best describes what you do day-to-day", ru: "Выберите вариант, который лучше всего описывает вашу работу", es: "Elige la opción que mejor describa lo que haces a diario", pt: "Escolha a opção que melhor descreve o que você faz no dia a dia", zh: "选择最能描述您日常工作的选项") }
    public static var onboardingQuizCompaniesPickerTitle: String { L(en: "WHAT BEST DESCRIBES YOUR COMPANY?", ru: "ЧТО ЛУЧШЕ ВСЕГО ОПИСЫВАЕТ ВАШУ КОМПАНИЮ?", es: "¿QUÉ DESCRIBE MEJOR A TU EMPRESA?", pt: "O QUE MELHOR DESCREVE A SUA EMPRESA?", zh: "什么最能描述您的公司？") }
    public static var onboardingQuizCompaniesPickerSubtitle: String { L(en: "Choose the option that's closest to what you do", ru: "Выберите вариант, ближайший к вашей деятельности", es: "Elige la opción más cercana a lo que haces", pt: "Escolha a opção mais próxima do que você faz", zh: "选择最接近您业务的选项") }

    public static var onboardingQuizExperienceTitle: String { L(en: "DO YOU HAVE PROFESSIONAL MODELLING EXPERIENCE AND AN AGENCY?", ru: "У ВАС ЕСТЬ ПРОФЕССИОНАЛЬНЫЙ ОПЫТ МОДЕЛИ И АГЕНТСТВО?", es: "¿TIENES EXPERIENCIA PROFESIONAL COMO MODELO Y UNA AGENCIA?", pt: "VOCÊ TEM EXPERIÊNCIA PROFISSIONAL COMO MODELO E UMA AGÊNCIA?", zh: "您是否拥有专业模特经验和经纪公司？") }
    public static var onboardingQuizExperienceSubtitle: String { L(en: "This helps us match you with the right castings from day one", ru: "Это поможет с первого дня подбирать вам правильные кастинги", es: "Esto nos ayuda a emparejarte con los castings correctos desde el primer día", pt: "Isso nos ajuda a combiná-lo com os castings certos desde o primeiro dia", zh: "这有助于我们从第一天起为您匹配合适的选角") }
    public static var onboardingQuizExperienceOptionYesTitle: String { L(en: "YES", ru: "ДА", es: "SÍ", pt: "SIM", zh: "是的") }
    public static var onboardingQuizExperienceOptionYesSubtitle: String { L(en: "I have a portfolio and I work with or have worked with an agency", ru: "У меня есть портфолио, и я работаю или работал(а) с агентством", es: "Tengo un portafolio y trabajo o he trabajado con una agencia", pt: "Tenho portfólio e trabalho ou já trabalhei com uma agência", zh: "我有作品集，并且与经纪公司合作过或正在合作") }
    public static var onboardingQuizExperienceOptionNoTitle: String { L(en: "NOT YET", ru: "ПОКА НЕТ", es: "AÚN NO", pt: "AINDA NÃO", zh: "还没有") }
    public static var onboardingQuizExperienceOptionNoSubtitle: String { L(en: "I'm building my career and don't have an agency yet", ru: "Я строю карьеру и пока без агентства", es: "Estoy construyendo mi carrera y aún no tengo agencia", pt: "Estou construindo minha carreira e ainda não tenho agência", zh: "我正在建立自己的职业生涯，目前还没有经纪公司") }

    public static func onboardingQuizProgress(question: Int, of total: Int) -> String {
        return L(
            en: "Question \(question) of \(total)",
            ru: "Вопрос \(question) из \(total)",
            es: "Pregunta \(question) de \(total)",
            pt: "Pergunta \(question) de \(total)",
            zh: "问题 \(question) / \(total)"
        )
    }

    // MARK: - Onboarding — Roles

    public static var onboardingRoleModelingAgency: String { L(en: "Modeling agency", ru: "Модельное агентство", es: "Agencia de modelos", pt: "Agência de modelos", zh: "模特经纪公司") }
    public static var onboardingRoleModelingAgencySubtitle: String { L(en: "I manage a roster of models and handle bookings", ru: "Я управляю списком моделей и занимаюсь бронированиями", es: "Gestiono un catálogo de modelos y manejo reservas", pt: "Eu gerencio uma lista de modelos e cuido das reservas", zh: "我管理模特名单并处理预订") }
    public static var onboardingRoleFashionBrand: String { L(en: "Fashion brand", ru: "Fashion-бренд", es: "Marca de moda", pt: "Marca de moda", zh: "时尚品牌") }
    public static var onboardingRoleFashionBrandSubtitle: String { L(en: "My brand is in fashion: clothing, shoes or accessories", ru: "Мой бренд в сфере моды: одежда, обувь или аксессуары", es: "Mi marca es de moda: ropa, zapatos o accesorios", pt: "Minha marca é de moda: roupas, sapatos ou acessórios", zh: "我的品牌属于时尚领域：服装、鞋类或配饰") }
    public static var onboardingRoleBrandOrBusiness: String { L(en: "Brand or business", ru: "Бренд или бизнес", es: "Marca o negocio", pt: "Marca ou empresa", zh: "品牌或企业") }
    public static var onboardingRoleBrandOrBusinessSubtitle: String { L(en: "I'm a business looking for models: restaurant, hotel, retailer or any other company", ru: "Я бизнес, ищущий моделей: ресторан, отель, ритейлер или любая другая компания", es: "Soy un negocio que busca modelos: restaurante, hotel, minorista o cualquier otra empresa", pt: "Sou uma empresa em busca de modelos: restaurante, hotel, varejista ou qualquer outra empresa", zh: "我是一家寻找模特的企业：餐厅、酒店、零售商或任何其他公司") }
    public static var onboardingRoleBeautyBrand: String { L(en: "Beauty brand", ru: "Beauty-бренд", es: "Marca de belleza", pt: "Marca de beleza", zh: "美妆品牌") }
    public static var onboardingRoleBeautyBrandSubtitle: String { L(en: "I work in beauty: cosmetics, skincare or fragrance", ru: "Я работаю в сфере красоты: косметика, уход за кожей или парфюмерия", es: "Trabajo en belleza: cosméticos, cuidado de la piel o fragancias", pt: "Trabalho com beleza: cosméticos, cuidados com a pele ou fragrâncias", zh: "我从事美妆行业：化妆品、护肤品或香水") }
    public static var onboardingRoleEventAgency: String { L(en: "Event agency", ru: "Event-агентство", es: "Agencia de eventos", pt: "Agência de eventos", zh: "活动公司") }
    public static var onboardingRoleEventAgencySubtitle: String { L(en: "I organise events, shows or promotional activities", ru: "Я организую мероприятия, шоу или промоакции", es: "Organizo eventos, desfiles o actividades promocionales", pt: "Eu organizo eventos, desfiles ou atividades promocionais", zh: "我组织活动、演出或推广活动") }
    public static var onboardingRoleMagazineMedia: String { L(en: "Magazine or media", ru: "Журнал или медиа", es: "Revista o medio", pt: "Revista ou mídia", zh: "杂志或媒体") }
    public static var onboardingRoleMagazineMediaSubtitle: String { L(en: "I'm a publication, media outlet or digital editorial", ru: "Я издательство, медиаресурс или цифровая редакция", es: "Soy una publicación, medio de comunicación o editorial digital", pt: "Sou uma publicação, veículo de mídia ou editorial digital", zh: "我是出版物、媒体机构或数字编辑部") }

    public static var onboardingRoleScout: String { L(en: "Scout", ru: "Скаут", es: "Scout", pt: "Scout", zh: "星探") }
    public static var onboardingRoleScoutSubtitle: String { L(en: "I find new faces, independently or for an agency", ru: "Ищу новые лица — самостоятельно или для агентства", es: "Encuentro nuevas caras, de forma independiente o para una agencia", pt: "Encontro novos rostos, de forma independente ou para uma agência", zh: "我寻找新面孔，独立或为经纪公司") }
    public static var onboardingRoleBooker: String { L(en: "Booker", ru: "Букер", es: "Booker", pt: "Booker", zh: "经纪") }
    public static var onboardingRoleBookerSubtitle: String { L(en: "I manage bookings and negotiations for models at an agency", ru: "Веду бронирования и переговоры для моделей агентства", es: "Gestiono reservas y negociaciones para modelos en una agencia", pt: "Gerencio reservas e negociações para modelos em uma agência", zh: "我为经纪公司的模特管理预订和谈判") }
    public static var onboardingRoleCastingDirector: String { L(en: "Casting Director", ru: "Кастинг-директор", es: "Director de casting", pt: "Diretor de elenco", zh: "选角导演") }
    public static var onboardingRoleCastingDirectorSubtitle: String { L(en: "I run castings for specific projects: shows, ads or film", ru: "Провожу кастинги под конкретные проекты: показы, рекламу или кино", es: "Dirijo castings para proyectos específicos: desfiles, anuncios o cine", pt: "Conduzo castings para projetos específicos: desfiles, anúncios ou cinema", zh: "我为特定项目进行选角：时装秀、广告或电影") }
    public static var onboardingRoleTalentManager: String { L(en: "Talent Manager", ru: "Тalent-менеджер", es: "Director de talentos", pt: "Gerente de talentos", zh: "人才经理") }
    public static var onboardingRoleTalentManagerSubtitle: String { L(en: "I represent and manage individual talent on their career", ru: "Представляю и сопровождаю карьеру конкретных талантов", es: "Represento y gestiono el talento individual y su carrera", pt: "Represento e gerencio talentos individuais em sua carreira", zh: "我代表并管理个人艺人的职业生涯") }

    public static var onboardingRolePhotographer: String { L(en: "Photographer", ru: "Фотограф", es: "Fotógrafo", pt: "Fotógrafo", zh: "摄影师") }
    public static var onboardingRoleStylist: String { L(en: "Stylist", ru: "Стилист", es: "Estilista", pt: "Estilista", zh: "造型师") }
    public static var onboardingRoleMakeupArtist: String { L(en: "Makeup Artist", ru: "Визажист", es: "Maquillador", pt: "Maquiador", zh: "化妆师") }
    public static var onboardingRoleHairStylist: String { L(en: "Hair Stylist", ru: "Парикмахер-стилист", es: "Peluquero", pt: "Cabeleireiro", zh: "发型师") }
    public static var onboardingRoleVideographer: String { L(en: "Videographer", ru: "Видеограф", es: "Videógrafo", pt: "Videógrafo", zh: "摄像师") }
    public static var onboardingRoleCreativeDirector: String { L(en: "Creative Director", ru: "Креативный директор", es: "Director creativo", pt: "Diretor criativo", zh: "创意总监") }
    public static var onboardingRoleFashionDesigner: String { L(en: "Fashion Designer", ru: "Дизайнер одежды", es: "Diseñador de moda", pt: "Estilista de moda", zh: "时装设计师") }
    public static var onboardingRoleStudioLocation: String { L(en: "Studio / Location", ru: "Студия / Локация", es: "Estudio / Ubicación", pt: "Estúdio / Localização", zh: "工作室 / 场地") }

    public static var onboardingRoleModel: String { L(en: "Model", ru: "Модель", es: "Modelo", pt: "Modelo", zh: "模特") }
    public static var onboardingRoleNewTalent: String { L(en: "New Talent", ru: "Новый талант", es: "Talento nuevo", pt: "Novo talento", zh: "新秀") }
    public static var onboardingRoleActor: String { L(en: "Actor or Actress", ru: "Актёр или актриса", es: "Actor o actriz", pt: "Ator ou atriz", zh: "演员") }
    public static var onboardingRoleDancer: String { L(en: "Dancer", ru: "Танцор", es: "Bailarín", pt: "Dançarino", zh: "舞者") }
    public static var onboardingRoleSingerPerformer: String { L(en: "Singer or Performer", ru: "Певец или исполнитель", es: "Cantante o artista", pt: "Cantor ou artista", zh: "歌手或表演者") }
    public static var onboardingRoleFan: String { L(en: "Fan", ru: "Фанат", es: "Fan", pt: "Fã", zh: "粉丝") }

    // MARK: - Onboarding — Result screens (3.3.*)

    public static var onboardingResultModelTitle: String { L(en: "You're a Professional Model", ru: "Вы профессиональная модель", es: "Eres una modelo profesional", pt: "Você é uma modelo profissional", zh: "你是专业模特") }
    public static var onboardingResultModelDescription: String { L(en: "Your profile will be built to showcase your portfolio and connect you directly with agencies and brands looking for experienced talent.", ru: "Ваш профиль покажет портфолио и соединит напрямую с агентствами и брендами, которым нужны опытные таланты.", es: "Tu perfil mostrará tu portafolio y te conectará directamente con agencias y marcas que buscan talento experimentado.", pt: "Seu perfil exibirá seu portfólio e o conectará diretamente com agências e marcas em busca de talentos experientes.", zh: "您的个人资料将展示作品集，并直接与寻找经验丰富的人才的经纪公司和品牌联系。") }
    public static var onboardingResultNewTalentTitle: String { L(en: "You're a Rising Talent", ru: "Вы восходящий талант", es: "Eres un talento emergente", pt: "Você é um talento em ascensão", zh: "你是一名新锐人才") }
    public static var onboardingResultNewTalentDescription: String { L(en: "Your profile will help you build your portfolio, get cast, find TFP shoots with photographers and stylists.", ru: "Профиль поможет наработать портфолио, попасть в кастинги и найти TFP-съёмки с фотографами и стилистами.", es: "Tu perfil te ayudará a crear tu portafolio, conseguir castings y encontrar sesiones TFP con fotógrafos y estilistas.", pt: "Seu perfil ajudará a construir seu portfólio, conseguir castings e encontrar ensaios TFP com fotógrafos e estilistas.", zh: "您的个人资料将帮助您建立作品集、获得选角，并与摄影师和造型师寻找 TFP 拍摄。") }
    public static var onboardingResultActorTitle: String { L(en: "You're an Actor", ru: "Вы актёр", es: "Eres actor", pt: "Você é ator", zh: "你是一名演员") }
    public static var onboardingResultActorDescription: String { L(en: "Your profile will connect you with brands and agencies looking for acting talent for campaigns, fashion films and live events.", ru: "Профиль соединит с брендами и агентствами, которые ищут актёров для кампаний, fashion-фильмов и живых событий.", es: "Tu perfil te conectará con marcas y agencias que buscan talento actoral para campañas, fashion films y eventos en vivo.", pt: "Seu perfil o conectará com marcas e agências em busca de talentos atorais para campanhas, fashion films e eventos.", zh: "您的个人资料将让您与寻找演员的品牌和经纪公司建立联系，参与营销活动、时尚影片和现场活动。") }
    public static var onboardingResultDancerTitle: String { L(en: "You're a Dancer", ru: "Вы танцор", es: "Eres bailarín", pt: "Você é dançarino", zh: "你是一名舞者") }
    public static var onboardingResultDancerDescription: String { L(en: "Your profile will pair your skills with shows, campaigns and events looking for dance talent across all styles.", ru: "Профиль соединит ваши навыки с показами, кампаниями и мероприятиями, которым нужны танцоры любых направлений.", es: "Tu perfil unirá tus habilidades con desfiles, campañas y eventos que buscan talento de danza en todos los estilos.", pt: "Seu perfil unirá suas habilidades a desfiles, campanhas e eventos em busca de dançarinos de todos os estilos.", zh: "您的个人资料将把您的技能与寻找各种风格舞蹈人才的演出、活动和项目相结合。") }
    public static var onboardingResultSingerTitle: String { L(en: "You're a Performer", ru: "Вы исполнитель", es: "Eres un artista", pt: "Você é um artista", zh: "你是一名表演者") }
    public static var onboardingResultSingerDescription: String { L(en: "Your profile will connect you to fashion events, brand campaigns and creative projects looking for performance talent.", ru: "Профиль соединит с fashion-событиями, бренд-кампаниями и креативными проектами, которым нужны исполнители.", es: "Tu perfil te conectará con eventos de moda, campañas de marca y proyectos creativos que buscan talento performático.", pt: "Seu perfil o conectará com eventos de moda, campanhas de marcas e projetos criativos em busca de artistas.", zh: "您的个人资料将让您与寻找表演人才的时尚活动、品牌活动和创意项目建立联系。") }
    public static var onboardingResultCreativeTitle: String { L(en: "You're a creative professional", ru: "Вы творческий профессионал", es: "Eres un profesional creativo", pt: "Você é um profissional criativo", zh: "你是一位创意专业人士") }
    public static var onboardingResultCreativeDescription: String { L(en: "Your profile will showcase your portfolio, let you post projects and connect with models, brands and agencies — on both sides of the market.", ru: "Профиль покажет ваше портфолио, позволит публиковать проекты и соединит с моделями, брендами и агентствами — с обеих сторон рынка.", es: "Tu perfil mostrará tu portafolio, te permitirá publicar proyectos y conectarte con modelos, marcas y agencias en ambos lados del mercado.", pt: "Seu perfil exibirá seu portfólio, permitirá publicar projetos e conectar-se com modelos, marcas e agências — dos dois lados do mercado.", zh: "您的个人资料将展示作品集，让您发布项目，并与模特、品牌和经纪公司建立联系——市场的两端。") }
    public static var onboardingResultCompaniesTitle: String { L(en: "You're here to find talent", ru: "Вы здесь, чтобы найти таланты", es: "Estás aquí para encontrar talento", pt: "Você está aqui para encontrar talentos", zh: "你来这里是为了寻找人才") }
    public static var onboardingResultCompaniesDescription: String { L(en: "Your profile will be set up to search, post castings and connect directly with models and creatives.", ru: "Профиль настроен на поиск, публикацию кастингов и прямой контакт с моделями и креаторами.", es: "Tu perfil estará configurado para buscar, publicar castings y conectarte directamente con modelos y creativos.", pt: "Seu perfil será configurado para buscar, publicar castings e conectar-se diretamente com modelos e criativos.", zh: "您的个人资料将设置为搜索、发布选角并直接与模特和创意人员建立联系。") }
    public static var onboardingResultIndustryProTitle: String { L(en: "You're a talent industry professional", ru: "Вы профессионал в индустрии талантов", es: "Eres un profesional de la industria del talento", pt: "Você é um profissional da indústria de talentos", zh: "你是人才行业的专业人士") }
    public static var onboardingResultIndustryProDescription: String { L(en: "Talent database, advanced search tools and casting workflow — for the way professionals actually work.", ru: "База талантов, продвинутый поиск и кастинг-воркфлоу — так, как реально работают профессионалы.", es: "Base de datos de talento, búsqueda avanzada y flujo de casting — como realmente trabajan los profesionales.", pt: "Base de talentos, busca avançada e fluxo de casting — como os profissionais realmente trabalham.", zh: "人才数据库、高级搜索工具和选角工作流程 — 专为专业人士实际工作方式而设。") }
    public static var onboardingResultFanTitle: String { L(en: "You're a Fashion Fan", ru: "Вы поклонник моды", es: "Eres un fan de la moda", pt: "Você é um fã de moda", zh: "你是时尚爱好者") }
    public static var onboardingResultFanDescription: String { L(en: "You'll be able to follow your favourite models and creators, discover new talent and stay connected to the fashion world.", ru: "Подписывайтесь на любимые модели и креаторов, открывайте новые таланты и оставайтесь в курсе мира моды.", es: "Podrás seguir a tus modelos y creadores favoritos, descubrir nuevos talentos y mantenerte conectado al mundo de la moda.", pt: "Você poderá acompanhar seus modelos e criadores favoritos, descobrir novos talentos e ficar conectado ao mundo da moda.", zh: "您可以关注您喜爱的模特和创作者，发现新人才，并与时尚世界保持联系。") }

    // MARK: - Onboarding — Common sections / fields

    public static var onboardingSectionIdentityTitle: String { L(en: "YOUR IDENTITY", ru: "ВАШИ ДАННЫЕ", es: "TU IDENTIDAD", pt: "SUA IDENTIDADE", zh: "您的身份") }
    public static var onboardingSectionPersonalDetailsTitle: String { L(en: "PERSONAL DETAILS", ru: "ЛИЧНЫЕ ДАННЫЕ", es: "DATOS PERSONALES", pt: "DADOS PESSOAIS", zh: "个人信息") }
    public static var onboardingSectionLocationTitle: String { L(en: "LOCATION", ru: "ЛОКАЦИЯ", es: "UBICACIÓN", pt: "LOCALIZAÇÃO", zh: "位置") }
    public static var onboardingSectionProfilePhotoTitle: String { L(en: "ADD YOUR PROFILE PHOTO", ru: "ДОБАВЬТЕ ФОТО ПРОФИЛЯ", es: "AÑADE TU FOTO DE PERFIL", pt: "ADICIONE SUA FOTO DE PERFIL", zh: "添加您的头像") }
    public static var onboardingSectionProfilePhotoSubtitle: String { L(en: "Use a clear photo of yourself. You can update this any time.", ru: "Загрузите чёткое фото себя. Его можно обновить в любой момент.", es: "Usa una foto clara de ti mismo. Puedes actualizarla en cualquier momento.", pt: "Use uma foto nítida sua. Você pode atualizá-la a qualquer momento.", zh: "请使用一张清晰的本人照片。您可以随时更新。") }

    public static var onboardingFieldFirstNamePlaceholder: String { L(en: "First name *", ru: "Имя *", es: "Nombre *", pt: "Nome *", zh: "名字 *") }
    public static var onboardingFieldLastNamePlaceholder: String { L(en: "Last name *", ru: "Фамилия *", es: "Apellido *", pt: "Sobrenome *", zh: "姓氏 *") }
    public static var onboardingFieldDateOfBirthTitle: String { L(en: "Date of birth", ru: "Дата рождения", es: "Fecha de nacimiento", pt: "Data de nascimento", zh: "出生日期") }
    public static var onboardingFieldDateOfBirthPlaceholder: String { L(en: "Choose a date", ru: "Выберите дату", es: "Elige una fecha", pt: "Escolha uma data", zh: "选择日期") }
    public static var onboardingFieldGenderPlaceholder: String { L(en: "Choose a gender", ru: "Выберите пол", es: "Elige un género", pt: "Escolha um gênero", zh: "选择性别") }
    public static var onboardingFieldCountryTitle: String { L(en: "Country", ru: "Страна", es: "País", pt: "País", zh: "国家") }
    public static var onboardingFieldCityPlaceholder: String { L(en: "City", ru: "Город", es: "Ciudad", pt: "Cidade", zh: "城市") }
    public static var onboardingFieldInstagramHandlePlaceholder: String { L(en: "Instagram handle", ru: "Инстаграм", es: "Usuario de Instagram", pt: "Usuário do Instagram", zh: "Instagram 账号") }
    public static var onboardingFieldInstagramHandleHelp: String { L(en: "Helps you get discovered faster", ru: "Поможет быстрее быть замеченным", es: "Te ayuda a ser descubierto más rápido", pt: "Ajuda você a ser descoberto mais rápido", zh: "帮助您更快被发现") }
    public static var onboardingFieldInstagramOrPortfolioPlaceholder: String { L(en: "Instagram / Portfolio URL", ru: "Инстаграм или URL портфолио", es: "Instagram / URL del portafolio", pt: "Instagram / URL do portfólio", zh: "Instagram / 作品集网址") }
    public static var onboardingFieldProfilePhotoPlaceholder: String { L(en: "Upload from library or take a photo", ru: "Загрузите из библиотеки или сделайте фото", es: "Subir desde la biblioteca o tomar una foto", pt: "Carregar da biblioteca ou tirar uma foto", zh: "从图库上传或拍摄照片") }
    public static var onboardingFieldProfilePhotoHelp: String { L(en: "Any file format supported", ru: "Поддерживается любой формат файла", es: "Se admite cualquier formato", pt: "Qualquer formato de arquivo suportado", zh: "支持任何文件格式") }
    public static var onboardingFieldProfilePhotoSelected: String { L(en: "Photo selected", ru: "Фото выбрано", es: "Foto seleccionada", pt: "Foto selecionada", zh: "已选择照片") }
    public static var onboardingFieldLogoPhotoPlaceholder: String { L(en: "Upload logo or take a photo", ru: "Загрузите логотип или сделайте фото", es: "Subir logo o tomar una foto", pt: "Carregar logo ou tirar uma foto", zh: "上传徽标或拍摄照片") }
    public static var onboardingFieldLogoPhotoHelp: String { L(en: "Any file format supported", ru: "Поддерживается любой формат файла", es: "Se admite cualquier formato", pt: "Qualquer formato de arquivo suportado", zh: "支持任何文件格式") }

    public static var onboardingGenderFemale: String { L(en: "Female", ru: "Женский", es: "Femenino", pt: "Feminino", zh: "女性") }
    public static var onboardingGenderMale: String { L(en: "Male", ru: "Мужской", es: "Masculino", pt: "Masculino", zh: "男性") }
    public static var onboardingGenderNonbinary: String { L(en: "Non-binary", ru: "Небинарный", es: "No binario", pt: "Não-binário", zh: "非二元性别") }
    public static var onboardingGenderPreferNotToSay: String { L(en: "Prefer not to say", ru: "Предпочитаю не указывать", es: "Prefiero no decir", pt: "Prefiro não dizer", zh: "不愿透露") }

    public static func onboardingFormProgress(step: Int, of total: Int) -> String {
        return L(
            en: "Step \(step) of \(total)",
            ru: "Шаг \(step) из \(total)",
            es: "Paso \(step) de \(total)",
            pt: "Etapa \(step) de \(total)",
            zh: "第 \(step) 步，共 \(total) 步"
        )
    }

    // MARK: - Onboarding — Form 4.A Companies & Brands

    public static var onboardingForm4ATitle: String { L(en: "Companies & Brands", ru: "Компании и бренды", es: "Empresas y marcas", pt: "Empresas e marcas", zh: "公司与品牌") }
    public static var onboardingForm4AStep1Title: String { L(en: "TELL US ABOUT YOUR COMPANY", ru: "РАССКАЖИТЕ О КОМПАНИИ", es: "CUÉNTANOS SOBRE TU EMPRESA", pt: "FALE-NOS SOBRE SUA EMPRESA", zh: "请介绍您的公司") }
    public static var onboardingForm4ACompanyNamePlaceholder: String { L(en: "Company / Organisation name *", ru: "Название компании / организации *", es: "Nombre de la empresa / organización *", pt: "Nome da empresa / organização *", zh: "公司 / 机构名称 *") }
    public static var onboardingForm4ACompanyTypeTitle: String { L(en: "Type", ru: "Тип", es: "Tipo", pt: "Tipo", zh: "类型") }
    public static var onboardingForm4ACompanyTypePlaceholder: String { L(en: "Choose a company type", ru: "Выберите тип компании", es: "Elige el tipo de empresa", pt: "Escolha o tipo de empresa", zh: "选择公司类型") }
    public static var onboardingForm4AStep2Title: String { L(en: "WHERE ARE YOU BASED?", ru: "ГДЕ ВЫ НАХОДИТЕСЬ?", es: "¿DÓNDE ESTÁS UBICADO?", pt: "ONDE VOCÊ ESTÁ LOCALIZADO?", zh: "您位于何处？") }
    public static var onboardingForm4AStep3Title: String { L(en: "VERIFICATION & CONTACT", ru: "ВЕРИФИКАЦИЯ И КОНТАКТ", es: "VERIFICACIÓN Y CONTACTO", pt: "VERIFICAÇÃO E CONTATO", zh: "验证与联系方式") }
    public static var onboardingForm4AWebsiteUrlPlaceholder: String { L(en: "Website URL", ru: "URL сайта", es: "URL del sitio web", pt: "URL do site", zh: "网站网址") }
    public static var onboardingForm4AWebsiteUrlHelp: String { L(en: "Helps verify your account", ru: "Поможет верифицировать аккаунт", es: "Ayuda a verificar tu cuenta", pt: "Ajuda a verificar sua conta", zh: "有助于验证您的账户") }
    public static var onboardingForm4AContactFirstNamePlaceholder: String { L(en: "Contact first name", ru: "Имя контакта", es: "Nombre del contacto", pt: "Nome do contato", zh: "联系人名字") }
    public static var onboardingForm4AContactLastNamePlaceholder: String { L(en: "Contact last name", ru: "Фамилия контакта", es: "Apellido del contacto", pt: "Sobrenome do contato", zh: "联系人姓氏") }
    public static var onboardingForm4AContactRolePlaceholder: String { L(en: "Contact role / title", ru: "Должность контакта", es: "Cargo del contacto", pt: "Cargo do contato", zh: "联系人职位") }
    public static var onboardingForm4AStep4Title: String { L(en: "ADD YOUR LOGO OR PROFILE PHOTO", ru: "ДОБАВЬТЕ ЛОГОТИП ИЛИ ФОТО", es: "AÑADE TU LOGO O FOTO DE PERFIL", pt: "ADICIONE SEU LOGO OU FOTO DE PERFIL", zh: "添加您的徽标或头像") }

    // MARK: - Onboarding — Form 4.B Industry Professionals

    public static var onboardingForm4BTitle: String { L(en: "Industry Professionals", ru: "Профессионалы индустрии", es: "Profesionales de la industria", pt: "Profissionais do mercado", zh: "行业专业人士") }
    public static var onboardingForm4BStep1Title: String { L(en: "YOUR PROFESSIONAL IDENTITY", ru: "ВАШ ПРОФЕССИОНАЛЬНЫЙ ПРОФИЛЬ", es: "TU IDENTIDAD PROFESIONAL", pt: "SUA IDENTIDADE PROFISSIONAL", zh: "您的职业身份") }
    public static var onboardingForm4BRoleTitle: String { L(en: "Role", ru: "Роль", es: "Rol", pt: "Função", zh: "角色") }
    public static var onboardingForm4BRolePlaceholder: String { L(en: "Choose a role", ru: "Выберите роль", es: "Elige un rol", pt: "Escolha uma função", zh: "选择一个角色") }
    public static var onboardingForm4BStep3Title: String { L(en: "PROFESSIONAL LINKS", ru: "ПРОФЕССИОНАЛЬНЫЕ ССЫЛКИ", es: "ENLACES PROFESIONALES", pt: "LINKS PROFISSIONAIS", zh: "职业链接") }
    public static var onboardingForm4BAgencyPlaceholder: String { L(en: "Agency / Organisation", ru: "Агентство / Организация", es: "Agencia / Organización", pt: "Agência / Organização", zh: "经纪公司 / 机构") }
    public static var onboardingForm4BAgencyHelp: String { L(en: "Your agency will receive a confirmation request", ru: "Агентству придёт запрос на подтверждение", es: "Tu agencia recibirá una solicitud de confirmación", pt: "Sua agência receberá um pedido de confirmação", zh: "您的经纪公司将收到确认请求") }

    // MARK: - Onboarding — Form 4.C1 Creative Individual

    public static var onboardingForm4C1Title: String { L(en: "Creative Professionals — Individual", ru: "Creative-профессионалы — индивидуально", es: "Profesionales creativos — individual", pt: "Profissionais criativos — individual", zh: "创意专业人士 — 个人") }
    public static var onboardingForm4C1Step1Title: String { L(en: "YOUR CREATIVE IDENTITY", ru: "ВАШ КРЕАТИВНЫЙ ПРОФИЛЬ", es: "TU IDENTIDAD CREATIVA", pt: "SUA IDENTIDADE CRIATIVA", zh: "您的创意身份") }
    public static var onboardingForm4C1SpecialisationTitle: String { L(en: "Specialisation", ru: "Специализация", es: "Especialización", pt: "Especialização", zh: "专长") }
    public static var onboardingForm4C1SpecialisationPlaceholder: String { L(en: "Choose a specialisation", ru: "Выберите специализацию", es: "Elige una especialización", pt: "Escolha uma especialização", zh: "选择专业方向") }
    public static var onboardingForm4C1Step3Title: String { L(en: "ADD YOUR PORTFOLIO", ru: "ДОБАВЬТЕ ПОРТФОЛИО", es: "AÑADE TU PORTAFOLIO", pt: "ADICIONE SEU PORTFÓLIO", zh: "添加您的作品集") }
    public static var onboardingForm4C1Step3Subtitle: String { L(en: "Recommended — helps clients find your work faster", ru: "Рекомендуется — клиенты быстрее находят ваши работы", es: "Recomendado — ayuda a los clientes a encontrar tu trabajo más rápido", pt: "Recomendado — ajuda os clientes a encontrar seu trabalho mais rápido", zh: "推荐 — 帮助客户更快找到您的作品") }
    public static var onboardingForm4C1PortfolioHelp: String { L(en: "Share a link to your Instagram, Behance, personal site or any portfolio", ru: "Поделитесь ссылкой на Инстаграм, Behance, личный сайт или любое портфолио", es: "Comparte un enlace a tu Instagram, Behance, sitio personal o cualquier portafolio", pt: "Compartilhe um link para seu Instagram, Behance, site pessoal ou qualquer portfólio", zh: "分享您的 Instagram、Behance、个人网站或任何作品集的链接") }

    // MARK: - Onboarding — Form 4.C2 Creative Studio

    public static var onboardingForm4C2Title: String { L(en: "Creative Professionals — Studio", ru: "Creative-профессионалы — студия", es: "Profesionales creativos — estudio", pt: "Profissionais criativos — estúdio", zh: "创意专业人士 — 工作室") }
    public static var onboardingForm4C2Step1Title: String { L(en: "YOUR STUDIO DETAILS", ru: "ДАННЫЕ СТУДИИ", es: "DETALLES DE TU ESTUDIO", pt: "DADOS DO SEU ESTÚDIO", zh: "工作室详情") }
    public static var onboardingForm4C2StudioNamePlaceholder: String { L(en: "Studio / space name *", ru: "Название студии / пространства *", es: "Nombre del estudio / espacio *", pt: "Nome do estúdio / espaço *", zh: "工作室 / 场地名称 *") }
    public static var onboardingForm4C2Step2Title: String { L(en: "CONTACT DETAILS", ru: "КОНТАКТНЫЕ ДАННЫЕ", es: "DATOS DE CONTACTO", pt: "DADOS DE CONTATO", zh: "联系方式") }
    public static var onboardingForm4C2WebsiteOrInstagramPlaceholder: String { L(en: "Website or Instagram", ru: "Сайт или Инстаграм", es: "Sitio web o Instagram", pt: "Site ou Instagram", zh: "网站或 Instagram") }
    public static var onboardingForm4C2WebsiteOrInstagramHelp: String { L(en: "Light verification signal", ru: "Лёгкий сигнал верификации", es: "Señal de verificación ligera", pt: "Sinal leve de verificação", zh: "轻量级验证标识") }
    public static var onboardingForm4C2ContactNamePlaceholder: String { L(en: "Contact name", ru: "Имя контакта", es: "Nombre de contacto", pt: "Nome do contato", zh: "联系人姓名") }
    public static var onboardingForm4C2ContactNameHelp: String { L(en: "Person managing bookings", ru: "Кто отвечает за брони", es: "Persona que gestiona reservas", pt: "Pessoa que gerencia reservas", zh: "管理预订的负责人") }
    public static var onboardingForm4C2ContactPhoneOrEmailPlaceholder: String { L(en: "Contact phone or email", ru: "Телефон или email", es: "Teléfono o email", pt: "Telefone ou email", zh: "联系电话或邮箱") }
    public static var onboardingForm4C2ContactPhoneOrEmailHelp: String { L(en: "For booking enquiries", ru: "Для запросов на бронирование", es: "Para consultas de reservas", pt: "Para solicitações de reserva", zh: "用于预订咨询") }
    public static var onboardingForm4C2Step3Title: String { L(en: "SHOW YOUR MAIN SPACE", ru: "ПОКАЖИТЕ ГЛАВНОЕ ПОМЕЩЕНИЕ", es: "MUESTRA TU ESPACIO PRINCIPAL", pt: "MOSTRE SEU ESPAÇO PRINCIPAL", zh: "展示您的主要场地") }
    public static var onboardingForm4C2Step3Subtitle: String { L(en: "Clients want to see what they're booking", ru: "Клиенты хотят видеть, что бронируют", es: "Los clientes quieren ver lo que reservan", pt: "Os clientes querem ver o que estão reservando", zh: "客户希望看到他们预订的内容") }

    // MARK: - Onboarding — Form 4.D1 Model

    public static var onboardingForm4D1Title: String { L(en: "Talent — Model", ru: "Талант — модель", es: "Talento — modelo", pt: "Talento — modelo", zh: "人才 — 模特") }
    public static var onboardingForm4D1Step3Title: String { L(en: "PROFESSIONAL LINKS", ru: "ПРОФЕССИОНАЛЬНЫЕ ССЫЛКИ", es: "ENLACES PROFESIONALES", pt: "LINKS PROFISSIONAIS", zh: "职业链接") }
    public static var onboardingForm4D1CurrentAgencyPlaceholder: String { L(en: "Current or last agency", ru: "Текущее или последнее агентство", es: "Agencia actual o última", pt: "Agência atual ou última", zh: "现任或最近的经纪公司") }
    public static var onboardingForm4D1CurrentAgencyHelp: String { L(en: "Add your agency to get a verified badge", ru: "Укажите агентство, чтобы получить значок верификации", es: "Añade tu agencia para obtener una insignia verificada", pt: "Adicione sua agência para ganhar um selo verificado", zh: "添加您的经纪公司以获得验证徽章") }
    public static var onboardingForm4D1Step4Title: String { L(en: "SHOW THE WORLD WHO YOU ARE", ru: "ПОКАЖИТЕ МИРУ, КТО ВЫ", es: "MUESTRA AL MUNDO QUIÉN ERES", pt: "MOSTRE AO MUNDO QUEM VOCÊ É", zh: "向世界展示您是谁") }
    public static var onboardingForm4D1Step4Subtitle: String { L(en: "Use a clear, front-facing photo. You can update this any time.", ru: "Используйте чёткое фото анфас. Его можно обновить в любой момент.", es: "Usa una foto clara de frente. Puedes actualizarla en cualquier momento.", pt: "Use uma foto nítida de frente. Você pode atualizá-la a qualquer momento.", zh: "请使用一张清晰的正面照片。您可以随时更新。") }

    // MARK: - Onboarding — Form 4.D2 New Talent

    public static var onboardingForm4D2Title: String { L(en: "Talent — New Talent", ru: "Талант — новый талант", es: "Talento — nuevo talento", pt: "Talento — novo talento", zh: "人才 — 新人") }
    public static var onboardingForm4D2Step3Title: String { L(en: "PROFESSIONAL LINKS", ru: "ПРОФЕССИОНАЛЬНЫЕ ССЫЛКИ", es: "ENLACES PROFESIONALES", pt: "LINKS PROFISSIONAIS", zh: "职业链接") }
    public static var onboardingForm4D2Step4Title: String { L(en: "ADD YOUR PROFILE PHOTO", ru: "ДОБАВЬТЕ ФОТО ПРОФИЛЯ", es: "AÑADE TU FOTO DE PERFIL", pt: "ADICIONE SUA FOTO DE PERFIL", zh: "添加您的头像") }
    public static var onboardingForm4D2TfpHintTitle: String { L(en: "Your first step: find a TFP shoot", ru: "Ваш первый шаг: найдите TFP-съёмку", es: "Tu primer paso: encuentra una sesión TFP", pt: "Seu primeiro passo: encontre um ensaio TFP", zh: "你的第一步：找到一次TFP拍摄") }
    public static var onboardingForm4D2TfpHintSubtitle: String { L(en: "TFP (Time For Portfolio) shoots are free collaborations with photographers. They'll build your portfolio fast. We'll show you how when you're in the app", ru: "TFP-съёмки (Time For Portfolio) — это бесплатное сотрудничество с фотографами. Они быстро создадут ваше портфолио. Мы покажем вам как, когда вы войдёте в приложение", es: "Las sesiones TFP (Time For Portfolio) son colaboraciones gratuitas con fotógrafos. Construirán tu portafolio rápidamente. Te mostraremos cómo cuando estés en la app", pt: "Os ensaios TFP (Time For Portfolio) são colaborações gratuitas com fotógrafos. Eles construirão seu portfólio rapidamente. Mostraremos como quando você estiver no aplicativo", zh: "TFP（作品集时间）拍摄是与摄影师的免费合作。它们能快速建立你的作品集。当你进入应用后，我们会告诉你具体方法") }

    // MARK: - Onboarding — Form 4.D3 Actor / Dancer / Singer

    public static var onboardingForm4D3Title: String { L(en: "Talent — Actor / Dancer / Singer", ru: "Талант — актёр / танцор / певец", es: "Talento — actor / bailarín / cantante", pt: "Talento — ator / dançarino / cantor", zh: "人才 — 演员 / 舞者 / 歌手") }
    public static var onboardingForm4D3Step3Title: String { L(en: "PROFESSIONAL LINKS", ru: "ПРОФЕССИОНАЛЬНЫЕ ССЫЛКИ", es: "ENLACES PROFESIONALES", pt: "LINKS PROFISSIONAIS", zh: "职业链接") }
    public static var onboardingForm4D3SpecialisationTitle: String { L(en: "Specialisation", ru: "Специализация", es: "Especialización", pt: "Especialização", zh: "专长") }
    public static var onboardingForm4D3SpecialisationPlaceholder: String { L(en: "Choose a specialisation", ru: "Выберите специализацию", es: "Elige una especialización", pt: "Escolha uma especialização", zh: "选择专业方向") }
    public static var onboardingForm4D3ShowreelUrlPlaceholder: String { L(en: "Showreel / demo reel URL", ru: "URL шоурила / демо-рила", es: "URL de showreel / demo reel", pt: "URL do showreel / demo reel", zh: "演示视频网址") }
    public static var onboardingForm4D3InstagramOrCastingPlaceholder: String { L(en: "Instagram / casting profile URL", ru: "Инстаграм / URL кастинг-профиля", es: "Instagram / URL del perfil de casting", pt: "Instagram / URL do perfil de casting", zh: "Instagram / 选角资料网址") }

    public static var onboardingForm4D3ActorSpecFilm: String { L(en: "Film", ru: "Кино", es: "Cine", pt: "Cinema", zh: "电影") }
    public static var onboardingForm4D3ActorSpecTheatre: String { L(en: "Theatre", ru: "Театр", es: "Teatro", pt: "Teatro", zh: "戏剧") }
    public static var onboardingForm4D3ActorSpecCommercial: String { L(en: "Commercial", ru: "Реклама", es: "Comercial", pt: "Comercial", zh: "广告") }
    public static var onboardingForm4D3ActorSpecDubbing: String { L(en: "Dubbing", ru: "Дубляж", es: "Doblaje", pt: "Dublagem", zh: "配音") }
    public static var onboardingForm4D3ActorSpecTV: String { L(en: "TV", ru: "ТВ", es: "TV", pt: "TV", zh: "电视") }
    public static var onboardingForm4D3SpecOther: String { L(en: "Other", ru: "Другое", es: "Otro", pt: "Outro", zh: "其他") }

    public static var onboardingForm4D3DancerSpecContemporary: String { L(en: "Contemporary", ru: "Контемпорари", es: "Contemporáneo", pt: "Contemporâneo", zh: "现代舞") }
    public static var onboardingForm4D3DancerSpecBallet: String { L(en: "Ballet", ru: "Балет", es: "Ballet", pt: "Balé", zh: "芭蕾舞") }
    public static var onboardingForm4D3DancerSpecHipHop: String { L(en: "Hip-hop", ru: "Хип-хоп", es: "Hip-hop", pt: "Hip-hop", zh: "嘻哈") }
    public static var onboardingForm4D3DancerSpecBallroom: String { L(en: "Ballroom", ru: "Бальные", es: "Salón", pt: "Salão", zh: "国标舞") }
    public static var onboardingForm4D3DancerSpecLatin: String { L(en: "Latin", ru: "Латино", es: "Latino", pt: "Latina", zh: "拉丁") }
    public static var onboardingForm4D3DancerSpecJazz: String { L(en: "Jazz", ru: "Джаз", es: "Jazz", pt: "Jazz", zh: "爵士") }

    public static var onboardingForm4D3SingerSpecPop: String { L(en: "Pop", ru: "Поп", es: "Pop", pt: "Pop", zh: "流行") }
    public static var onboardingForm4D3SingerSpecRnB: String { L(en: "R&B", ru: "R&B", es: "R&B", pt: "R&B", zh: "R&B") }
    public static var onboardingForm4D3SingerSpecJazz: String { L(en: "Jazz", ru: "Джаз", es: "Jazz", pt: "Jazz", zh: "爵士") }
    public static var onboardingForm4D3SingerSpecClassical: String { L(en: "Classical", ru: "Классика", es: "Clásica", pt: "Clássica", zh: "古典") }
    public static var onboardingForm4D3SingerSpecMusicalTheatre: String { L(en: "Musical Theatre", ru: "Мюзикл", es: "Teatro musical", pt: "Teatro musical", zh: "音乐剧") }
    public static var onboardingForm4D3SingerSpecOpera: String { L(en: "Opera", ru: "Опера", es: "Ópera", pt: "Ópera", zh: "歌剧") }

    // MARK: - Onboarding — Form 4.E Fan

    public static var onboardingForm4ETitle: String { L(en: "Fan Registration", ru: "Регистрация фана", es: "Registro de fan", pt: "Cadastro de fã", zh: "粉丝注册") }
    public static var onboardingForm4EStep1Title: String { L(en: "TELL US ABOUT YOURSELF", ru: "РАССКАЖИТЕ О СЕБЕ", es: "CUÉNTANOS SOBRE TI", pt: "FALE-NOS SOBRE VOCÊ", zh: "请介绍您自己") }
    public static var onboardingForm4EStep2Title: String { L(en: "ADD YOUR PROFILE PHOTO", ru: "ДОБАВЬТЕ ФОТО ПРОФИЛЯ", es: "AÑADE TU FOTO DE PERFIL", pt: "ADICIONE SUA FOTO DE PERFIL", zh: "添加您的头像") }
    public static var onboardingForm4EStep2Subtitle: String { L(en: "Use a clear photo of yourself. You can update this any time.", ru: "Загрузите чёткое фото себя. Его можно обновить в любой момент.", es: "Usa una foto clara de ti mismo. Puedes actualizarla en cualquier momento.", pt: "Use uma foto nítida sua. Você pode atualizá-la a qualquer momento.", zh: "请使用一张清晰的本人照片。您可以随时更新。") }

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
    public static var debugUISection: String { "UI" }
    public static var debugShowTouches: String { L(en: "Show touches on screen", ru: "Показывать жесты на экране", es: "Mostrar toques en pantalla", pt: "Mostrar toques na tela", zh: "在屏幕上显示触摸") }
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
    public static var failedToUploadAvatar: String { L(en: "Couldn't upload avatar", ru: "Не удалось загрузить аватар", es: "No se pudo subir el avatar", pt: "Não foi possível carregar o avatar", zh: "无法上传头像") }
    public static var unknownCity: String { L(en: "Unknown city", ru: "Неизвестный город", es: "Ciudad desconocida", pt: "Cidade desconhecida", zh: "未知城市") }
    public static var tbd: String { L(en: "TBD", ru: "Уточняется", es: "Por definir", pt: "A definir", zh: "待定") }
    public static var eventFallbackName: String { L(en: "Event", ru: "Событие", es: "Evento", pt: "Evento", zh: "活动") }
    public static var roleFallbackUser: String { L(en: "User", ru: "Пользователь", es: "Usuario", pt: "Usuário", zh: "用户") }
    public static var failedToUpdateEvent: String { L(en: "Failed to update event", ru: "Не удалось обновить событие", es: "Error al actualizar el evento", pt: "Falha ao atualizar o evento", zh: "更新活动失败") }
    public static var failedToCreateEvent: String { L(en: "Failed to create event", ru: "Не удалось создать событие", es: "Error al crear el evento", pt: "Falha ao criar o evento", zh: "创建活动失败") }
    public static var addShort: String { L(en: "+ Add", ru: "+ Добавить", es: "+ Agregar", pt: "+ Adicionar", zh: "+ 添加") }
    public static var addOnlyTextShort: String { L(en: "Add", ru: "Добавить", es: "Agregar", pt: "Adicionar", zh: "添加") }
    public static var searchPlaceholder: String { L(en: "Search...", ru: "Поиск...", es: "Buscar...", pt: "Buscar...", zh: "搜索...") }
    public static func nSelected(_ n: Int) -> String {
        L(en: "\(n) selected", ru: "\(n) выбрано", es: "\(n) seleccionados", pt: "\(n) selecionados", zh: "已选\(n)项")
    }
    public static var emptyTitleAddEvent: String { L(en: "There are no upcoming\nevents at the moment.", ru: "Пока нет предстоящих\nсобытий", es: "No hay eventos\npróximos en este momento", pt: "Não há eventos\nfuturos no momento", zh: "目前暂无即将举行的活动") }
    public static var emptySubTitleAddEvent: String { L(en: "Check back later or create\na new one", ru: "Загляните позже или\nсоздайте новое", es: "Vuelve más tarde o\ncrea uno nuevo", pt: "Volte mais tarde ou\ncrie um novo", zh: "稍后再试或创建新活动") }
    public static var editEvent: String { L(en: "Edit event", ru: "Редактировать событие", es: "Editar evento", pt: "Editar evento", zh: "编辑活动") }
    public static var closeApplications: String { L(en: "Close applications", ru: "Закрыть подачу заявок", es: "Cerrar inscripciones", pt: "Encerrar inscrições", zh: "关闭申请") }
    public static var cancelEvent: String { L(en: "Cancel event", ru: "Отменить событие", es: "Cancelar evento", pt: "Cancelar evento", zh: "取消活动") }
    public static var publishEvent: String { L(en: "Publish event", ru: "Опубликовать событие", es: "Publicar evento", pt: "Publicar evento", zh: "发布活动") }
    public static var applyPreviewOnly: String { L(en: "Apply now (preview only)", ru: "Подать заявку (только предпросмотр)", es: "Aplicar ahora (solo vista previa)", pt: "Candidatar-se agora (apenas visualização)", zh: "立即申请（仅预览）") }
    public static func closesData(_ data: String) -> String { L(en: "Closes: \(data)", ru: "Закрытие: \(data)", es: "Cierre: \(data)", pt: "Encerramento: \(data)", zh: "截止: \(data)") }
    public static var viewEventPage: String { L(en: "View event page", ru: "Просмотр страницы события", es: "Ver página del evento", pt: "Ver página do evento", zh: "查看活动页面") }
    public static var manageApplications: String { L(en: "Manage applications", ru: "Управление заявками", es: "Gestionar solicitudes", pt: "Gerenciar candidaturas", zh: "管理申请") }
    public static var subtitleCreateEvent: String { L(en: "Fashion model event is now\nvisible to all users", ru: "Событие для фешн-моделей теперь\nвидно всем пользователям", es: "El evento de modelos de moda ahora\nes visible para todos los usuarios", pt: "O evento de modelo de moda agora\nestá visível para todos os usuários", zh: "时尚模特活动现在\n对所有用户可见") }
    public static var titleCreateEvent: String { L(en: "Your event is live!", ru: "Ваше событие опубликовано!", es: "¡Tu evento está en vivo!", pt: "Seu evento está no ar!", zh: "您的活动已上线！") }
    public static var errorCreateUpdateEvent: String { L(en: "Couldn't post event", ru: "Не удалось опубликовать событие", es: "No se pudo publicar el evento", pt: "Não foi possível publicar o evento", zh: "无法发布活动") }
    public static var chooseEvent: String { L(en: "Choose an event", ru: "Выберите событие", es: "Elige un evento", pt: "Escolha um evento", zh: "选择一个活动") }
    public static var you: String { L(en: "@you", ru: "@вы", es: "@tú", pt: "@você", zh: "@你") }
    public static var withdrawApplication: String { L(en: "Withdraw application", ru: "Отозвать заявку", es: "Retirar solicitud", pt: "Retirar inscrição", zh: "撤销申请") }
    public static func youAppliedOn(_ data: String) -> String { L(en: "You applied on \(data)", ru: "Вы подали заявку \(data)", es: "Solicitaste el \(data)", pt: "Você se inscreveu em \(data)", zh: "您于 \(data) 提交申请") }
    public static var withdrawSheetTitle: String { L(en: "Withdraw your application?", ru: "Отозвать вашу заявку?", es: "¿Retirar tu solicitud?", pt: "Retirar sua inscrição?", zh: "撤销您的申请？") }
    public static var withdrawSheetSubtitle: String { L(en: "The organiser will be notified. You won't be able to reapply to this event.", ru: "Организатор будет уведомлен. Вы не сможете подать заявку на это событие снова.", es: "Se notificará al organizador. No podrás volver a solicitarlo para este evento.", pt: "O organizador será notificado. Você não poderá se inscrever novamente neste evento.", zh: "组织者将收到通知。您将无法重新申请此活动。") }
    public static var keepApplication: String { L(en: "Keep application", ru: "Оставить заявку", es: "Mantener solicitud", pt: "Manter inscrição", zh: "保留申请") }
    public static var withdrawConfirm: String { L(en: "Yes, withdraw", ru: "Да, отозвать", es: "Sí, retirar", pt: "Sim, retirar", zh: "是的，撤销") }
    public static var submitApplication: String { L(en: "Submit application", ru: "Отправить заявку", es: "Enviar solicitud", pt: "Enviar candidatura", zh: "提交申请") }
    public static var parametersApplying: String { L(en: "Parameters for Applying", ru: "Параметры для подачи", es: "Parámetros para solicitar", pt: "Parâmetros para candidatura", zh: "申请参数") }
    public static var fewParametersDont: String { L(en: "Some parameters don't match. Apply anyway?", ru: "Некоторые параметры не совпадают. Всё равно отправить?", es: "Algunos parámetros no coinciden. ¿Solicitar de todos modos?", pt: "Alguns parâmetros não correspondem. Candidatar-se assim mesmo?", zh: "部分参数不匹配。仍然提交申请？") }
    public static func oneParameterDont(_ parameter: String) -> String { L(en: "Your \(parameter) doesn't match. Apply anyway?", ru: "Ваш параметр «\(parameter)» не совпадает. Всё равно отправить?", es: "Tu \(parameter) no coincide. ¿Solicitar de todos modos?", pt: "Seu/sua \(parameter) não corresponde. Candidatar-se assim mesmo?", zh: "您的\(parameter)不匹配。仍然提交申请？") }
    public static var allParametersSuccess: String { L(en: "All parameters are suitable for this event!", ru: "Все параметры подходят для этого события!", es: "¡Todos los parámetros son adecuados para este evento!", pt: "Todos os parâmetros são adequados para este evento!", zh: "所有参数均适用于此活动！") }
    public static var submit: String { L(en: "Submit", ru: "Отправить", es: "Enviar", pt: "Enviar", zh: "提交") }
    public static var sending: String { L(en: "Sending...", ru: "Отправка...", es: "Enviando...", pt: "A enviar...", zh: "发送中...") }
    public static var sendApplyRequestFail: String { L(en: "Couldn't send a request for an event", ru: "Не удалось отправить запрос на участие в событии", es: "No se pudo enviar la solicitud para el evento", pt: "Não foi possível enviar o pedido para o evento", zh: "无法发送活动请求") }
    public static var withdrawApplicationFail: String { L(en: "Couldn't withdraw the application", ru: "Не удалось отозвать заявку", es: "No se pudo retirar la solicitud", pt: "Não foi possível retirar a inscrição", zh: "无法撤销申请") }
    public static func rangeFrom(_ value: String) -> String { L(en: "From \(value)", ru: "От \(value)", es: "Desde \(value)", pt: "A partir de \(value)", zh: "从\(value)起") }
    public static func rangeUpTo(_ value: String) -> String { L(en: "Up to \(value)", ru: "До \(value)", es: "Hasta \(value)", pt: "Até \(value)", zh: "最多\(value)") }
    public static var eventApplyTitle: String { L(en: "You're in!", ru: "Вы участвуете!", es: "¡Estás dentro!", pt: "Está confirmado!", zh: "您已加入！") }
    public static func eventApplySubtitle(_ date: String) -> String { L(en: "Your application has been sent. The organiser will review it by \(date).", ru: "Ваша заявка отправлена. Организатор рассмотрит её до \(date).", es: "Su solicitud ha sido enviada. El organizador la revisará antes del \(date).", pt: "A sua candidatura foi enviada. O organizador irá analisá-la até \(date).", zh: "您的申请已发送。组织者将在\(date)前进行审核。") }

    // MARK: - Feed Events
    
    public static var eventsMy: String { L(en: "My Events", ru: "Мои события", es: "Mis eventos", pt: "Meus eventos", zh: "我的活动") }
    public static var eventsAll: String { L(en: "All Events", ru: "Все события", es: "Todos los eventos", pt: "Todos os eventos", zh: "所有活动") }
    public static var failedApplyEvent: String { L(en: "Failed to send application", ru: "Не удалось подать заявку", es: "No se pudo enviar la solicitud", pt: "Não foi possível enviar a inscrição", zh: "申请提交失败") }
    public static var feedEventLoadErrorTitle: String { L(en: "Couldn't load events", ru: "Не удалось загрузить события", es: "No se pudieron cargar los eventos", pt: "Não foi possível carregar os eventos", zh: "无法加载活动") }
    public static var feedEventLoadErrorSubtitle: String { L(en: "Something went wrong on our end.\nCheck your connection and try again.", ru: "Что-то пошло не так с нашей стороны.\nПроверьте соединение и попробуйте снова.", es: "Algo salió mal de nuestro lado.\nVerifica tu conexión e inténtalo de nuevo.", pt: "Algo deu errado da nossa parte.\nVerifique sua conexão e tente novamente.", zh: "我们的端出了问题。\n请检查连接后重试。") }
    
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
    public static func deadlineData(_ data: String) -> String { L(en: "Deadline: \(data)", ru: "Дедлайн: \(data)", es: "Fecha límite: \(data)", pt: "Prazo final: \(data)", zh: "截止日期: \(data)") }
    public static func afterDeadlineData(_ data: String) -> String { L(en: "Applications closed \(data)", ru: "Прием заявок закрыт \(data)", es: "Inscripciones cerradas \(data)", pt: "Inscrições encerradas \(data)", zh: "申请已截止 \(data)") }
    public static func deadlineDataTime(_ time: String) -> String { L(en: "Closes in \(time)", ru: "Закрывается через \(time)", es: "Cierra en \(time)", pt: "Fecha em \(time)", zh: "\(time)后关闭") }
    public static func currentApplied(_ users: Int) -> String { L(en: "\(users) applied", ru: "\(users) подано заявок", es: "\(users) aplicaron", pt: "\(users) candidaturas", zh: "\(users) 人已申请") }
    public static func allApplied(_ users: Int) -> String { L(en: "\(users) max spots", ru: "Максимум \(users) мест", es: "\(users) plazas máximas", pt: "Máximo \(users) vagas", zh: "最多 \(users) 个名额") }

    // MARK: - Event Applications List

    public static var applicationsList: String { L(en: "Applications list", ru: "Список заявок", es: "Lista de solicitudes", pt: "Lista de candidaturas", zh: "申请列表") }
    public static var pending: String { L(en: "Pending", ru: "В ожидании", es: "Pendiente", pt: "Pendente", zh: "待处理") }
    public static var shortlisted: String { L(en: "Shortlisted", ru: "В шорт-листе", es: "Preseleccionado", pt: "Pré-selecionado", zh: "入围") }
    public static var accepted: String { L(en: "Accepted", ru: "Принято", es: "Aceptado", pt: "Aceito", zh: "已接受") }
    public static var rejected: String { L(en: "Rejected", ru: "Отклонено", es: "Rechazado", pt: "Rejeitado", zh: "已拒绝") }
    public static var noApplicationsYet: String { L(en: "No applications yet", ru: "Пока нет заявок", es: "Aún no hay solicitudes", pt: "Nenhuma candidatura ainda", zh: "暂无申请") }
    public static var eventApplicationsListErrorTitle: String { L(en: "Couldn't load applications list", ru: "Не удалось загрузить список заявок", es: "No se pudo cargar la lista de solicitudes", pt: "Não foi possível carregar a lista de candidaturas", zh: "无法加载申请列表") }
    public static var closed: String { L(en: "Closed", ru: "Закрыто", es: "Cerrado", pt: "Fechado", zh: "已关闭") }

    // MARK: - Event Search
    
    public static var eventsSearchPlaceholder: String { L(en: "Search by name", ru: "Поиск по названию", es: "Buscar por nombre", pt: "Pesquisar por nome", zh: "按名称搜索") }
    public static var eventsSearchTypeEvents: String { L(en: "Type events", ru: "Тип мероприятий", es: "Tipo de eventos", pt: "Tipo de eventos", zh: "活动类型") }
    public static var eventsSearchDateOfEvent: String { L(en: "Date of event", ru: "Дата мероприятия", es: "Fecha del evento", pt: "Data do evento", zh: "活动日期") }
    public static var eventsSearchPaidOnly: String { L(en: "Paid only", ru: "Только платные", es: "Solo de pago", pt: "Apenas pagos", zh: "仅付费") }

    // MARK: - City Search

    public static var citySearchPlaceholder: String { L(en: "Search city", ru: "Поиск города", es: "Buscar ciudad", pt: "Pesquisar cidade", zh: "搜索城市") }
    public static var cityNotFound: String { L(en: "City not found in database", ru: "Город не найден в базе данных", es: "Ciudad no encontrada en la base de datos", pt: "Cidade não encontrada no banco de dados", zh: "数据库中未找到城市") }
    public static var chooseCity: String { L(en: "Choose City", ru: "Выберите город", es: "Elige ciudad", pt: "Escolha cidade", zh: "选择城市") }

    // MARK: - Add Model
    
    public static var addModelTitle: String { L(en: "Add a model to your roster", ru: "Добавить модель в список", es: "Agregar un modelo a tu lista", pt: "Adicionar um modelo à sua lista", zh: "将模特添加到您的名单中") }
    public static var addModelInitialState: String { L(en: "Start typing to search for a model", ru: "Начните вводить текст для поиска модели", es: "Comienza a escribir para buscar un modelo", pt: "Comece a digitar para buscar um modelo", zh: "开始输入以搜索模特") }
    public static var addModelSearchNoFoundTitle: String { L(en: "No Results Found", ru: "Результатов не найдено", es: "No se encontraron resultados", pt: "Nenhum resultado encontrado", zh: "未找到结果") }
    public static var addModelSearchNoFoundSubtitle: String { L(en: "Try a different search query", ru: "Попробуйте другой поисковый запрос", es: "Prueba una consulta de búsqueda diferente", pt: "Tente uma consulta de busca diferente", zh: "尝试不同的搜索词") }
    public static var addModelSearchAlreadyAdded: String { L(en: "Already added", ru: "Уже добавлен", es: "Ya agregado", pt: "Já adicionado", zh: "已添加") }
    public static var addModelConfirm: String { L(en: "Confirm", ru: "Подтвердить", es: "Confirmar", pt: "Confirmar", zh: "确认") }
    public static var addModelNote: String { L(en: "Note: Adding this model to your roster allows your agency to send them exclusive private casting calls, manage their bookings, and officially represent them on Divo.", ru: "Примечание: Добавление этой модели в список позволяет вашему агентству отправлять ей эксклюзивные частные приглашения на кастинги, управлять её бронированиями и официально представлять её на Divo.", es: "Nota: Agregar este modelo a tu lista permite que tu agencia le envíe convocatorias de casting privadas exclusivas, gestione sus reservas y la represente oficialmente en Divo.", pt: "Nota: Adicionar este modelo à sua lista permite que sua agência envie convites exclusivos privados para elenco, gerencie suas reservas e a represente oficialmente no Divo.", zh: "注意：将此模特添加到您的名单中后，您的经纪公司可以向其发送独家私人试镜邀请、管理其预订，并在 Divo 上正式代表该模特。") }
    public static var addModelConfirming: String { L(en: "Confirming...", ru: "Подтверждение...", es: "Confirmando...", pt: "Confirmando...", zh: "确认中...") }
    public static func addModelSuccess(_ name: String) -> String { L(en: "We successfully added \(name) to the agency.", ru: "Мы успешно добавили \(name) в агентство.", es: "Agregamos exitosamente a \(name) a la agencia.", pt: "Adicionamos \(name) à agência com sucesso.", zh: "我们成功将 \(name) 添加到经纪公司。") }
    public static var modelSuccessDelete: String { L(en: "Successfully removed the model from the agency", ru: "Модель успешно удалена из агентства", es: "Modelo eliminado exitosamente de la agencia", pt: "Modelo removido da agência com sucesso", zh: "已成功从经纪公司移除模特") }
    public static func addModelAlertTitle(_ name: String) -> String { L(en: "This model is currently represented by \(name)", ru: "Эта модель в настоящее время представлена агенством \(name)", es: "Este modelo está actualmente representado por \(name)", pt: "Este modelo é atualmente representado por \(name)", zh: "该模特目前由 \(name) 代理") }
    public static var addModelAlertSubtitle: String { L(en: "You cannot add her to your roster while she is with another agency.", ru: "Вы не можете добавить её в свой список, пока она находится в другом агентстве.", es: "No puedes agregarla a tu lista mientras esté con otra agencia.", pt: "Você não pode adicioná-la à sua lista enquanto ela estiver em outra agência.", zh: "她在其他经纪公司期间，您无法将她添加到您的名单中。") }

    // MARK: - Helpers

    private static func pluralRu(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod10 == 1 && mod100 != 11 { return one }
        if mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20) { return few }
        return many
    }
}
