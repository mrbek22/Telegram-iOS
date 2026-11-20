import Foundation

/// AlfaGram's own texts follow the Telegram in-app language (not the iOS system language).
/// The source strings are Uzbek (Latin); English and Russian translations are looked up here.
/// Any other language falls back to English; Uzbek keeps the source (Cyrillic when `cyrillicUi`).
public enum AlfaStrings {
    public enum Lang {
        case uz
        case en
        case ru
    }

    private static let lock = NSLock()
    private static var _languageCode: String = "en"

    /// Set from the presentation strings whenever the Telegram language changes.
    public static var languageCode: String {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _languageCode
        }
        set {
            lock.lock()
            _languageCode = newValue
            lock.unlock()
        }
    }

    public static var lang: Lang {
        let code = languageCode.lowercased()
        if code.hasPrefix("uz") {
            return .uz
        }
        for prefix in ["ru", "uk", "be", "kk", "ky", "tg"] {
            if code.hasPrefix(prefix) {
                return .ru
            }
        }
        return .en
    }

    /// Translation only (no Cyrillic conversion). Unknown strings are returned unchanged.
    public static func tr(_ uz: String) -> String {
        switch lang {
        case .uz:
            return uz
        case .en:
            return table[uz]?.0 ?? uz
        case .ru:
            return table[uz]?.1 ?? uz
        }
    }

    /// Picks one of three explicit variants (for texts built from parts).
    public static func pick(uz: String, en: String, ru: String) -> String {
        switch lang {
        case .uz:
            return uz
        case .en:
            return en
        case .ru:
            return ru
        }
    }

    /// `tr` + replaces `{0}`, `{1}`… with the arguments.
    public static func f(_ uz: String, _ args: String...) -> String {
        var result = tr(uz)
        for (i, arg) in args.enumerated() {
            result = result.replacingOccurrences(of: "{\(i)}", with: arg)
        }
        return result
    }

    private static let table: [String: (String, String)] = [
        // Settings screen
        "XABARLAR": ("MESSAGES", "СООБЩЕНИЯ"),
        "O'chirilgan xabarlarni saqlash": ("Keep deleted messages", "Сохранять удалённые сообщения"),
        "Tahrir tarixini saqlash": ("Keep edit history", "Сохранять историю правок"),
        "Xabar menyusida «ID nusxalash»": ("«Copy ID» in message menu", "«Копировать ID» в меню сообщения"),
        "Suhbatdosh o'chirgan xabar chatda qoladi va vaqti yonida 🗑 belgisi chiqadi. Tahrirlangan xabarni bosib turing → «Tahrir tarixi» — oldingi matnlar.": ("A message deleted by the other person stays in the chat with a 🗑 mark next to its time. Long-press an edited message → «Edit history» to see earlier versions.", "Удалённое собеседником сообщение остаётся в чате с меткой 🗑 рядом со временем. Зажмите изменённое сообщение → «История правок», чтобы увидеть прежние версии."),
        "GHOST REJIM": ("GHOST MODE", "РЕЖИМ ПРИЗРАКА"),
        "Onlayn ko'rinmaslik": ("Hide online status", "Не показывать «в сети»"),
        "«Yozyapti...» ni yubormaslik": ("Don't send «typing…»", "Не отправлять «печатает…»"),
        "O'qilganini bildirmaslik": ("Don't send read receipts", "Не отмечать прочитанным"),
        "Story'larni anonim ko'rish": ("View stories anonymously", "Смотреть истории анонимно"),
        "Yoqilganda boshqalar sizni onlayn, yozayotgan, xabarini yoki story'sini ko'rgan holda ko'rmaydi.": ("When on, others won't see you online, typing, or that you've read their message or viewed their story.", "Если включено, другие не увидят, что вы в сети, печатаете, прочитали их сообщение или посмотрели историю."),
        "KUZATUV": ("TRACKING", "ОТСЛЕЖИВАНИЕ"),
        "Kontaktlar onlayn tarixini yozish": ("Record contacts' online history", "Записывать историю «в сети» контактов"),
        "Onlayn tarixi": ("Online history", "История «в сети»"),
        "Profil o'zgarishlarini yozish": ("Record profile changes", "Записывать изменения профилей"),
        "Profil o'zgarishlari": ("Profile changes", "Изменения профилей"),
        "«Yozdi, yubormadi» jurnali": ("«Typed, didn't send» log", "Журнал «Печатал, но не отправил»"),
        "Yozdi, yubormadi": ("Typed, didn't send", "Печатал, но не отправил"),
        "Kim qachon onlayn bo'lgani, username, rasm yoki raqamini o'zgartirgani va sizga yozib, yubormagani. Hammasi faqat telefoningizda saqlanadi.": ("Who was online and when, who changed their username, photo or number, and who typed to you but didn't send. Everything is stored only on your phone.", "Кто и когда был в сети, кто сменил имя пользователя, фото или номер и кто начал писать вам, но не отправил. Всё хранится только на вашем телефоне."),
        "XAVFSIZLIK": ("SECURITY", "БЕЗОПАСНОСТЬ"),
        "Shubhali havolalardan ogohlantirish": ("Warn about suspicious links", "Предупреждать о подозрительных ссылках"),
        "Telegram reklamalarini yashirish": ("Hide Telegram ads", "Скрывать рекламу Telegram"),
        "Soxta bank, Click, Payme yoki Telegram saytlari, APK yuklovchi va «sovg'a» va'da qiluvchi havolalarni ochishdan oldin ogohlantiradi.": ("Warns before opening fake bank, Click, Payme or Telegram sites, APK downloads and links promising «gifts».", "Предупреждает перед открытием поддельных сайтов банков, Click, Payme или Telegram, загрузок APK и ссылок с обещанием «подарков»."),
        "CHATLAR": ("CHATS", "ЧАТЫ"),
        "Story'lar qatorini yashirish": ("Hide stories row", "Скрыть ряд историй"),
        "Hammasini ovozsiz yuborish": ("Send everything silently", "Отправлять всё без звука"),
        "Ovozsiz yuborilgan xabar qabul qiluvchida tovushsiz keladi. Story qatori chatlar ro'yxatiga qaytganingizda yashiriladi. Dumaloq video tugmasini bosib tursangiz, old yoki orqa kamerani tanlaysiz — yozuv qo'lsiz davom etadi.": ("Silent messages arrive without a sound. The stories row hides when you return to the chat list. Hold the round video button to pick the front or back camera — recording then continues hands-free.", "Беззвучные сообщения приходят без звука. Ряд историй скрывается при возврате к списку чатов. Удерживайте кнопку видеосообщения, чтобы выбрать фронтальную или основную камеру — запись продолжится без рук."),
        "Dumaloq videoda kamerani so'rash": ("Ask camera for round videos", "Спрашивать камеру для видеосообщений"),
        "Dumaloq video qaysi kamerada yozilsin?": ("Which camera for the round video?", "Какой камерой снимать видеосообщение?"),
        "Old kamera (selfi)": ("Front camera (selfie)", "Фронтальная камера (селфи)"),
        "Orqa kamera": ("Back camera", "Основная камера"),

        // Chat lock / hidden accounts
        "MAXFIYLIK": ("PRIVACY", "КОНФИДЕНЦИАЛЬНОСТЬ"),
        "Maxfiy akkauntlar": ("Hidden accounts", "Скрытые аккаунты"),
        "Maxfiy akkauntlarni ochish": ("Open hidden accounts", "Открыть скрытые аккаунты"),
        "Chatni qulflash: chatlar ro'yxatida chatni bosib turing → «Chatni qulflash». Qulflangan chat Face ID yoki telefon paroli bilan ochiladi va xabarlari ro'yxatda ko'rinmaydi.": ("Chat lock: in the chat list, press and hold a chat → «Lock chat». A locked chat opens with Face ID or the phone passcode, and its messages are hidden in the list.", "Блокировка чата: в списке чатов удерживайте чат → «Заблокировать чат». Заблокированный чат открывается по Face ID или коду телефона, а его сообщения скрыты в списке."),
        "Yoqilgan akkaunt «Hisoblar» ro'yxatida va akkaunt almashtirishda ko'rinmaydi. Unga faqat shu yerdan, Face ID yoki parol bilan kirasiz. Bildirishnomalari kelaveradi — kerak bo'lsa, o'sha akkauntda o'chirib qo'ying.": ("A switched-on account is not shown in the accounts list or the account switcher. You reach it only from here, with Face ID or the passcode. Its notifications still arrive — turn them off in that account if needed.", "Включённый аккаунт не виден в списке аккаунтов и при переключении. Войти в него можно только отсюда, по Face ID или коду. Уведомления продолжают приходить — при необходимости отключите их в этом аккаунте."),
        "Kirish": ("Open", "Войти"),
        "Qulflangan chatni ochish": ("Open the locked chat", "Открыть заблокированный чат"),
        "🔒 Qulflangan chat": ("🔒 Locked chat", "🔒 Заблокированный чат"),
        "Chatni qulflash": ("Lock chat", "Заблокировать чат"),
        "Qulfni olib tashlash": ("Unlock chat", "Снять блокировку"),
        "Chat qulfini olib tashlash": ("Remove the chat lock", "Снять блокировку чата"),
        "Chat qulfdan chiqarildi": ("Chat unlocked", "Блокировка чата снята"),
        "Chat qulflandi: ochish uchun Face ID yoki parol so'raladi": ("Chat locked: Face ID or the passcode is needed to open it", "Чат заблокирован: для открытия нужен Face ID или код"),
        "Media hali yuklanmagan": ("The media isn't downloaded yet", "Медиа ещё не загружено"),
        "Hammasini belgilash": ("Select all", "Выбрать все"),
        "Yangi xabar": ("New message", "Новое сообщение"),
        "AlfaGram haqida": ("About AlfaGram", "Об AlfaGram"),
        "Chatni eksport qilish": ("Export chat", "Экспорт чата"),
        "Chatni eksport qilish: oxirgi 5000 tagacha xabar. Formatni tanlang.": ("Export chat: up to the latest 5000 messages. Choose a format.", "Экспорт чата: до 5000 последних сообщений. Выберите формат."),
        "HTML sahifa": ("HTML page", "HTML-страница"),
        "Matn fayl (TXT)": ("Text file (TXT)", "Текстовый файл (TXT)"),
        "Eksport qilish uchun xabar topilmadi.": ("No messages to export.", "Нет сообщений для экспорта."),
        "AlfaGram eksporti": ("AlfaGram export", "Экспорт AlfaGram"),
        "[Rasm]": ("[Photo]", "[Фото]"),
        "[Video]": ("[Video]", "[Видео]"),
        "[Ovozli xabar]": ("[Voice message]", "[Голосовое сообщение]"),
        "[Dumaloq video]": ("[Video message]", "[Видеосообщение]"),
        "[Stiker]": ("[Sticker]", "[Стикер]"),
        "[Fayl]": ("[File]", "[Файл]"),
        "[Xizmat xabari]": ("[Service message]", "[Служебное сообщение]"),
        "[Media]": ("[Media]", "[Медиа]"),
        "Vaqtincha to'xtatish": ("Pause", "Приостановить"),
        "Qayta yoqish": ("Resume", "Возобновить"),
        "Bildirishnoma kelmaydi": ("No notifications", "Без уведомлений"),
        "Bildirishnomalar o'chiq": ("Notifications are off", "Уведомления выключены"),
        "Yashirish": ("Hide", "Скрыть"),
        "Maxfiy akkauntlarga o'tadi": ("Moves to hidden accounts", "Переместится в скрытые"),
        "Har safar so'rash": ("Ask every time", "Спрашивать каждый раз"),
        "Doim old": ("Always front", "Всегда фронтальная"),
        "Doim orqa": ("Always back", "Всегда основная"),
        "Doim old kamera": ("Always the front camera", "Всегда фронтальная камера"),
        "Doim orqa kamera": ("Always the back camera", "Всегда основная камера"),
        "Dumaloq video qaysi kamerada boshlansin?": ("Which camera should round videos start with?", "С какой камеры начинать видеосообщения?"),
        "Bir martalik media o'chmasin": ("Keep self-destructing media", "Не удалять исчезающие медиа"),
        "Bir martalik va soniyali rasm, video, ovoz chatda qoladi": ("View-once and timed photos, videos and voice stay in the chat", "Одноразовые и исчезающие фото, видео и голосовые остаются в чате"),
        "Hikoya qo'shish": ("Add story", "Добавить историю"),
        "QR kodni skanerlash": ("Scan QR code", "Сканировать QR-код"),
        "Asboblar": ("Tools", "Инструменты"),
        "Ko'rinish": ("Appearance", "Оформление"),
        "Keshni tozalash": ("Clear cache", "Очистить кэш"),
        "Ro'yxatning oxiriga o'tish": ("Go to the end of the list", "В конец списка"),

        // AlfaGram settings: one-line explanations under the switches
        "Suhbatdosh o'chirgan xabar sizda 🗑 belgisi bilan qoladi": ("A message the other person deletes stays with you, marked 🗑", "Удалённое собеседником сообщение останется у вас с отметкой 🗑"),
        "Tahrirlangan xabarni bosib turing → «Tahrir tarixi»": ("Press and hold an edited message → «Edit history»", "Удерживайте изменённое сообщение → «История правок»"),
        "Xabarni bosib turganda ID'ni nusxalash bandi": ("A «Copy ID» item when you press and hold a message", "Пункт «Копировать ID» при удержании сообщения"),
        "Hech kim sizni onlayn holatda ko'rmaydi": ("No one sees you online", "Никто не видит вас в сети"),
        "Suhbatdosh siz yozayotganingizni ko'rmaydi": ("Others don't see that you're typing", "Собеседник не видит, что вы печатаете"),
        "Xabarni o'qiganingiz yuboruvchiga bildirilmaydi": ("The sender isn't told you read the message", "Отправитель не узнает, что вы прочитали"),
        "Story muallifi siz ko'rganingizni bilmaydi": ("The author won't know you watched the story", "Автор не узнает, что вы смотрели историю"),
        "Chatlar ro'yxati tepasidagi ko'z belgisi uchala Ghost sozlamasini bir bosishda yoqadi.": ("The eye at the top of the chat list turns all three Ghost settings on with one tap.", "Глаз вверху списка чатов включает все три настройки призрака одним нажатием."),
        "Kim qachon onlayn bo'lgani yozib boriladi": ("Records who was online and when", "Записывается, кто и когда был в сети"),
        "Username, rasm, raqam yoki ism o'zgarishi": ("Username, photo, phone or name changes", "Смена имени пользователя, фото, номера или имени"),
        "Sizga yozib, yubormaganlar": ("Who typed to you but didn't send", "Кто начал писать вам, но не отправил"),
        "Hammasi faqat telefoningizda saqlanadi.": ("Everything is stored only on your phone.", "Всё хранится только на вашем телефоне."),
        "Soxta bank, Click, Payme, Telegram saytlari va APK havolalari": ("Fake bank, Click, Payme, Telegram sites and APK links", "Поддельные сайты банков, Click, Payme, Telegram и ссылки на APK"),
        "Kanallardagi homiylik xabarlari ko'rinmaydi": ("Sponsored messages in channels are hidden", "Спонсорские сообщения в каналах скрыты"),
        "Chatlar ro'yxati tepasidagi story qatori": ("The stories row above the chat list", "Ряд историй над списком чатов"),
        "Xabarlaringiz qabul qiluvchida tovushsiz keladi": ("Your messages arrive without a sound", "Ваши сообщения приходят без звука"),
        "Bosib turganda old yoki orqa kamera so'raladi": ("Holding the button asks: front or back camera", "При удержании спрашивается: фронтальная или основная камера"),
        "Rasm, video va matnni saqlash, skrinshot olish": ("Save photos, videos and text, take screenshots", "Сохранение фото, видео и текста, скриншоты"),
        "O'zbek tili tanlanganda ilova kirillda": ("With Uzbek selected, the app is in Cyrillic", "При выбранном узбекском — интерфейс на кириллице"),
        "Lotincha matn kirillga o'girib yuboriladi": ("Latin text is sent converted to Cyrillic", "Текст латиницей отправляется кириллицей"),

        // What AlfaGram can do (first-launch list)
        "AlfaGram imkoniyatlari": ("What AlfaGram can do", "Возможности AlfaGram"),
        "Tushunarli!": ("Got it!", "Понятно!"),
        "Onlayn ko'rinmasdan o'qing: «yozyapti» va «o'qildi» yuborilmaydi. Chatlar ro'yxati tepasidagi ko'z belgisi bilan bir bosishda yoqing.": ("Read without appearing online: no «typing…» and no read receipts. Turn it on with one tap on the eye at the top of the chat list.", "Читайте, не появляясь в сети: «печатает…» и отметки о прочтении не отправляются. Включается одним нажатием на глаз вверху списка чатов."),
        "O'chirilgan xabarlar qoladi": ("Deleted messages stay", "Удалённые сообщения остаются"),
        "Suhbatdoshingiz xabarni o'chirsa ham, u sizda 🗑 belgisi bilan saqlanib qoladi.": ("Even if the other person deletes a message, it stays with you, marked 🗑.", "Даже если собеседник удалит сообщение, оно останется у вас с отметкой 🗑."),
        "Tahrirlangan xabarni bosib turing → «Tahrir tarixi» — barcha oldingi matnlarni ko'rasiz.": ("Press and hold an edited message → «Edit history» to see every earlier version.", "Удерживайте изменённое сообщение → «История правок» — увидите все прежние версии."),
        "Chat qulfi": ("Chat lock", "Блокировка чатов"),
        "Chatni bosib turing → «Chatni qulflash». U Face ID yoki parol bilan ochiladi, xabarlari ro'yxatda va bildirishnomada ko'rinmaydi.": ("Press and hold a chat → «Lock chat». It opens with Face ID or the passcode, and its messages are hidden in the list and notifications.", "Удерживайте чат → «Заблокировать чат». Он открывается по Face ID или коду, а его сообщения скрыты в списке и уведомлениях."),
        "Story'larni muallifga bildirmasdan ko'ring — bu sukut bo'yicha yoqilgan.": ("Watch stories without the author knowing — on by default.", "Смотрите истории незаметно для автора — включено по умолчанию."),
        "10 ta akkaunt": ("10 accounts", "10 аккаунтов"),
        "10 tagacha akkauntni bitta ilovada ishlating. Keraklisini «Maxfiy akkauntlar»da yashirib qo'ying.": ("Use up to 10 accounts in one app. Hide any of them in «Hidden accounts».", "До 10 аккаунтов в одном приложении. Любой можно спрятать в «Скрытых аккаунтах»."),
        "Dumaloq video kamerasi": ("Round video camera", "Камера для видеосообщений"),
        "Dumaloq video tugmasini bosib turing — old yoki orqa kamerani tanlaysiz, yozuv qo'lsiz davom etadi.": ("Hold the round video button to pick the front or back camera; recording then continues hands-free.", "Удерживайте кнопку видеосообщения — выберите фронтальную или основную камеру, запись продолжится без рук."),
        "Soxta bank, Click, Payme yoki Telegram saytlari va «sovg'a» va'da qiluvchi havolalarni ochishdan oldin ogohlantiramiz.": ("We warn you before opening fake bank, Click, Payme or Telegram sites and links that promise a «gift».", "Предупреждаем перед открытием поддельных сайтов банков, Click, Payme, Telegram и ссылок с «подарками»."),
        "O'zbekcha va kirillcha": ("Uzbek, Latin and Cyrillic", "Узбекский: латиница и кириллица"),
        "Ilova o'zbek tilida, xohlasangiz kirillda. Lotincha yozganingizni kirillda yuborish ham mumkin.": ("The app speaks Uzbek, in Cyrillic too if you like. Text typed in Latin can be sent in Cyrillic.", "Приложение на узбекском, по желанию — кириллицей. Набранное латиницей можно отправлять кириллицей."),
        "Hammasi bir joyda": ("All in one place", "Всё в одном месте"),
        "Barcha imkoniyatlarni Sozlamalar → AlfaGram bo'limida yoqib-o'chirasiz.": ("Turn every feature on or off in Settings → AlfaGram.", "Все функции включаются и выключаются в Настройках → AlfaGram."),
        "Bot token bilan kirish": ("Log in with a bot token", "Войти по токену бота"),
        "Tokenni @BotFather beradi. Bot rejimi cheklangan: chatlar ro'yxati va eski xabarlar ko'rinmaydi, faqat kirgandan keyingi yangi xabarlar keladi.": ("@BotFather gives the token. Bot mode is limited: the chat list and old messages are not shown, only new messages after logging in arrive.", "Токен выдаёт @BotFather. Режим бота ограничен: список чатов и старые сообщения не видны, приходят только новые сообщения после входа."),
        "Serverga ulanish hali tayyor emas. Birozdan keyin qayta urinib ko'ring.": ("Not connected to the server yet. Try again in a moment.", "Подключение к серверу ещё не готово. Попробуйте чуть позже."),
        "Token noto'g'ri. U 123456789:ABCdef... ko'rinishida bo'ladi.": ("Invalid token. It looks like 123456789:ABCdef...", "Неверный токен. Он выглядит как 123456789:ABCdef..."),
        "Token noto'g'ri yoki bekor qilingan.": ("The token is invalid or revoked.", "Токен неверный или отозван."),
        "Urinishlar juda ko'p. Birozdan keyin qayta urinib ko'ring.": ("Too many attempts. Try again later.", "Слишком много попыток. Попробуйте позже."),
        "Kirib bo'lmadi": ("Couldn't log in", "Не удалось войти"),
        "Hammasi": ("All", "Все"),
        "Belgilarni olib tashlash": ("Deselect all", "Снять выделение"),
        "CHEKLOVSIZ": ("NO RESTRICTIONS", "БЕЗ ОГРАНИЧЕНИЙ"),
        "Taqiqlangan chatlardan saqlash": ("Save from restricted chats", "Сохранять из защищённых чатов"),
        "Saqlash va nusxa olish yopilgan chatlarda ham rasm, video va matnni saqlash, skrinshot olish. Forward'ni Telegram serveri baribir bloklashi mumkin.": ("Save photos, videos and text and take screenshots even in chats where saving and copying are disabled. Telegram's server may still block forwarding.", "Сохраняйте фото, видео и текст и делайте скриншоты даже в чатах, где сохранение и копирование запрещены. Пересылку сервер Telegram всё равно может заблокировать."),
        "TIL": ("LANGUAGE", "ЯЗЫК"),
        "Kirill alifbosi (Ўзбекча)": ("Cyrillic script (Ўзбекча)", "Кириллица (Ўзбекча)"),
        "Lotincha yozsam, kirillda yuborilsin": ("Send Uzbek Latin text as Cyrillic", "Отправлять узбекскую латиницу кириллицей"),
        "O'zbek tili tanlangan bo'lsa, ilova kirillda ko'rinadi. Tilni Sozlamalar → Til bo'limidan tanlang.": ("With Uzbek selected, the app is shown in Cyrillic. Choose the language in Settings → Language.", "Если выбран узбекский, приложение отображается кириллицей. Язык выбирается в Настройки → Язык."),
        "HISOBLAR": ("ACCOUNTS", "АККАУНТЫ"),
        "Hisoblar": ("Accounts", "Аккаунты"),
        "Hisob qo'shish": ("Add Account", "Добавить аккаунт"),
        "Joriy hisob": ("Current account", "Текущий аккаунт"),
        "Hisobni almashtirish uchun bosing. 10 tagacha hisob qo'shish mumkin.": ("Tap an account to switch to it. You can add up to 10 accounts.", "Нажмите на аккаунт, чтобы переключиться. Можно добавить до 10 аккаунтов."),

        // Settings / profile entries
        "Mening AlfaGram havolam": ("My AlfaGram link", "Моя ссылка AlfaGram"),
        "Havolani nusxalash": ("Copy link", "Копировать ссылку"),
        "Ulashish": ("Share", "Поделиться"),
        "Kartochka sifatida ulashish": ("Share as a card", "Поделиться карточкой"),
        "QR'ni rasmlarga saqlash": ("Save QR to Photos", "Сохранить QR в Фото"),
        "Shaxsiy havola uchun avval username qo'ying.": ("Set a username first to get your personal link.", "Чтобы получить личную ссылку, сначала задайте имя пользователя."),
        "Username qo'yish": ("Set username", "Задать имя пользователя"),
        "Havola nusxalandi": ("Link copied", "Ссылка скопирована"),
        "Ghost rejim yoqildi: onlayn, «yozyapti» va «o'qildi» yashirin": ("Ghost mode on: online, «typing» and «read» are hidden", "Режим призрака включён: «в сети», «печатает» и «прочитано» скрыты"),
        "Ghost rejim o'chirildi": ("Ghost mode off", "Режим призрака выключен"),
        "Rasmlarga saqlandi": ("Saved to Photos", "Сохранено в Фото"),
        "Yordam guruhi": ("Help group", "Группа поддержки"),
        "Ro'yxatdan o'tgan": ("Registered", "Регистрация"),

        // Chat list tabs
        "Shaxsiy": ("Personal", "Личные"),
        "O'zaro kontaktlar": ("Mutual contacts", "Взаимные контакты"),
        "Guruhlar": ("Groups", "Группы"),
        "Kanallar": ("Channels", "Каналы"),
        "Botlar": ("Bots", "Боты"),
        "O'qilmagan": ("Unread", "Непрочитанные"),

        // Greeting
        "Xayrli tong": ("Good morning", "Доброе утро"),
        "Xayrli kun": ("Good afternoon", "Добрый день"),
        "Xayrli kech": ("Good evening", "Добрый вечер"),
        "Xayrli tun": ("Good night", "Доброй ночи"),

        // Onboarding
        "Ghost rejim": ("Ghost mode", "Режим призрака"),
        "Onlayn ko'rinmasdan o'qing: «yozyapti» va «o'qildi» belgilari yuborilmaydi, story'larni anonim ko'ring. Sozlamalar → AlfaGram.": ("Read without appearing online: «typing» and «read» marks aren't sent, and stories are viewed anonymously. Settings → AlfaGram.", "Читайте, не появляясь в сети: «печатает» и «прочитано» не отправляются, истории смотрятся анонимно. Настройки → AlfaGram."),
        "Hech narsa yo'qolmaydi": ("Nothing disappears", "Ничего не пропадает"),
        "Suhbatdoshingiz xabarni o'chirsa ham, u sizda 🗑 belgisi bilan qoladi. Tahrirlangan xabarning eski matnini ko'rish uchun xabarni bosib turing.": ("Even if the other person deletes a message, it stays with you marked 🗑. Long-press an edited message to see its earlier text.", "Даже если собеседник удалит сообщение, у вас оно останется с меткой 🗑. Зажмите изменённое сообщение, чтобы увидеть прежний текст."),
        "Havola himoyasi": ("Link protection", "Защита от ссылок"),
        "Soxta bank, Click, Payme yoki Telegram saytlari va «sovg'a» va'da qiluvchi havolalarni ochishdan oldin ogohlantiramiz. Hammasi faqat telefoningizda ishlaydi.": ("We warn you before opening fake bank, Click, Payme or Telegram sites and links promising «gifts». Everything works only on your phone.", "Мы предупреждаем перед открытием поддельных сайтов банков, Click, Payme или Telegram и ссылок с обещанием «подарков». Всё работает только на вашем телефоне."),
        "Boshlash": ("Get started", "Начать"),
        "Keyingi": ("Next", "Далее"),

        // Logs
        "Bugun": ("Today", "Сегодня"),
        "Kecha": ("Yesterday", "Вчера"),
        "{0} daq": ("{0} min", "{0} мин"),
        "{0} soat {1} daq": ("{0} h {1} min", "{0} ч {1} мин"),
        "Tarixni tozalash": ("Clear history", "Очистить историю"),
        "Barcha yozuvlar o'chiriladi. Yangilari yozilishda davom etadi.": ("All records will be deleted. New ones will keep being recorded.", "Все записи будут удалены. Новые продолжат записываться."),
        "Tozalash": ("Clear", "Очистить"),
        "Ismini o'zgartirdi: ": ("Changed name: ", "Сменил имя: "),
        "Username qo'ydi: ": ("Set username: ", "Установил имя пользователя: "),
        "Username'ni olib tashladi: ": ("Removed username: ", "Убрал имя пользователя: "),
        "Profil rasmini o'zgartirdi": ("Changed profile photo", "Сменил фото профиля"),
        "Profil rasmini olib tashladi yoki yashirdi": ("Removed or hid profile photo", "Удалил или скрыл фото профиля"),
        "Telefon raqami o'zgardi: ": ("Phone number changed: ", "Сменился номер телефона: "),
        "Hozircha o'zgarish yo'q. Kontaktlaringiz yoki yozishgan odamlaringiz username'ini, profil rasmini yoki raqamini o'zgartirsa, shu yerda ko'rinadi. Ma'lumot faqat telefoningizda saqlanadi.": ("No changes yet. When your contacts or people you chat with change their username, profile photo or number, it will appear here. Data is stored only on your phone.", "Изменений пока нет. Когда ваши контакты или собеседники сменят имя пользователя, фото профиля или номер, это появится здесь. Данные хранятся только на вашем телефоне."),
        "Hozircha yozuv yo'q. Kontaktlaringiz qachon onlayn bo'lgani ilova internetga ulangan paytda yozib boriladi. Ma'lumot faqat telefoningizda saqlanadi.": ("No records yet. When your contacts are online is recorded while the app is connected. Data is stored only on your phone.", "Записей пока нет. Когда контакты в сети, записывается, пока приложение подключено к интернету. Данные хранятся только на вашем телефоне."),
        "KONTAKTLAR": ("CONTACTS", "КОНТАКТЫ"),
        "onlayn": ("online", "в сети"),
        "Bosing — o'sha odam qachon va qancha vaqt onlayn bo'lgani.": ("Tap to see when and for how long that person was online.", "Нажмите, чтобы увидеть, когда и сколько человек был в сети."),
        "Hozircha yozuv yo'q.": ("No records yet.", "Записей пока нет."),
        "hozir": ("now", "сейчас"),
        "Oxirgi marta: ": ("Last time: ", "Последний раз: "),
        "Hozircha yozuv yo'q. Kimdir shaxsiy chatda sizga yozishni boshlab, keyin yubormasa, shu yerda ko'rinadi.": ("No records yet. If someone starts typing to you in a private chat and doesn't send, it will appear here.", "Записей пока нет. Если кто-то начнёт писать вам в личном чате и не отправит, это появится здесь."),
        "Yozdi ({0} soniya), lekin yubormadi": ("Typed ({0} s) but didn't send", "Печатал ({0} с), но не отправил"),

        // Message menu
        "ID nusxalash": ("Copy ID", "Копировать ID"),
        "Lotinga o'girish": ("Convert to Latin", "В латиницу"),
        "Kirillga o'girish": ("Convert to Cyrillic", "В кириллицу"),
        "Lotin alifbosida": ("In Latin script", "Латиницей"),
        "Kirill alifbosida": ("In Cyrillic script", "Кириллицей"),
        "Nusxalash": ("Copy", "Копировать"),
        "Tahrir tarixi": ("Edit history", "История правок"),
        "Hozirgi:": ("Current:", "Сейчас:"),
        "{0} gacha:": ("Before {0}:", "До {0}:"),

        // Link guard
        "⚠️ Shubhali havola": ("⚠️ Suspicious link", "⚠️ Подозрительная ссылка"),
        "Ochmaslik": ("Don't open", "Не открывать"),
        "Baribir ochish": ("Open anyway", "Всё равно открыть"),
        "Havola dastur (APK) yuklab beradi": ("The link downloads an app (APK)", "Ссылка скачивает приложение (APK)"),
        "Manzil boshqa alifbo harflari bilan niqoblangan ({0})": ("The address is disguised with letters from another alphabet ({0})", "Адрес замаскирован буквами другого алфавита ({0})"),
        "Manzil sayt nomi emas, raqamli IP": ("The address is a numeric IP, not a site name", "Адрес — числовой IP, а не имя сайта"),
        "Sayt o'zini «{0}» qilib ko'rsatyapti, lekin rasmiy manzil emas ({1})": ("The site pretends to be «{0}» but isn't its official address ({1})", "Сайт выдаёт себя за «{0}», но это не официальный адрес ({1})"),
        "Sovg'a/bonus/premium va'da qiluvchi shubhali sayt": ("Suspicious site promising a gift/bonus/premium", "Подозрительный сайт, обещающий подарок/бонус/премиум"),
        "\nBunday saytlar Telegram akkauntingiz, karta ma'lumotlaringiz yoki SMS kodingizni o'g'irlashi mumkin. Kodni hech kimga bermang.": ("\nSuch sites can steal your Telegram account, card details or SMS code. Never share your code with anyone.", "\nТакие сайты могут украсть ваш аккаунт Telegram, данные карты или SMS-код. Никому не сообщайте код."),
    ]
}
