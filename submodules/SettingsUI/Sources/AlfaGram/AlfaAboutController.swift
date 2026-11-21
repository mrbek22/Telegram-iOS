import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext

/// AlfaGram: «About AlfaGram» — every feature with its icon and how to turn it on, how it works and how to turn it off.
/// Keep it current: each new feature gets an entry here in the same build.
private struct AlfaText {
    let uz: String
    let en: String
    let ru: String

    var value: String {
        return AlfaCyrillic.ui(AlfaStrings.pick(uz: self.uz, en: self.en, ru: self.ru))
    }
}

private struct AlfaAboutFeature {
    let symbol: String
    let color: UInt32
    let title: AlfaText
    let enable: AlfaText
    let how: AlfaText
    let disable: AlfaText?
}

private func alfaAboutFeatures() -> [AlfaAboutFeature] {
    return [
    AlfaAboutFeature(symbol: "textformat.abc", color: 0x34c759,
        title: AlfaText(uz: "Yangi alifbo (Ş Ç Ö Ğ)", en: "New Uzbek alphabet (Ş Ç Ö Ğ)", ru: "Новый узбекский алфавит (Ş Ç Ö Ğ)"),
        enable: AlfaText(uz: "Sozlamalar → AlfaGram → «Yangi alifbo» (ilova matnlari) va «Yangi alifboda yuborilsin» (xabarlar).", en: "Settings → AlfaGram → «New alphabet» (the app's texts) and «Send in the new alphabet» (messages).", ru: "Настройки → AlfaGram → «Новый алфавит» (тексты приложения) и «Отправлять на новом алфавите» (сообщения)."),
        how: AlfaText(uz: "sh, ch, o', g' → ş, ç, ö, ğ. Siz odatdagidek yozasiz, xabar yangi alifboda ketadi. Havola, @username va teglar o'zgarmaydi. Kirill bilan bir vaqtda faqat bittasi yoqiladi.", en: "sh, ch, o', g' → ş, ç, ö, ğ. You type as usual; the message goes in the new alphabet. Links, @usernames and tags stay as they are. Only one of Cyrillic and the new alphabet is on at a time.", ru: "sh, ch, o', g' → ş, ç, ö, ğ. Вы пишете как обычно, сообщение уходит на новом алфавите. Ссылки, @username и теги не меняются. Кириллица и новый алфавит — только что-то одно."),
        disable: AlfaText(uz: "O'sha bandlarni o'chiring.", en: "Turn those switches off.", ru: "Выключите эти переключатели.")),
    AlfaAboutFeature(symbol: "eye.slash.fill", color: 0xaf52de,
        title: AlfaText(uz: "Yashirin chatlar", en: "Hidden chats", ru: "Скрытые чаты"),
        enable: AlfaText(uz: "Sozlamalar → AlfaGram → «Yashirin chatlar»: qulf turini (4 raqamli PIN yoki parol) tanlab kod qo'ying. Keyin chatni bosib turing → «Chatni yashirish».", en: "Settings → AlfaGram → «Hidden chats»: pick the lock type (a 4-digit PIN or a password) and set the code. Then hold a chat → «Hide chat».", ru: "Настройки → AlfaGram → «Скрытые чаты»: выберите тип блокировки (4-значный PIN или пароль) и задайте код. Затем удерживайте чат → «Скрыть чат»."),
        how: AlfaText(uz: "Yashirilgan chat ro'yxatdan va uzatish oynasidan yo'qoladi, ovozsiz bo'ladi, bildirishnoma kelmaydi. Ko'rish uchun «Chatlar» sarlavhasini bosib turing va kodni kiriting; ilovadan chiqsangiz, yana yashirinadi.", en: "A hidden chat disappears from the list and the forward picker, is muted and sends no notifications. To see it, hold the «Chats» title and enter the code; leaving the app hides it again.", ru: "Скрытый чат исчезает из списка и окна пересылки, без звука и уведомлений. Чтобы увидеть, удерживайте заголовок «Чаты» и введите код; после выхода из приложения он снова скрыт."),
        disable: AlfaText(uz: "Chatni bosib turing → «Yashirishdan chiqarish», yoki sozlamada kod bilan «O'chirish».", en: "Hold the chat → «Unhide», or turn it off in the settings with the code.", ru: "Удерживайте чат → «Не скрывать» или выключите в настройках с кодом.")),
    AlfaAboutFeature(symbol: "eye.slash.fill", color: 0x8e8e93,
        title: AlfaText(uz: "Ghost rejim", en: "Ghost Mode", ru: "Режим призрака"),
        enable: AlfaText(uz: "Chatlar ro'yxati tepasidagi ko'z belgisini bosing yoki Sozlamalar → AlfaGram → Ghost rejim bo'limida kerakli bandlarni yoqing.", en: "Tap the eye at the top of the chat list, or turn on the switches in Settings → AlfaGram → Ghost Mode.", ru: "Нажмите на глаз вверху списка чатов или включите переключатели в Настройки → AlfaGram → Режим призрака."),
        how: AlfaText(uz: "Siz xabarlarni o'qiysiz, lekin suhbatdoshga «o'qildi», «yozyapti...» va «onlayn» belgilari bormaydi.", en: "You read messages, but the other side gets no read receipts, no «typing…» and no «online».", ru: "Вы читаете сообщения, но собеседник не получает отметок о прочтении, «печатает…» и «в сети»."),
        disable: AlfaText(uz: "Ko'z belgisini qayta bosing yoki o'sha bandlarni o'chiring.", en: "Tap the eye again or turn the same switches off.", ru: "Нажмите на глаз ещё раз или выключите те же переключатели.")),
    AlfaAboutFeature(symbol: "trash.fill", color: 0xff3b30,
        title: AlfaText(uz: "O'chirilgan xabarlar", en: "Deleted messages", ru: "Удалённые сообщения"),
        enable: AlfaText(uz: "Sozlamalar → AlfaGram → «O'chirilgan xabarlarni saqlash» (sukut bo'yicha yoqilgan).", en: "Settings → AlfaGram → «Keep deleted messages» (on by default).", ru: "Настройки → AlfaGram → «Сохранять удалённые сообщения» (включено по умолчанию)."),
        how: AlfaText(uz: "Suhbatdosh xabarni o'chirsa ham, u sizning chatingizda qoladi va vaqti yonida 🗑 belgisi chiqadi.", en: "When the other person deletes a message, it stays in your chat with 🗑 next to the time.", ru: "Если собеседник удалит сообщение, оно останется у вас с 🗑 рядом со временем."),
        disable: AlfaText(uz: "O'sha bandni o'chiring.", en: "Turn the same switch off.", ru: "Выключите тот же переключатель.")),
    AlfaAboutFeature(symbol: "clock.arrow.circlepath", color: 0x30b8a8,
        title: AlfaText(uz: "Tahrir tarixi", en: "Edit history", ru: "История правок"),
        enable: AlfaText(uz: "Sozlamalar → AlfaGram → «Tahrir tarixini saqlash» (sukut bo'yicha yoqilgan).", en: "Settings → AlfaGram → «Keep edit history» (on by default).", ru: "Настройки → AlfaGram → «Сохранять историю правок» (включено по умолчанию)."),
        how: AlfaText(uz: "Tahrirlangan xabarni bosib turing → «Tahrir tarixi»: barcha oldingi matnlari ko'rinadi.", en: "Press and hold an edited message → «Edit history» to see every earlier version.", ru: "Удерживайте изменённое сообщение → «История правок» — видны все прежние версии."),
        disable: nil),
    AlfaAboutFeature(symbol: "play.circle.fill", color: 0x5856d6,
        title: AlfaText(uz: "Story'larni anonim ko'rish", en: "Anonymous stories", ru: "Анонимные истории"),
        enable: AlfaText(uz: "Sukut bo'yicha yoqilgan: Sozlamalar → AlfaGram → Ghost rejim → «Story'larni anonim ko'rish».", en: "On by default: Settings → AlfaGram → Ghost Mode → «View stories anonymously».", ru: "Включено по умолчанию: Настройки → AlfaGram → Режим призрака → «Смотреть истории анонимно»."),
        how: AlfaText(uz: "Story muallifi siz ko'rganingizni bilmaydi — ko'rganlar ro'yxatida chiqmaysiz.", en: "The author doesn't learn you watched — you're not in the viewers list.", ru: "Автор не узнает, что вы смотрели, — вас нет в списке зрителей."),
        disable: nil),
    AlfaAboutFeature(symbol: "lock.fill", color: 0x007aff,
        title: AlfaText(uz: "Chat qulfi", en: "Chat lock", ru: "Блокировка чатов"),
        enable: AlfaText(uz: "Chatlar ro'yxatida chatni bosib turing → «Chatni qulflash».", en: "In the chat list, press and hold a chat → «Lock chat».", ru: "В списке чатов удерживайте чат → «Заблокировать чат»."),
        how: AlfaText(uz: "Chat Face ID yoki telefon paroli bilan ochiladi. Ro'yxatda, bosib turgandagi oldindan ko'rishda va bildirishnomada xabarlar ko'rinmaydi. Ilovadan chiqsangiz, yana qulflanadi.", en: "The chat opens with Face ID or the phone passcode. Its messages are hidden in the list, in the long-press preview and in notifications. It locks again when you leave the app.", ru: "Чат открывается по Face ID или коду телефона. Сообщения скрыты в списке, в предпросмотре при удержании и в уведомлениях. После выхода из приложения чат снова блокируется."),
        disable: AlfaText(uz: "Chatni bosib turing → «Qulfni olib tashlash» (Face ID so'raladi).", en: "Press and hold the chat → «Unlock chat» (asks for Face ID).", ru: "Удерживайте чат → «Снять блокировку» (потребуется Face ID).")),
    AlfaAboutFeature(symbol: "person.crop.circle.badge.xmark", color: 0x007aff,
        title: AlfaText(uz: "Maxfiy akkauntlar", en: "Hidden accounts", ru: "Скрытые аккаунты"),
        enable: AlfaText(uz: "Sozlamalardagi akkauntni bosib turing → «Yashirish», yoki Sozlamalar → AlfaGram → «Maxfiy akkauntlar» (Face ID bilan) → akkauntni yoqing.", en: "Press and hold the account in Settings → «Hide», or Settings → AlfaGram → «Hidden accounts» (with Face ID) → switch the account on.", ru: "Удерживайте аккаунт в Настройках → «Скрыть», или Настройки → AlfaGram → «Скрытые аккаунты» (по Face ID) → включите аккаунт."),
        how: AlfaText(uz: "Akkaunt «Hisoblar» ro'yxatida va almashtirishda ko'rinmaydi, bildirishnomalari chiqmaydi. Unga faqat shu bo'limdan kirasiz.", en: "The account disappears from the accounts list and the switcher, and its notifications aren't shown. You open it only from that section.", ru: "Аккаунт не виден в списке и переключателе, его уведомления не показываются. Войти в него можно только из этого раздела."),
        disable: AlfaText(uz: "O'sha bo'limda akkauntni o'chiring.", en: "Switch the account off in the same section.", ru: "Выключите аккаунт в том же разделе.")),
    AlfaAboutFeature(symbol: "pause.circle.fill", color: 0xff9500,
        title: AlfaText(uz: "Akkauntni vaqtincha to'xtatish", en: "Pause an account", ru: "Приостановка аккаунта"),
        enable: AlfaText(uz: "Sozlamalardagi akkauntlar ro'yxatida akkauntni bosib turing → «Vaqtincha to'xtatish».", en: "Press and hold the account in the Settings accounts list → «Pause».", ru: "Удерживайте аккаунт в списке аккаунтов в Настройках → «Приостановить»."),
        how: AlfaText(uz: "Bu akkauntdan hech qanday bildirishnoma kelmaydi — go'yo bu telefonda kirilmagandek.", en: "No notifications at all come from this account — as if it weren't logged in on this phone.", ru: "Уведомления от этого аккаунта не приходят вовсе — будто он не вошёл на этом телефоне."),
        disable: AlfaText(uz: "Akkauntni yana bosib turing → «Qayta yoqish».", en: "Press and hold the account again → «Resume».", ru: "Снова удерживайте аккаунт → «Возобновить».")),
    AlfaAboutFeature(symbol: "person.2.fill", color: 0x007aff,
        title: AlfaText(uz: "10 ta akkaunt", en: "10 accounts", ru: "10 аккаунтов"),
        enable: AlfaText(uz: "Sozlamalar → «Akkaunt qo'shish».", en: "Settings → «Add Account».", ru: "Настройки → «Добавить аккаунт»."),
        how: AlfaText(uz: "Bitta ilovada 10 tagacha Telegram akkaunti. Ular orasida Sozlamalar tugmasini bosib turib almashasiz.", en: "Up to 10 Telegram accounts in one app. Switch by pressing and holding the Settings tab.", ru: "До 10 аккаунтов Telegram в одном приложении. Переключайтесь, удерживая вкладку «Настройки»."),
        disable: nil),
    AlfaAboutFeature(symbol: "Chat List/Filters/Bot", color: 0x5856d6,
        title: AlfaText(uz: "Bot token bilan kirish", en: "Log in with a bot token", ru: "Вход по токену бота"),
        enable: AlfaText(uz: "Kirish ekranida (telefon raqami so'raladigan joy) o'ng tepadagi robot tugmasini bosing va @BotFather bergan tokenni kiriting.", en: "On the login screen (where the phone number is asked), tap the robot at the top right and enter the token from @BotFather.", ru: "На экране входа (где спрашивают номер) нажмите робота справа вверху и введите токен от @BotFather."),
        how: AlfaText(uz: "Ilova bot nomidan ochiladi. Telegram botlarga eski chatlar va tarixni bermaydi — faqat kirgandan keyingi yangi xabarlar keladi.", en: "The app opens as the bot. Telegram gives bots no old chats or history — only new messages after logging in.", ru: "Приложение открывается от имени бота. Telegram не даёт ботам старые чаты и историю — только новые сообщения после входа."),
        disable: AlfaText(uz: "Bot akkauntidan chiqing: Sozlamalar → Tahrirlash → Chiqish.", en: "Log out of the bot account: Settings → Edit → Log Out.", ru: "Выйдите из аккаунта бота: Настройки → Изменить → Выйти.")),
    AlfaAboutFeature(symbol: "clock.fill", color: 0x34c759,
        title: AlfaText(uz: "Kuzatuv", en: "Tracking", ru: "Отслеживание"),
        enable: AlfaText(uz: "Sozlamalar → AlfaGram → Kuzatuv: onlayn tarixi, profil o'zgarishlari, «Yozdi, yubormadi».", en: "Settings → AlfaGram → Tracking: online history, profile changes, «Typed, didn't send».", ru: "Настройки → AlfaGram → Отслеживание: история онлайна, изменения профиля, «Писал, не отправил»."),
        how: AlfaText(uz: "Kontaktlar qachon onlayn bo'lgani, username, rasm, raqam yoki ismini o'zgartirgani va sizga yozib yubormagani yozib boriladi. Hammasi faqat telefoningizda.", en: "Records when contacts were online, changed their username, photo, phone or name, and typed to you without sending. All stays on your phone.", ru: "Записывается, когда контакты были в сети, меняли имя пользователя, фото, номер или имя и писали вам, не отправив. Всё хранится только на телефоне."),
        disable: AlfaText(uz: "O'sha bandlarni o'chiring.", en: "Turn the same switches off.", ru: "Выключите те же переключатели.")),
    AlfaAboutFeature(symbol: "checkmark.shield.fill", color: 0x007aff,
        title: AlfaText(uz: "Havola himoyasi", en: "Link protection", ru: "Защита от ссылок"),
        enable: AlfaText(uz: "Sukut bo'yicha yoqilgan: Sozlamalar → AlfaGram → Xavfsizlik.", en: "On by default: Settings → AlfaGram → Security.", ru: "Включено по умолчанию: Настройки → AlfaGram → Безопасность."),
        how: AlfaText(uz: "Soxta bank, Click, Payme yoki Telegram saytlari, APK yuklovchi va «sovg'a» va'da qiluvchi havolalarni ochishdan oldin ogohlantiradi.", en: "Warns before opening fake bank, Click, Payme or Telegram sites, APK downloads and «gift» links.", ru: "Предупреждает перед открытием поддельных сайтов банков, Click, Payme, Telegram, загрузок APK и ссылок с «подарками»."),
        disable: AlfaText(uz: "«Shubhali havolalardan ogohlantirish»ni o'chiring.", en: "Turn «Warn about suspicious links» off.", ru: "Выключите «Предупреждать о подозрительных ссылках».")),
    AlfaAboutFeature(symbol: "nosign", color: 0xff3b30,
        title: AlfaText(uz: "Reklamasiz kanallar", en: "No channel ads", ru: "Каналы без рекламы"),
        enable: AlfaText(uz: "Sukut bo'yicha yoqilgan: Sozlamalar → AlfaGram → «Telegram reklamalarini yashirish».", en: "On by default: Settings → AlfaGram → «Hide Telegram ads».", ru: "Включено по умолчанию: Настройки → AlfaGram → «Скрывать рекламу Telegram»."),
        how: AlfaText(uz: "Kanallardagi homiylik (reklama) xabarlari yuklanmaydi.", en: "Sponsored messages in channels aren't loaded.", ru: "Спонсорские сообщения в каналах не загружаются."),
        disable: nil),
    AlfaAboutFeature(symbol: "square.grid.2x2.fill", color: 0xff9500,
        title: AlfaText(uz: "Avtomatik tablar", en: "Automatic tabs", ru: "Автоматические вкладки"),
        enable: AlfaText(uz: "O'zingiz papka yaratmagan bo'lsangiz, o'zi chiqadi.", en: "Shown automatically while you have no folders of your own.", ru: "Появляются сами, пока у вас нет своих папок."),
        how: AlfaText(uz: "«Barchasi» yonida to'rt tab: odamlar, guruhlar, kanallar va botlar — asosiy ro'yxatda ham, arxivda ham.", en: "Next to «All» there are four tabs: people, groups, channels and bots — in the main list and in the archive.", ru: "Рядом с «Все» четыре вкладки: люди, группы, каналы и боты — и в основном списке, и в архиве."),
        disable: AlfaText(uz: "O'zingizning papkangizni yarating — shunda sizning papkalaringiz ko'rinadi.", en: "Create a folder of your own — then your folders are shown.", ru: "Создайте свою папку — тогда будут показаны ваши папки.")),
    AlfaAboutFeature(symbol: "person.3.fill", color: 0x007aff,
        title: AlfaText(uz: "Kontaktlardan guruh va kanal", en: "Groups and channels from Contacts", ru: "Группы и каналы из контактов"),
        enable: AlfaText(uz: "Kontaktlar tabining tepasidagi «Yangi guruh» yoki «Yangi kanal» qatorini bosing.", en: "Tap «New Group» or «New Channel» at the top of the Contacts tab.", ru: "Нажмите «Новая группа» или «Новый канал» вверху вкладки «Контакты»."),
        how: AlfaText(uz: "Guruh uchun a'zolarni tanlab, nom berasiz; kanal uchun nom va tavsif kiritasiz — «Yangi xabar» ichiga kirmasdan.", en: "For a group pick the members and a name; for a channel enter a name and description — without going through «New Message».", ru: "Для группы выберите участников и название, для канала — название и описание, не заходя в «Новое сообщение»."),
        disable: nil),
    AlfaAboutFeature(symbol: "square.and.arrow.up.fill", color: 0x30b8a8,
        title: AlfaText(uz: "Chatni eksport qilish", en: "Export chat", ru: "Экспорт чата"),
        enable: AlfaText(uz: "Chat ichida tepadagi avatarni bosing → «Chatni eksport qilish».", en: "In a chat, tap the avatar at the top → «Export chat».", ru: "В чате нажмите на аватар вверху → «Экспорт чата»."),
        how: AlfaText(uz: "Oxirgi 5000 tagacha xabar HTML sahifa yoki TXT fayl bo'lib tayyorlanadi; uni Fayllarga saqlaysiz yoki istalgan chatga yuborasiz.", en: "Up to the latest 5000 messages become an HTML page or a TXT file — save it to Files or send it to any chat.", ru: "До 5000 последних сообщений сохраняются в HTML-страницу или TXT-файл — сохраните в Файлы или отправьте в любой чат."),
        disable: nil),
    AlfaAboutFeature(symbol: "arrow.up.to.line.circle.fill", color: 0x5856d6,
        title: AlfaText(uz: "Boshiga o'tish", en: "Go to the beginning", ru: "В начало чата"),
        enable: AlfaText(uz: "Profil yoki kanal sahifasida ⋯ «yana» → «Boshiga o'tish».", en: "On a profile or channel page, ⋯ More → «Go to the beginning».", ru: "На странице профиля или канала ⋯ «Ещё» → «В начало чата»."),
        how: AlfaText(uz: "Chat yoki kanal eng birinchi xabaridan ochiladi — uzoq tepaga surish shart emas.", en: "The chat or channel opens at its very first message — no endless scrolling up.", ru: "Чат или канал открывается с самого первого сообщения — без долгой прокрутки вверх."),
        disable: nil),
    AlfaAboutFeature(symbol: "photo.on.rectangle.angled", color: 0xff9500,
        title: AlfaText(uz: "Rasmlar va videolar alohida", en: "Photos and videos apart", ru: "Фото и видео отдельно"),
        enable: AlfaText(uz: "O'zi ishlaydi: profil yoki kanal sahifasining pastidagi tablar.", en: "Always on: the tabs at the bottom of a profile or channel page.", ru: "Работает само: вкладки внизу страницы профиля или канала."),
        how: AlfaText(uz: "«Media» o'rniga ikkita tab: «Rasmlar» — faqat rasmlar, «Videolar» — faqat videolar.", en: "Instead of «Media» there are two tabs: «Photos» with photos only and «Videos» with videos only.", ru: "Вместо «Медиа» две вкладки: «Фото» — только фото, «Видео» — только видео."),
        disable: nil),
    AlfaAboutFeature(symbol: "text.bubble.fill", color: 0xff9500,
        title: AlfaText(uz: "Yozdi, yubormadi — profilda", en: "Typed, didn't send — in the profile", ru: "Писал, не отправил — в профиле"),
        enable: AlfaText(uz: "Sozlamalar → AlfaGram → «Yozdi, yubormadi» jurnalini yoqing; keyin odamning profilida ⋯ «yana» → «Yozdi, yubormadi».", en: "Turn on Settings → AlfaGram → «Typed, didn't send»; then in a person's profile ⋯ More → «Typed, didn't send».", ru: "Включите Настройки → AlfaGram → «Писал, не отправил»; затем в профиле человека ⋯ «Ещё» → «Писал, не отправил»."),
        how: AlfaText(uz: "Faqat shu odam sizga yozishni boshlab, yubormagan paytlari ko'rinadi.", en: "Shows only the times this person started typing to you and didn't send.", ru: "Видно только, когда этот человек начинал писать вам и не отправлял."),
        disable: nil),
    AlfaAboutFeature(symbol: "phone.fill", color: 0x34c759,
        title: AlfaText(uz: "Qo'ng'iroqdan oldin so'rash", en: "Confirm before calling", ru: "Подтверждение звонка"),
        enable: AlfaText(uz: "Sukut bo'yicha yoqilgan: Sozlamalar → AlfaGram → «Qo'ng'iroqdan oldin so'rash».", en: "On by default: Settings → AlfaGram → «Confirm before calling».", ru: "Включено по умолчанию: Настройки → AlfaGram → «Подтверждать звонок»."),
        how: AlfaText(uz: "Qo'ng'iroq yoki video qo'ng'iroq tugmasini bossangiz, avval «Qo'ng'iroq qilinsinmi?» deb so'raladi — tasodifiy qo'ng'iroq ketmaydi.", en: "Tapping a call or video call button first asks «Call?» — no accidental calls.", ru: "При нажатии на звонок или видеозвонок сначала спрашивается «Позвонить?» — случайных звонков не будет."),
        disable: AlfaText(uz: "O'sha bandni o'chiring.", en: "Turn the same switch off.", ru: "Выключите тот же переключатель.")),
    AlfaAboutFeature(symbol: "video.badge.plus", color: 0xff9500,
        title: AlfaText(uz: "Galereyadan dumaloq video", en: "Round video from the gallery", ru: "Видеосообщение из галереи"),
        enable: AlfaText(uz: "Chatda 📎 → «Dumaloq video» → videoni tanlang. «Har safar so'rash» rejimida dumaloq video tugmasini bosib turib «Galereyadan video» ham bor.", en: "In a chat: 📎 → «Round video» → pick a video. In «Ask every time» mode, holding the round video button also offers «Video from gallery».", ru: "В чате: 📎 → «Видеосообщение» → выберите видео. В режиме «Спрашивать каждый раз» удержание кнопки видеосообщения тоже предлагает «Видео из галереи»."),
        how: AlfaText(uz: "1 daqiqagacha bo'lgan video o'rtasidan kvadrat qilib qirqiladi va dumaloq video bo'lib yuboriladi. Uzunroq video qabul qilinmaydi.", en: "A video up to 1 minute long is cropped to a centered square and sent as a round video. Longer videos are not accepted.", ru: "Видео до 1 минуты обрезается до квадрата по центру и отправляется кружком. Более длинные видео не принимаются."),
        disable: nil),
    AlfaAboutFeature(symbol: "checkmark.circle.fill", color: 0x34c759,
        title: AlfaText(uz: "Hammasini belgilash", en: "Select all", ru: "Выбрать все"),
        enable: AlfaText(uz: "Chatlar yoki kontaktlarda tanlash rejimiga o'ting.", en: "Enter selection mode in chats or contacts.", ru: "Перейдите в режим выбора в чатах или контактах."),
        how: AlfaText(uz: "Chatlarda tepadagi «Hammasi», kontaktlarda pastdagi «Hammasini belgilash» barchasini bir bosishda tanlaydi. Qayta bossangiz, belgilar olib tashlanadi.", en: "«All» at the top in chats and «Select all» at the bottom in contacts select everything in one tap. Tap again to clear.", ru: "«Все» вверху в чатах и «Выбрать все» внизу в контактах выбирают всё одним нажатием. Повторное нажатие снимает выбор."),
        disable: nil),
    AlfaAboutFeature(symbol: "ellipsis.circle.fill", color: 0x8e8e93,
        title: AlfaText(uz: "⋯ menyu", en: "⋯ menu", ru: "Меню ⋯"),
        enable: AlfaText(uz: "Chatlar ro'yxati tepasidagi ⋯ tugmasini bosing.", en: "Tap ⋯ at the top of the chat list.", ru: "Нажмите ⋯ вверху списка чатов."),
        how: AlfaText(uz: "Yangi xabar, hikoya qo'shish, QR skaner, AlfaGram sozlamalari, ko'rinish, keshni tozalash va ro'yxat oxiriga o'tish — hammasi bir joyda.", en: "New message, add story, QR scanner, AlfaGram settings, appearance, clear cache and jump to the end of the list — in one place.", ru: "Новое сообщение, история, QR-сканер, настройки AlfaGram, оформление, очистка кэша и переход в конец списка — в одном месте."),
        disable: nil),
    AlfaAboutFeature(symbol: "video.circle.fill", color: 0xff9500,
        title: AlfaText(uz: "Dumaloq video kamerasi", en: "Round video camera", ru: "Камера видеосообщений"),
        enable: AlfaText(uz: "Sozlamalar → AlfaGram → «Dumaloq video kamerasi»: har safar so'rash, doim old yoki doim orqa.", en: "Settings → AlfaGram → «Round video camera»: ask every time, always front or always back.", ru: "Настройки → AlfaGram → «Камера видеосообщений»: спрашивать каждый раз, всегда фронтальная или всегда основная."),
        how: AlfaText(uz: "«Har safar so'rash»da tugmani bosib tursangiz, kamera so'raladi va yozuv qo'lsiz davom etadi; «doim» rejimlarida video darhol tanlangan kamerada boshlanadi.", en: "With «Ask every time», holding the button asks for the camera and recording continues hands-free; the «always» modes start right away with that camera.", ru: "В режиме «Спрашивать каждый раз» при удержании кнопки спрашивается камера, и запись идёт без рук; режимы «всегда» сразу начинают с выбранной камеры."),
        disable: nil),
    AlfaAboutFeature(symbol: "bell.slash.fill", color: 0x5856d6,
        title: AlfaText(uz: "Ovozsiz yuborish", en: "Silent sending", ru: "Тихая отправка"),
        enable: AlfaText(uz: "Sozlamalar → AlfaGram → «Hammasini ovozsiz yuborish».", en: "Settings → AlfaGram → «Send everything silently».", ru: "Настройки → AlfaGram → «Отправлять всё без звука»."),
        how: AlfaText(uz: "Barcha xabarlaringiz qabul qiluvchida tovushsiz keladi.", en: "All your messages arrive without a sound.", ru: "Все ваши сообщения приходят без звука."),
        disable: AlfaText(uz: "O'sha bandni o'chiring.", en: "Turn the same switch off.", ru: "Выключите тот же переключатель.")),
    AlfaAboutFeature(symbol: "qrcode", color: 0x2563eb,
        title: AlfaText(uz: "Mening AlfaGram havolam", en: "My AlfaGram link", ru: "Моя ссылка AlfaGram"),
        enable: AlfaText(uz: "Sozlamalar → «Mening AlfaGram havolam».", en: "Settings → «My AlfaGram link».", ru: "Настройки → «Моя ссылка AlfaGram»."),
        how: AlfaText(uz: "alfagram.uz/username havolangiz QR kartochka bilan: nusxalash, ulashish, kartochka sifatida ulashish va rasmlarga saqlash.", en: "Your alfagram.uz/username link with a QR card: copy, share, share as a card or save to Photos.", ru: "Ваша ссылка alfagram.uz/username с QR-карточкой: копировать, поделиться, отправить карточкой или сохранить в Фото."),
        disable: nil),
    AlfaAboutFeature(symbol: "character.book.closed.fill", color: 0x30b8a8,
        title: AlfaText(uz: "O'zbekcha va kirillcha", en: "Uzbek: Latin and Cyrillic", ru: "Узбекский: латиница и кириллица"),
        enable: AlfaText(uz: "Sozlamalar → Til → O'zbek tili; kirill uchun Sozlamalar → AlfaGram → Til.", en: "Settings → Language → Uzbek; for Cyrillic, Settings → AlfaGram → Language.", ru: "Настройки → Язык → узбекский; для кириллицы — Настройки → AlfaGram → Язык."),
        how: AlfaText(uz: "Ilova o'zbekcha, xohlasangiz kirillda. «Lotincha yozsam, kirillda yuborilsin» yoqilsa, matningiz kirillga o'girilib yuboriladi.", en: "The app speaks Uzbek, in Cyrillic if you like. With «Send Latin as Cyrillic» on, your text is converted before sending.", ru: "Приложение на узбекском, по желанию — кириллицей. С «Латиницу отправлять кириллицей» текст конвертируется перед отправкой."),
        disable: AlfaText(uz: "O'sha bandlarni o'chiring.", en: "Turn the same switches off.", ru: "Выключите те же переключатели.")),
    AlfaAboutFeature(symbol: "number", color: 0x5e6ad2,
        title: AlfaText(uz: "ID nusxalash", en: "Copy ID", ru: "Копировать ID"),
        enable: AlfaText(uz: "Sukut bo'yicha yoqilgan: Sozlamalar → AlfaGram → «Xabar menyusida «ID nusxalash»».", en: "On by default: Settings → AlfaGram → «Copy ID in message menu».", ru: "Включено по умолчанию: Настройки → AlfaGram → «Копировать ID в меню сообщения»."),
        how: AlfaText(uz: "Xabarni bosib turganda «ID nusxalash» bandi chiqadi; profilda foydalanuvchi ID'si ko'rinadi.", en: "Pressing and holding a message shows «Copy ID»; profiles show the user ID.", ru: "При удержании сообщения появляется «Копировать ID»; в профиле виден ID пользователя."),
        disable: nil)
    ]
}

private enum AlfaAboutEntry: ItemListNodeEntry, Equatable {
    case header(Int32, Int32, String)
    case text(Int32, Int32, String)
    case feature(Int32, Int32, String, String, UInt32)

    var section: ItemListSectionId {
        switch self {
        case let .header(section, _, _), let .text(section, _, _), let .feature(section, _, _, _, _):
            return section
        }
    }

    var stableId: Int32 {
        switch self {
        case let .header(_, id, _), let .text(_, id, _), let .feature(_, id, _, _, _):
            return id
        }
    }

    static func <(lhs: AlfaAboutEntry, rhs: AlfaAboutEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        switch self {
        case let .header(_, _, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .text(_, _, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .feature(_, _, title, symbol, color):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: alfaSettingsIcon(symbol, color), title: title, label: "", sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
        }
    }
}

private func alfaAboutEntries() -> [AlfaAboutEntry] {
    var entries: [AlfaAboutEntry] = []
    var id: Int32 = 0
    func next() -> Int32 {
        id += 1
        return id
    }

    let enableLabel = AlfaText(uz: "YOQISH", en: "ENABLE", ru: "ВКЛЮЧИТЬ").value
    let howLabel = AlfaText(uz: "QANDAY ISHLAYDI", en: "HOW IT WORKS", ru: "КАК РАБОТАЕТ").value
    let disableLabel = AlfaText(uz: "O'CHIRISH", en: "DISABLE", ru: "ВЫКЛЮЧИТЬ").value

    entries.append(.header(0, next(), AlfaText(uz: "ALFAGRAM NIMA?", en: "WHAT IS ALFAGRAM", ru: "ЧТО ТАКОЕ ALFAGRAM").value))
    entries.append(.text(0, next(), AlfaText(uz: "AlfaGram — ustiga qo'shimcha imkoniyatlar qo'shilgan Telegram. Quyidagilarning hammasi bepul, obunasiz. Har birini Sozlamalar → AlfaGram bo'limida yoqib-o'chirasiz.", en: "AlfaGram is Telegram with extra tools built on top. Everything below is free, with no subscription. Each feature is turned on or off in Settings → AlfaGram.", ru: "AlfaGram — это Telegram с дополнительными возможностями. Всё ниже бесплатно и без подписки. Каждая функция включается и выключается в Настройки → AlfaGram.").value))

    var section: Int32 = 1
    for feature in alfaAboutFeatures() {
        entries.append(.feature(section, next(), feature.title.value, feature.symbol, feature.color))
        var text = enableLabel + ": " + feature.enable.value + "\n\n" + howLabel + ": " + feature.how.value
        if let disable = feature.disable {
            text += "\n\n" + disableLabel + ": " + disable.value
        }
        entries.append(.text(section, next(), text))
        section += 1
    }
    return entries
}

/// AlfaGram: the «About AlfaGram» screen (Settings → AlfaGram → at the bottom).
public func alfaAboutController(context: AccountContext) -> ViewController {
    let signal = context.sharedContext.presentationData
    |> deliverOnMainQueue
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(AlfaCyrillic.ui("AlfaGram haqida")), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: alfaAboutEntries(), style: .blocks, animateChanges: false)
        return (controllerState, (listState, 0))
    }
    return ItemListController(context: context, state: signal)
}
