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

    // MARK: - Feed Segments

    public static var feedSubscribed: String { L(en: "SUBSCRIBED MODELS", ru: "ПОДПИСКИ", es: "MODELOS SUSCRITOS", pt: "MODELOS INSCRITOS", zh: "已订阅模特") }
    public static var feedAllUsers: String { L(en: "ALL USERS", ru: "ВСЕ ПОЛЬЗОВАТЕЛИ", es: "TODOS LOS USUARIOS", pt: "TODOS OS USUÁRIOS", zh: "所有用户") }
    public static var feedAgencies: String { L(en: "AGENCIES & PRO MEMBERS", ru: "АГЕНТСТВА И PRO", es: "AGENCIAS Y PRO", pt: "AGÊNCIAS E PRO", zh: "经纪公司和专业会员") }
    public static var addStory: String { L(en: "Add Story", ru: "Добавить", es: "Añadir", pt: "Adicionar", zh: "添加动态") }

    // MARK: - Roles

    public static var roleModel: String { L(en: "model", ru: "модель", es: "modelo", pt: "modelo", zh: "模特") }
    public static var roleNewFace: String { L(en: "new face", ru: "новое лицо", es: "cara nueva", pt: "rosto novo", zh: "新面孔") }
    public static var roleAgency: String { L(en: "agency", ru: "агентство", es: "agencia", pt: "agência", zh: "经纪公司") }
    public static var statusModel: String { L(en: "♦️ model", ru: "♦️ модель", es: "♦️ modelo", pt: "♦️ modelo", zh: "♦️ 模特") }

    // MARK: - Profile Edit Menu

    public static var editProfile: String { L(en: "Edit Profile", ru: "Редактировать профиль", es: "Editar perfil", pt: "Editar perfil", zh: "编辑资料") }
    public static var changeBackground: String { L(en: "Change Profile Background", ru: "Сменить фон профиля", es: "Cambiar fondo de perfil", pt: "Alterar fundo do perfil", zh: "更换资料背景") }
    public static var editSocialLinksMenu: String { L(en: "Edit Social Links", ru: "Редактировать ссылки", es: "Editar redes sociales", pt: "Editar redes sociais", zh: "编辑社交链接") }
    public static var manageWorkExperience: String { L(en: "Manage Work Experience", ru: "Управление опытом работы", es: "Gestionar experiencia", pt: "Gerenciar experiência", zh: "管理工作经历") }
    public static var addPhoto: String { L(en: "Add Photo", ru: "Добавить фото", es: "Agregar foto", pt: "Adicionar foto", zh: "添加照片") }
    public static var addVideo: String { L(en: "Add Video", ru: "Добавить видео", es: "Agregar video", pt: "Adicionar vídeo", zh: "添加视频") }

    // MARK: - Profile Counters & Actions

    public static var counterLike: String { L(en: "Like", ru: "Нравится", es: "Me gusta", pt: "Curtir", zh: "喜欢") }
    public static var counterViewed: String { L(en: "Viewed", ru: "Просмотры", es: "Visto", pt: "Visto", zh: "已查看") }
    public static var counterSave: String { L(en: "Save", ru: "Сохранить", es: "Guardar", pt: "Salvar", zh: "收藏") }
    public static var uploadYourPhotos: String { L(en: "Upload your photos", ru: "Загрузите фото", es: "Sube tus fotos", pt: "Envie suas fotos", zh: "上传您的照片") }
    public static var uploadYourVideos: String { L(en: "Upload your videos", ru: "Загрузите видео", es: "Sube tus videos", pt: "Envie seus vídeos", zh: "上传您的视频") }
    public static var noVideosYet: String { L(en: "No videos yet", ru: "Видео пока нет", es: "Sin videos aún", pt: "Sem vídeos ainda", zh: "暂无视频") }
    public static var noChannelsYet: String { L(en: "No channels yet", ru: "Каналов пока нет", es: "Sin canales aún", pt: "Sem canais ainda", zh: "暂无频道") }
    public static var noModelsYet: String { L(en: "No models yet", ru: "Моделей пока нет", es: "Sin modelos aún", pt: "Sem modelos ainda", zh: "暂无模特") }
    public static var noEventsYet: String { L(en: "No events yet", ru: "Событий пока нет", es: "Sin eventos aún", pt: "Sem eventos ainda", zh: "暂无活动") }
    public static var addChannel: String { L(en: "Add channel", ru: "Добавить канал", es: "Agregar canal", pt: "Adicionar canal", zh: "添加频道") }
    public static var addModel: String { L(en: "Add model", ru: "Добавить модель", es: "Agregar modelo", pt: "Adicionar modelo", zh: "添加模特") }
    public static var addEvent: String { L(en: "Add event", ru: "Добавить событие", es: "Agregar evento", pt: "Adicionar evento", zh: "添加活动") }
    public static var uploadingPhotos: String { L(en: "Uploading Photos...", ru: "Загрузка фото...", es: "Subiendo fotos...", pt: "Enviando fotos...", zh: "上传照片中...") }
    public static var uploadingVideos: String { L(en: "Uploading Videos...", ru: "Загрузка видео...", es: "Subiendo videos...", pt: "Enviando vídeos...", zh: "上传视频中...") }
    public static var loadingChannels: String { L(en: "Loading channels...", ru: "Загрузка каналов...", es: "Cargando canales...", pt: "Carregando canais...", zh: "加载频道中...") }
    public static var loadingModels: String { L(en: "Loading models...", ru: "Загрузка моделей...", es: "Cargando modelos...", pt: "Carregando modelos...", zh: "加载模特中...") }
    public static var loadingEvents: String { L(en: "Loading events...", ru: "Загрузка событий...", es: "Cargando eventos...", pt: "Carregando eventos...", zh: "加载活动中...") }
    public static var noName: String { L(en: "No name", ru: "Без имени", es: "Sin nombre", pt: "Sem nome", zh: "无名") }

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
    public static var settingsBannerDescription: String { L(en: "Publish your profile as a model, join castings or add events as agency — be part of the global fashion network.", ru: "Опубликуйте профиль модели, участвуйте в кастингах или добавляйте мероприятия — станьте частью мировой fashion-сети.", es: "Publica tu perfil como modelo, únete a castings o añade eventos como agencia — forma parte de la red global de moda.", pt: "Publique seu perfil como modelo, participe de castings ou adicione eventos como agência — faça parte da rede global de moda.", zh: "发布您的模特资料，参加选角或作为经纪公司添加活动——成为全球时尚网络的一部分。") }
    public static var settingsLearnMore: String { L(en: "LEARN MORE", ru: "УЗНАТЬ БОЛЬШЕ", es: "MÁS INFORMACIÓN", pt: "SAIBA MAIS", zh: "了解更多") }

    // MARK: - Common

    public static var ok: String { L(en: "OK", ru: "OK", es: "OK", pt: "OK", zh: "好的") }
    public static var cancel: String { L(en: "Cancel", ru: "Отмена", es: "Cancelar", pt: "Cancelar", zh: "取消") }
    public static var save: String { L(en: "Save", ru: "Сохранить", es: "Guardar", pt: "Salvar", zh: "保存") }
    public static var nextStep: String { L(en: "Next Step", ru: "Следующий шаг", es: "Siguiente Paso", pt: "Próximo Passo", zh: "下一步") }
    public static var delete: String { L(en: "Delete", ru: "Удалить", es: "Eliminar", pt: "Excluir", zh: "删除") }
    public static var edit: String { L(en: "Edit", ru: "Редактировать", es: "Editar", pt: "Editar", zh: "编辑") }
    public static var error: String { L(en: "Error", ru: "Ошибка", es: "Error", pt: "Erro", zh: "错误") }
    public static var search: String { L(en: "Search", ru: "Поиск", es: "Buscar", pt: "Buscar", zh: "搜索") }
    public static var apply: String { L(en: "Apply", ru: "Подать заявку", es: "Aplicar", pt: "Aplicar", zh: "申请") }
    public static var loading: String { L(en: "Loading...", ru: "Загрузка...", es: "Cargando...", pt: "Carregando...", zh: "加载中...") }
    public static var continueButton: String { L(en: "Continue", ru: "Продолжить", es: "Continuar", pt: "Continuar", zh: "继续") }

    public static func xOfY(_ x: Int, _ y: Int) -> String {
        L(en: "\(x) of \(y)", ru: "\(x) из \(y)", es: "\(x) de \(y)", pt: "\(x) de \(y)", zh: "\(x) / \(y)")
    }

    // MARK: - Profile

    public static var myProfile: String { L(en: "MY PROFILE", ru: "МОЙ ПРОФИЛЬ", es: "MI PERFIL", pt: "MEU PERFIL", zh: "我的个人资料") }
    public static var agencyProfile: String { L(en: "AGENCY PROFILE", ru: "ПРОФИЛЬ АГЕНТСТВА", es: "PERFIL DE AGENCIA", pt: "PERFIL DA AGÊNCIA", zh: "经纪公司资料") }
    public static var noBiography: String { L(en: "No biography", ru: "Нет биографии", es: "Sin biografía", pt: "Sem biografia", zh: "暂无简介") }
    public static var fillInInfoAboutYou: String { L(en: "Fill in the information about you", ru: "Заполните информацию о себе", es: "Complete la información sobre usted", pt: "Preencha as informações sobre você", zh: "请填写您的信息") }
    public static var fillInInfoAboutAgency: String { L(en: "Fill in the information about the agency", ru: "Заполните информацию об агентстве", es: "Complete la información sobre la agencia", pt: "Preencha as informações sobre a agência", zh: "请填写经纪公司信息") }
    public static var biography: String { L(en: "BIOGRAPHY", ru: "БИОГРАФИЯ", es: "BIOGRAFÍA", pt: "BIOGRAFIA", zh: "简介") }
    public static var biographyTitle: String { L(en: "Biography", ru: "Биография", es: "Biografía", pt: "Biografia", zh: "简介") }
    public static var description_: String { L(en: "DESCRIPTION", ru: "ОПИСАНИЕ", es: "DESCRIPCIÓN", pt: "DESCRIÇÃO", zh: "描述") }
    public static var descriptionTitle: String { L(en: "Description", ru: "Описание", es: "Descripción", pt: "Descrição", zh: "描述") }
    public static var appearance: String { L(en: "APPEARANCE", ru: "ВНЕШНОСТЬ", es: "APARIENCIA", pt: "APARÊNCIA", zh: "外貌") }
    public static var seeMore: String { L(en: "SEE MORE", ru: "ПОКАЗАТЬ ЕЩЁ", es: "VER MÁS", pt: "VER MAIS", zh: "查看更多") }
    public static var seeLess: String { L(en: "SEE LESS", ru: "СВЕРНУТЬ", es: "VER MENOS", pt: "VER MENOS", zh: "收起") }
    public static var editLinks: String { L(en: "EDIT LINKS", ru: "РЕД. ССЫЛКИ", es: "EDITAR ENLACES", pt: "EDITAR LINKS", zh: "编辑链接") }
    public static var myLinks: String { L(en: "My Links", ru: "Мои ссылки", es: "Mis enlaces", pt: "Meus links", zh: "我的链接") }
    public static var editSocialLinks: String { L(en: "EDIT SOCIAL LINKS", ru: "РЕДАКТИРОВАТЬ ССЫЛКИ", es: "EDITAR REDES SOCIALES", pt: "EDITAR REDES SOCIAIS", zh: "编辑社交链接") }
    public static var enterYourWebsite: String { L(en: "Enter your website", ru: "Введите ваш сайт", es: "Ingrese su sitio web", pt: "Insira seu site", zh: "输入您的网站") }
    public static var socialLinksUpdated: String { L(en: "Social links updated", ru: "Ссылки обновлены", es: "Enlaces actualizados", pt: "Links atualizados", zh: "社交链接已更新") }
    public static var profileUpdated: String { L(en: "Profile updated", ru: "Профиль обновлён", es: "Perfil actualizado", pt: "Perfil atualizado", zh: "个人资料已更新") }
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
    public static var noLikesYet: String { L(en: "No likes yet.", ru: "Пока нет лайков.", es: "Sin me gusta aún.", pt: "Sem curtidas ainda.", zh: "暂无喜欢。") }
    public static var noLikesSubtitle: String { L(en: "Tap the heart icon to like model you enjoy.", ru: "Нажмите на сердечко, чтобы отметить понравившуюся модель.", es: "Toque el corazón para dar me gusta.", pt: "Toque no coração para curtir o modelo.", zh: "点击心形图标来喜欢模特。") }
    public static var nothingSavedYet: String { L(en: "Nothing saved yet.", ru: "Пока ничего не сохранено.", es: "Nada guardado aún.", pt: "Nada salvo ainda.", zh: "暂无收藏。") }
    public static var nothingSavedSubtitle: String { L(en: "Save model to easily find them later.", ru: "Сохраняйте модели, чтобы легко их находить.", es: "Guarde modelos para encontrarlos fácilmente.", pt: "Salve modelos para encontrá-los facilmente.", zh: "收藏模特以便稍后查找。") }
    public static var noProfileViewedYet: String { L(en: "No profile viewed yet.", ru: "Ещё нет просмотров.", es: "Ningún perfil visto aún.", pt: "Nenhum perfil visualizado.", zh: "暂无浏览记录。") }
    public static var noProfileViewedSubtitle: String { L(en: "Profiles that have been here will be displayed here.", ru: "Здесь будут отображаться просмотренные профили.", es: "Los perfiles visitados se mostrarán aquí.", pt: "Os perfis visualizados serão exibidos aqui.", zh: "浏览过的资料将显示在此处。") }

    // MARK: - Work Experience

    public static var workExperience: String { L(en: "Work experience", ru: "Опыт работы", es: "Experiencia laboral", pt: "Experiência profissional", zh: "工作经历") }
    public static var noWorkExperienceYet: String { L(en: "THERE ARE NO WORK\nEXPERIENCE YET.", ru: "ОПЫТА РАБОТЫ\nПОКА НЕТ.", es: "AÚN NO HAY\nEXPERIENCIA LABORAL.", pt: "AINDA NÃO HÁ\nEXPERIÊNCIA.", zh: "暂无\n工作经历。") }
    public static var noWorkExperienceSubtitle: String { L(en: "Click the button below\nto add your work\nexperience", ru: "Нажмите кнопку ниже,\nчтобы добавить\nопыт работы", es: "Haga clic en el botón\npara agregar su\nexperiencia", pt: "Clique no botão abaixo\npara adicionar sua\nexperiência", zh: "点击下方按钮\n添加您的\n工作经历") }
    public static var addWorkExperience: String { L(en: "Add Work Experience", ru: "Добавить опыт работы", es: "Agregar experiencia", pt: "Adicionar experiência", zh: "添加工作经历") }
    public static var workExperienceInfo: String { L(en: "Work experience info", ru: "Информация об опыте работы", es: "Información de experiencia", pt: "Informações da experiência", zh: "工作经历信息") }
    public static var enterAgencyName: String { L(en: "Enter agency name", ru: "Введите название агентства", es: "Ingrese el nombre de la agencia", pt: "Insira o nome da agência", zh: "输入经纪公司名称") }
    public static var startDate: String { L(en: "Start date", ru: "Дата начала", es: "Fecha de inicio", pt: "Data de início", zh: "开始日期") }
    public static var endDate: String { L(en: "End date", ru: "Дата окончания", es: "Fecha de fin", pt: "Data de término", zh: "结束日期") }
    public static var currentlyWorking: String { L(en: "I am currently working in this role", ru: "Я сейчас работаю на этой позиции", es: "Actualmente trabajo en este puesto", pt: "Estou atualmente nesta função", zh: "我目前在此职位工作") }
    public static var saveChanges: String { L(en: "Save Changes", ru: "Сохранить изменения", es: "Guardar cambios", pt: "Salvar alterações", zh: "保存更改") }
    public static var createNewWorkExperience: String { L(en: "Create New Work Experience", ru: "Создать опыт работы", es: "Crear nueva experiencia", pt: "Criar nova experiência", zh: "创建新工作经历") }
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

    public static var createEvent: String { L(en: "Create event", ru: "Создать мероприятие", es: "Crear evento", pt: "Criar evento", zh: "创建活动") }
    public static var eventInfo: String { L(en: "Event info", ru: "Информация о мероприятии", es: "Información del evento", pt: "Informações do evento", zh: "活动信息") }
    public static var nameEvent: String { L(en: "Name event", ru: "Название мероприятия", es: "Nombre del evento", pt: "Nome do evento", zh: "活动名称") }
    public static var enterNameEvent: String { L(en: "Enter name event", ru: "Введите название", es: "Ingrese el nombre", pt: "Insira o nome", zh: "输入活动名称") }
    public static var aboutEvent: String { L(en: "About event", ru: "О мероприятии", es: "Sobre el evento", pt: "Sobre o evento", zh: "关于活动") }
    public static var eventType: String { L(en: "Event type", ru: "Тип мероприятия", es: "Tipo de evento", pt: "Tipo de evento", zh: "活动类型") }
    public static var chooseEventType: String { L(en: "Choose event type", ru: "Выберите тип", es: "Elija el tipo", pt: "Escolha o tipo", zh: "选择活动类型") }
    public static var eventDate: String { L(en: "Event Date", ru: "Дата мероприятия", es: "Fecha del evento", pt: "Data do evento", zh: "活动日期") }
    public static var eventTime: String { L(en: "Event Time", ru: "Время мероприятия", es: "Hora del evento", pt: "Hora do evento", zh: "活动时间") }
    public static var venueOfEvent: String { L(en: "Venue of the event", ru: "Место проведения", es: "Lugar del evento", pt: "Local do evento", zh: "活动地点") }
    public static var chooseCountry: String { L(en: "Choose a country", ru: "Выберите страну", es: "Elija un país", pt: "Escolha um país", zh: "选择国家") }
    public static var parametersForApplying: String { L(en: "Parameters for Applying", ru: "Параметры для заявки", es: "Parámetros de solicitud", pt: "Parâmetros para candidatura", zh: "申请参数") }
    public static var addParameters: String { L(en: "+ Add parameters", ru: "+ Добавить параметры", es: "+ Agregar parámetros", pt: "+ Adicionar parâmetros", zh: "+ 添加参数") }
    public static var createEventButton: String { L(en: "Create Event", ru: "Создать мероприятие", es: "Crear evento", pt: "Criar evento", zh: "创建活动") }
    public static var pleaseFillAllFields: String { L(en: "Please fill in all fields", ru: "Пожалуйста, заполните все поля", es: "Por favor, complete todos los campos", pt: "Por favor, preencha todos os campos", zh: "请填写所有字段") }
    public static var eventAdded: String { L(en: "Event added", ru: "Мероприятие добавлено", es: "Evento agregado", pt: "Evento adicionado", zh: "活动已添加") }
    public static var casting: String { L(en: "Casting", ru: "Кастинг", es: "Casting", pt: "Casting", zh: "选角") }
    public static var participants: String { L(en: "participants", ru: "участников", es: "participantes", pt: "participantes", zh: "参与者") }
    public static var views: String { L(en: "views", ru: "просмотров", es: "vistas", pt: "visualizações", zh: "浏览") }
    public static var online: String { L(en: "Online", ru: "В сети", es: "En línea", pt: "Online", zh: "在线") }
    public static var organizer: String { L(en: "Organizer", ru: "Организатор", es: "Organizador", pt: "Organizador", zh: "组织者") }
    public static var about: String { L(en: "About", ru: "О мероприятии", es: "Acerca de", pt: "Sobre", zh: "关于") }
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
    public static var serverUnavailable: String { L(en: "Server Unavailable", ru: "Сервер недоступен", es: "Servidor no disponible", pt: "Servidor indisponível", zh: "服务器不可用") }
    public static var serverUnavailableSubtitle: String { L(en: "Unable to connect to the server.\nTry toggling your VPN on or off.", ru: "Не удалось подключиться к серверу.\nПопробуйте включить или выключить VPN.", es: "No se pudo conectar al servidor.\nIntente activar o desactivar su VPN.", pt: "Não foi possível conectar ao servidor.\nTente ativar ou desativar a VPN.", zh: "无法连接到服务器。\n请尝试开启或关闭VPN。") }
    public static var noSubscriptionsYet: String { L(en: "No Subscriptions Yet", ru: "Пока нет подписок", es: "Sin suscripciones aún", pt: "Sem inscrições ainda", zh: "暂无订阅") }
    public static var noSubscriptionsSubtitle: String { L(en: "Subscribe to models to see\nthem here.", ru: "Подпишитесь на модели,\nчтобы видеть их здесь.", es: "Suscríbase a modelos\npara verlos aquí.", pt: "Inscreva-se em modelos\npara vê-los aqui.", zh: "订阅模特\n即可在此查看。") }
    public static var noResults: String { L(en: "No Results", ru: "Нет результатов", es: "Sin resultados", pt: "Sem resultados", zh: "无结果") }
    public static var noResultsSubtitle: String { L(en: "No agencies or pro members\nfound at the moment.", ru: "Агентства и модели\nне найдены.", es: "No se encontraron agencias\nni miembros pro.", pt: "Nenhuma agência ou membro\npro encontrado.", zh: "暂未找到经纪公司\n或专业会员。") }
    public static var noUsersFound: String { L(en: "No Users Found", ru: "Пользователи не найдены", es: "No se encontraron usuarios", pt: "Nenhum usuário encontrado", zh: "未找到用户") }
    public static var noUsersFoundSubtitle: String { L(en: "There are no users\nto display right now.", ru: "Сейчас нет пользователей\nдля отображения.", es: "No hay usuarios\npara mostrar ahora.", pt: "Não há usuários\npara exibir agora.", zh: "当前没有\n可显示的用户。") }
    public static var sendDM: String { L(en: "Send DM", ru: "Написать", es: "Enviar MD", pt: "Enviar MD", zh: "发私信") }
    public static var goToMyProfile: String { L(en: "Go to my profile", ru: "Перейти в мой профиль", es: "Ir a mi perfil", pt: "Ir para meu perfil", zh: "前往我的资料") }

    // MARK: - Onboarding

    public static var onboardingTitle1: String { L(en: "STEP INTO THE FASHION WORLD", ru: "ВОЙДИ В МИР МОДЫ", es: "ENTRA EN EL MUNDO DE LA MODA", pt: "ENTRE NO MUNDO DA MODA", zh: "踏入时尚世界") }
    public static var onboardingTitle2: String { L(en: "FROM SELFIE TO SPOTLIGHT", ru: "ОТ СЕЛФИ ДО ПОДИУМА", es: "DEL SELFIE AL ESCENARIO", pt: "DE SELFIE AO PALCO", zh: "从自拍到聚光灯") }
    public static var onboardingTitle3: String { L(en: "WHERE NEW MODELS ARE BORN", ru: "ГДЕ РОЖДАЮТСЯ НОВЫЕ МОДЕЛИ", es: "DONDE NACEN NUEVOS MODELOS", pt: "ONDE NOVOS MODELOS NASCEM", zh: "新模特诞生之地") }
    
    // MARK: - Add Model Agency

    public static var linkModel: String { L(en: "Link on profile in Divo", ru: "Ссылка на профиль в Divo", es: "Enlace en el perfil en Divo", pt: "Link no perfil em Divo", zh: "Divo个人资料连结") }
    public static var titleAddModel: String { L(en: "ADD A NEW MODEL", ru: "ДОБАВЬТЕ НОВУЮ МОДЕЛЬ", es: "AGREGAR UN NUEVO MODELO", pt: "ADICIONAR UM NOVO MODELO", zh: "添加新模型") }
    public static var subTitleAddModel: String { L(en: "Fill out the model's details to add\nthem to your agency. You can\nupdate this information anytime.", ru: "Заполните данные модели, чтобы добавить\nих в свое агентство. Вы можете\nобновить эту информацию в любое время.", es: "Complete los detalles del modelo para agregarlos\na su agencia. Puede\nactualizar esta información en cualquier momento.", pt: "Preencha os detalhes do modelo para adicionar\nà sua agência. Você pode\natualizar essas informações a qualquer momento.", zh: "填写模型的详细信息以将\n添加到您的代理机构。您可以随时\n更新此信息。") }
    public static var parametersAddModel: String { L(en: "Your parameters", ru: "Ваши параметры", es: "Sus parámetros", pt: "Os seus parâmetros", zh: "您的参数") }
    public static var emptyTitleAddModel: String { L(en: "THERE ARE NO MODELS\nFROM YOUR AGENCY YET.", ru: "ТЕКУЩИХ МОДЕЛЕЙ\nОТ ВАШЕГО АГЕНТСТВА ПОКА НЕТ.", es: "NO HAY MODELOS\nDE SU AGENCIA TODAVÍA.", pt: "AINDA NÃO HÁ MODELOS\nDA SUA AGÊNCIA.", zh: "目前还没有\n贵机构的模特。") }
    public static var emptySubTitleAddModel: String { L(en: "Click the button below\nto add your model", ru: "НАЖМИТЕ КНОПКУ НИЖЕ,\nЧТОБЫ ДОБАВИТЬ МОДЕЛЬ", es: "Haz clic en el botón de abajo\npara añadir tu modelo", pt: "Clique no botão abaixo\npara adicionar seu modelo", zh: "点击下方按钮\n添加您的模特") }

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

    // MARK: - Helpers

    private static func pluralRu(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod10 == 1 && mod100 != 11 { return one }
        if mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20) { return few }
        return many
    }
}
