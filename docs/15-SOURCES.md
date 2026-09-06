# Kaynaklar ve doğrulama sınırları

Erişim/tarama tarihi: 2026-09-06. Teknik planın API dayanakları resmî Apple/OpenAI belgeleri ve bağımlılıkların kendi depolarıdır. Tasarım tercihleri bu kaynakların zorunlu kıldığı tek çözüm gibi sunulmaz.

| Kaynak | Neyi destekler | Neyi kanıtlamaz |
| --- | --- | --- |
| [Apple MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra) | Native menü çubuğu scene'i | Launchestra yaşam döngüsünün test edildiğini |
| [Apple NSWorkspace](https://developer.apple.com/documentation/appkit/nsworkspace) | Uygulama ve kaynak açma API yüzeyi | Tüm hedef uygulamaların aynı davranacağını |
| [openApplication](https://developer.apple.com/documentation/appkit/nsworkspace/openapplication%28at%3Aconfiguration%3Acompletionhandler%3A%29) | Asenkron başlatma ve callback | Editör projesi veya sayfanın hazır olmasını |
| [Belirli uygulamayla URL açma](https://developer.apple.com/documentation/appkit/nsworkspace/open%28_%3Awithapplicationat%3Aconfiguration%3Acompletionhandler%3A%29) | Sonraki editör adaptörü için aday | Terminal çalışma dizini davranışını |
| [Security-scoped bookmark seçeneği](https://developer.apple.com/documentation/Foundation/NSURL/BookmarkCreationOptions/withSecurityScope) | Sandbox ile ilişkili bookmark seçeneği | Normal bookmark'ın TCC izni verdiğini |
| [SMAppService register](https://developer.apple.com/documentation/servicemanagement/smappservice/register%28%29) | Login item/service kayıt mekanizması | Kullanıcının OS ayarının hep açık kalacağını |
| [Ekran değişikliği callback'i](https://developer.apple.com/documentation/coregraphics/cgdisplayregisterreconfigurationcallback%28_%3A_%3A%29) | Gelecek monitör olayı deneyi | Kalıcı fiziksel monitör kimliğini |
| [Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) | İmzalı doğrudan dağıtım akışı | Launchestra'nın imzalanmış/test edilmiş olduğunu |
| [GitHub Actions runner images](https://github.com/actions/runner-images) | GitHub-hosted macOS image/Xcode envanteri ve image desteği | Bu deponun CI koşusunun geçtiğini |
| [actions/checkout](https://github.com/actions/checkout) | Kilitli kaynak checkout action'ı; workflow'da v6.0.2 commit'i kullanılıyor | Uzak deponun veya workflow run'ının var olduğunu |
| [actions/upload-artifact](https://github.com/actions/upload-artifact) | Workflow log/xcresult artifact saklama; workflow'da v7.0.1 commit'i kullanılıyor | Saklanan artifact'ın uygulama release'i olduğunu |
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | Global shortcut, recorder ve custom storage yaklaşımı; projede 3.0.1 sürümü kullanılıyor | Bütün macOS sürümü/düzen kombinasyonlarının sorunsuz olduğunu |
| [GPT-5.6 Sol model](https://developers.openai.com/api/docs/models/gpt-5.6-sol) | Kullanıcının model adının resmî karşılığı | Kullanıcının hesabındaki kullanım hakkını |
| [GPT-5.6 prompting](https://developers.openai.com/api/docs/guides/model-guidance?model=gpt-5.6#prompting-best-practices) | Kısa/tekrarsız talimat ve açık sonuç yaklaşımı | Bu projede belirli başarı/hız oranını |
| [Codex AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md) | Proje talimat dosyası kullanımı | Diğer belgelerin otomatik tamamının yüklendiğini |
| [Kero](https://kero.sh/) | Terminal merkezli alternatifin kendi tanımı | Rakip özelliklerinin eksiksiz karşılaştırmasını |
| [AeroSpace](https://github.com/nikitabobko/AeroSpace) | Pencere yöneticisi odağı | Launchestra ile hiçbir örtüşme olmadığını |
| [Quay](https://github.com/manustays/quay) | Yerel servis yönetimi odağı | Talep büyüklüğünü veya pazar payını |
| [DeskMode - Standing Desk Timer](https://apps.apple.com/us/app/deskmode-standing-desk-timer/id6781822294) | Aynı adla yayımlanmış ve Mac uyumluluğu listelenen ürün | Bizim ürün fikrinin aynı olduğunu veya hukuki marka sonucunu |
| [Deskmode Suite](https://wordpress.org/plugins/deskmode-suite/) | Yazılım alanındaki ikinci güncel ad kullanımı | Her ülke/sınıftaki marka hakkını |
| [WIPO Global Brand Database](https://www.wipo.int/en/web/global-brand-database) | Uluslararası ve katılımcı ofis koleksiyonlarında marka arama yüzeyi | Tek kısa aramanın kapsamlı hukuki uygunluk olduğunu |

Apple belge sayfalarının bir kısmı dinamik içerik sunar. Uygulama sırasında Xcode'un yerel SDK imzaları ve gerçek minimum deployment target derlemesi son teknik doğrulamadır. Güncel API dokümanı geçmiş OS sürümündeki availability'yi tek başına kanıtlamaz.

## Kanıt düzeyleri

- **Kaynaklı bilgi:** Yukarıdaki resmî mekanizma ve proje tanımları.
- **Yerel gözlem:** arm64 macOS 26.6.2 üzerinde Xcode 26.1.1/Xcode Swift 6.2.1 ile app build ve 15 UI testi; CLI Swift 6.2.3 ile güncel 71 paket testi geçti. Release 50 × 30 fixture'ın 30 görünüm ölçümü p95 24,024 ms verdi. Global developer path CLI tools olduğu için komutlarda oturuma özgü `DEVELOPER_DIR` kullanıldı.
- **Tasarım kararı:** macOS 14 tabanı, 50×30 kapasite, 10/60s süre, JSON, sandbox kapalı v0.1.
- **Hipotez:** Kullanıcıların günlük tekrar kullanımı ve ortam profiline ihtiyaç düzeyi.
- **Bekleyen doğrulama:** macOS 14 cihaz matrisi, dış disk/erişim reddi, İngilizce klavye düzeni, VoiceOver/Full Keyboard Access ve yayımlanmış beta sonuçları.

Hiçbir araştırma notu kod görevinin test kanıtı yerine geçmez.
