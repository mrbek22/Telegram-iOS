# AlfaGram iOS

Telegram-iOS (TelegramMessenger/Telegram-iOS) asosidagi AlfaGram. Android versiyasi: `mrbek22/Telegram`.
Ish tarmog'i: `alfagram`.

## Build

- Sinov build: GitHub Actions → **AlfaGram iOS (imzosiz sinov build)** (`.github/workflows/alfagram-ios.yml`),
  `xcode-27` Mac serverida, Telegram'ning `fake-codesigning` sertifikatlari bilan. Natija — imzosiz IPA (telefonga
  o'rnatilmaydi, faqat kod yig'ilishini tekshiradi).
- Xcode/Bazel versiyasi `versions.json` da (hozir Xcode 27.1, Bazel 9.2.0).
- Haqiqiy build (TestFlight / App Store) uchun kerak: Apple Developer akkaunti ($99/yil), Team ID, `uz.alfagram.*`
  bundle ID, sertifikat va provisioning profillar, o'z `api_id`/`api_hash` (my.telegram.org). Shundan keyin
  `build-system/alfagram-configuration.json` yaratiladi.

## Bosqichlar

1. **Brend** ✅ — nom "AlfaGram" (`Telegram/BUILD` CFBundleDisplayName), ikonka `Telegram/Telegram-iOS/Telegram.icon`.
   Qoldi: muqobil ikonkalar (`*.alticon`), ishga tushish ekrani, bundle ID (Apple akkaunti bilan).
2. **AlfaGram sozlamalari** ✅ (`TelegramCore/Sources/AlfaGram/AlfaSettings.swift`, ekran `SettingsUI/Sources/AlfaGram`) — `submodules/AlfaGram` moduli: bayroqlar (UserDefaults), Sozlamalarda "AlfaGram" bo'limi.
3. **O'chirilgan xabarlarni saqlash** ✅ (`AlfaDeletedMessageAttribute`, `alfaKeepDeletedMessages`; vaqt yonida 🗑) — `TelegramCore/Sources/State/Sync/StateReplay.swift`
   (`.DeleteMessages`, `.DeleteMessagesWithGlobalIds` → `applyDeleteMessagesWithGlobalIds`): o'chirish o'rniga belgi qo'yish.
4. **Tahrir tarixi** ✅ (`AlfaEditHistoryMessageAttribute`, kontekst menyu "Tahrir tarixi") — xabar tahrirlanganda eski matnni lokal saqlash.
5. **Ghost rejim** ✅ (onlayn, yozyapti, o'qildi) — onlayn: `TelegramCore/Sources/State/ManagedAccountPresence.swift`; yozyapman:
   `ManagedLocalInputActivities.swift`; o'qildi belgisi — read state sinxronlash.
6. **Avto papkalar, arxiv turlari, ikki tomonlama surish, onlayn tarix, APK/havola himoyasi** (iOS'da APK yo'q —
   faqat havola himoyasi).
7. **Apple qoidalari** — himoyalangan kontentni saqlash va shunga o'xshash funksiyalar App Store tekshiruvidan
   o'tmasligi mumkin; ular masofadan (AlfaConfig) o'chiriladigan bo'ladi.

## Holat (2026-11-09)

Android'dagi funksiyalar (APK qo'riqchisidan tashqari) ko'chirildi:
- Sozlamalar → AlfaGram: xabarlar, Ghost (onlayn/yozyapti/o'qildi/anonim story), kuzatuv jurnallari, xavfsizlik, cheklovsiz, til, yordam guruhi.
- Kuzatuv (faqat telefonda, `TelegramCore/Sources/AlfaGram/AlfaLogs.swift`): onlayn tarixi, profil o'zgarishlari (Kontaktlar → «Profil o'zgarishlari» ham), yozdi-yubormadi.
- Havola himoyasi (`AlfaGramUI/AlfaLinkGuard.swift`, `TelegramUI/Sources/OpenUrl.swift`), reklama bloki, xabar menyusida «ID nusxalash», profilda ID va taxminiy ro'yxatdan o'tgan sana.
- Ochilish animatsiyasi (`AlfaGramUI/AlfaSplashOverlay.swift`), chatlar sarlavhasida salomlashuv (`ChatListUI/AlfaChatListGreeting.swift`), birinchi ochilishda 3 slayd, App Store baholash so'rovi.
- Kirill: Til → «Ўзбекча (кирилл)», «lotincha yozsam kirillda yuborilsin»; yangi userlarga Night mavzu; 10 akkaunt.
- Ko'chirilmagan: avto papkalar (iOS'da Sozlamalar → Papkalar → tavsiya etilgan papkalar bor), Wrapped, story ko'ruvchilar tarixi, muqobil ikonkalar.
