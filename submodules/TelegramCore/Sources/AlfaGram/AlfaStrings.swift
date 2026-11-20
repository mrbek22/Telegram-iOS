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
