# macOS entegrasyonları ve teknik deneyler

API seçimi resmî dokümantasyon, yerel SDK derlemesi ve 5 Eylül 2026 tarihli DM-002/DM-003 deneylerine dayanır. Bulgular arm64 macOS 26.6.2 üzerindeki dar teknik kanıttır; bütün macOS sürümleri veya hedef uygulamalar için uyumluluk iddiası değildir.

## V0.1 entegrasyon tablosu

| İşlev | Seçilen yol | İzin/başarı sınırı | Doğrulama |
| --- | --- | --- | --- |
| Menü çubuğu | SwiftUI MenuBarExtra, window style; ayrı yönetim penceresi | Süreç/pencere yaşam döngüsü gerçek app bundle'da test edilir | DM-002, DM-011 |
| Uygulama seçimi | NSOpenPanel ile .app seçimi, Bundle metadata | Diskteki script veya sıradan dosyayı uygulama kabul etme | DM-002, DM-013 |
| Uygulama açma | NSWorkspace bundle ID çözümü ve openApplication | Başlatma callback'i uygulamanın iş içeriğinin hazır olduğunu kanıtlamaz | DM-002, DM-008 |
| Klasör açma | NSOpenPanel directory seçimi; bookmark çözümü; Finder'a NSWorkspace open isteği | Protected folders için OS erişim kısıtı olabilir; Full Disk Access çözümünü dayatma | DM-002, DM-008 |
| URL açma | NSWorkspace ile varsayılan handler'a http/https URL gönderimi | Handler isteği kabul edebilir ama sayfa yüklenmeyebilir; ağ kontrolü yok | DM-002, DM-008 |
| Kısayol | KeyboardShortcuts, custom Binding ve kayıtlı shortcut events | Keylogger/event tap kullanılmaz; OS çakışmaları her zaman önceden bilinmeyebilir | DM-003, DM-018 |
| Girişte başlat | SMAppService.mainApp | OS kaydı/onayı gerçek durumdur; kullanıcı isteği tek başına başarı değildir | DM-019 |
| Yerel kaynak hatırlama | Foundation URL bookmark | V0.1 sandbox kapalı; normal bookmark, TCC bypass yok | DM-002, DM-007 |

Kaynaklar: [MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra), [NSWorkspace](https://developer.apple.com/documentation/appkit/nsworkspace), [openApplication](https://developer.apple.com/documentation/appkit/nsworkspace/openapplication%28at%3Aconfiguration%3Acompletionhandler%3A%29), [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts), [SMAppService register](https://developer.apple.com/documentation/servicemanagement/smappservice/register%28%29).

## DM-002 sonucu: sistem açma ve yaşam döngüsü

Deney ortamı: Mac16,7, arm64; macOS 26.6.2 (25G83); Xcode 26.1.1 (17B100); Xcode Swift 6.2.1. Debug app bundle yerel olarak derlendi. App Sandbox kapalı, entitlement dosyası boş ve `LSUIElement=true`; shell, AppleScript veya Accessibility kullanılmadı.

Derlenerek kullanılan SDK çağrıları:

```swift
NSWorkspace.urlForApplication(withBundleIdentifier:)
NSWorkspace.openApplication(at:configuration:) async throws -> NSRunningApplication
NSWorkspace.open(_:withApplicationAt:configuration:) async throws
NSWorkspace.open(_:) -> Bool
URL.bookmarkData(options:includingResourceValuesForKeys:relativeTo:)
URL.init(resolvingBookmarkData:options:relativeTo:bookmarkDataIsStale:)
```

`WorkspaceExperimentService` MainActor üzerinde çalışır. Uygulama bundle ID ile çözülür; klasör açıkça Finder URL'sine gönderilir; URL yalnız host içeren HTTP/HTTPS ise varsayılan handler'a verilir. Başarılı dönüş yalnız Launch Services'ın isteği kabul ettiğini bildirir. Hedef uygulamanın arayüzü, klasör içeriği veya web sayfasının yüklenmesi ayrıca doğrulanmaz.

| Senaryo | Gerçek sonuç | Kanıt sınırı |
| --- | --- | --- |
| Safari kapalıyken ve çalışırken açma | Her iki istek kabul edildi | Safari içeriğinin hazır olma süresi ölçülmedi |
| `DeskMode OS smoke ' $() 🚀` klasörünü Finder'da açma | İstek kabul edildi; shell yolu yok | Korunan klasör/erişim reddi denenmedi |
| `Türkçe folder ' $() 🚀` bookmark'ı oluştur, klasörü taşı, çöz | Yeni konum çözüldü, otomatik test geçti | Dış disk ayrılması ve silinmiş hedef bekliyor |
| `http://localhost:65535/deskmode-smoke` ve `https://example.com/` | Varsayılan handler istekleri kabul etti | Localhost servisi/sayfa yüklenmesi aranmadı |
| `javascript:alert(1)` | Handler çağrılmadan `invalidURL` | İzinli liste HTTP/HTTPS ile sınırlı |
| Menü ajanı başlatma | LSUIElement uygulaması çalışmaya devam etti | Uyku/uyanma matrisi bekliyor |
| Yönetim penceresini göster, kapat, yeniden göster | Yeni NSWindow oluşturuldu; süreç çalışır kaldı | Yerel imzalı gerçek app sürecinde otomatik UI smoke |

Gerçek OS smoke testi bilinçli olarak opt-in'dir; geçici sentetik klasör kullanır ve Safari/Finder/varsayılan tarayıcıyı açar. Dış disk, erişim reddi, minimum macOS 14 cihazı, ağ tamamen kapalı durum ve prompt gösteren korunan kaynaklar DM-007/008/026 kapsamındaki tam OS matrisi için açık kalır.

## DM-007/008 üretim adaptörleri — 2026-09-06

`FolderReferenceService` bookmark işlemlerini MainActor dışında bir actor üzerinde yürütür. Çözüm bookmark verisinden gelmek zorundadır; `lastKnownPath` yalnız tanılama metadata'sıdır. Çözüm stale ise yeni bookmark üretilir ve `FolderReferenceRepairService` store'un yüklendiği revision ile repository save çağırır. Normal bookmark'ın sandbox veya TCC izni verdiği varsayılmaz.

MainActor `WorkspaceDispatcher`, `WorkspaceClient` sınırının arkasında bundle ID çözümü ve yalnız üç açma yolu sunar: uygulama, Finder ile klasör ve varsayılan handler ile HTTP(S). Sonuç yalnız kabul veya sabit `RunErrorCode` reddidir; ham NSError açıklaması, yol, tam URL veya bookmark otomatik loglanmaz. Sahte istemci testleri bu eşlemeleri doğruladı. DM-015 doğrulamasında gerçek ürün runner'ı Safari, geçici Finder klasörü ve `http://localhost:65535/deskmode-smoke` hedefini sırayla gönderdi; üç Launch Services isteği kabul edildi ve dış alan adı kullanılmadı.

## DM-003/018 sonucu: global kısayol

`KeyboardShortcuts` 3.0.1 tam sürümü kullanılır. Her iki `Package.resolved` dosyası `49c3fc04ea827f816df67843bfcc57286b47ff06` revision'ına kilitlidir. Paket MIT lisanslıdır. 3.0.1 kaynak yüzeyindeki `Recorder(_:shortcut:)`, `Shortcut(carbonKeyCode:carbonModifiers:)`, `isTakenBySystem` ve `events(for:)` Swift 6/macOS 14 hedefinde derlendi.

Kütüphanenin UserDefaults tabanlı ad deposu kullanılmaz. Editördeki custom-binding recorder, Carbon key code ve modifier değerlerini doğrudan profil taslağındaki `ShortcutBinding` alanına yazar; tek kayıt otoritesi sürümlü `ProfileStore` JSON'udur. `ProfileShortcutCoordinator` kaydedilmiş profil setinden listener üretir ve uygulama yeniden açıldığında bağları etkinleştirir. Yeni set önce çakışma için doğrulanıp etkin olmayan listener'larla hazırlanır; repository kaydı başarılı olursa tek adımda etkinleşir. Kayıt başarısız olursa hazırlanan listener'lar iptal edilir ve eski aktif set korunur.

| Senaryo | Sonuç |
| --- | --- |
| İlk açılış / atanmamış profil | `shortcutDraft=nil`; listener oluşturulmadı |
| Aynı chord'u iki profile verme | Saf validator `duplicateShortcut` döndürdü |
| Rebind ve remove | Eski task iptal edildi; registry sırasıyla bir ve sıfır listener tuttu |
| JSON yazma hatası | Proposed binding etkinleşmedi |
| OS registration hatası | Yeni geçici listener'lar iptal edildi; eski aktif assignment korundu |
| Basılı tutma | Tekrarlanan key-down olayları tetiklemedi; tek key-up bir kez tetikledi |
| Arka plan gerçek event | Finder öndeyken `⌘⌥⌃⇧K`, Launchestra'yı tam bir kez tetikledi |
| Sistem çakışması | `⌘⌥⌃⇧Q`, bu makinede `isTakenBySystem` ile reddedildi |
| Klavye düzeni | Etkin `Turkish-QWERTY-PC` düzeninde gerçek global event geçti |

İngilizce düzen bu makinede etkin giriş kaynakları arasında bulunmadığından düzen değiştirme testi yapılmadı. Persist edilen Carbon key code fiziksel tuş konumudur; UI geçerli düzene göre açıklama üretir ve harf anlamının düzenler arasında sabit kalacağı vaat edilmez. Media key ve Caps Lock V0.1 kapsamı dışındadır. İmzalı ürün UI testinde geçici JSON'dan yüklenen `⌘⌥⌃⇧K`, Finder öndeyken ortak `AppModel.run` yolunu tetikledi; test dispatcher'ı dış kaynak açmadan tamamlandı.

## DM-019 sonucu: girişte başlatma

`LoginItemService`, ServiceManagement çağrılarını MainActor üzerinde dar bir `LoginItemBackend` sınırı arkasında tutar. Üretim backend'i yalnız `SMAppService.mainApp` kullanır; uygulama açılışında `status` okunur ancak `register()` veya `unregister()` çağrılmaz. Ayar değeri ayrı bir UserDefaults bayrağından değil `SMAppService.Status` değerinden türetilir.

| Sistem durumu | Arayüz davranışı |
| --- | --- |
| `notRegistered` | Anahtar kapalı; Launchestra kendiliğinden kaydolmaz |
| `enabled` | Anahtar açık; login sonrasında uygulamanın başlatılabileceği, profilin otomatik çalışmayacağı yazılır |
| `requiresApproval` | Anahtar açık/pending; macOS onayı ve Giriş Öğeleri bağlantısı gösterilir; kullanıcı kaydı kaldırabilir |
| `notFound` | Anahtar kapalı; uygulamanın Applications klasörüne taşınması önerilir; kullanıcı yeniden kayıt deneyebilir |

Fake backend testleri ilk okumanın mutasyon yapmadığını, kayıt/kaldırma sonrasında gösterilen değerin backend'in gerçek durumu olduğunu, dış sistem değişikliğinin yenilemeye yansıdığını, onay bekleyen kaydın kaldırılabildiğini ve kayıt hatasının `enabled` uydurmadığını doğruladı. OS-05 opt-in smoke testi yerel imzalı app bundle ile gerçek kullanıcı oturumunda `notFound → enabled → notRegistered` sonucunu verdi. Başlangıçtaki kapalı durum geri yüklendi; test profil çalıştırmadı. `notFound` ilk değerinin build dizinindeki geçici bundle'a ait olduğu, kayıt çağrısının yine de bu ortamda başarıyla etkinleştiği kayda geçirildi.

## Sonraki sürümler için sınırlar

- **Editöre klasör gönderme:** NSWorkspace `open(_:withApplicationAt:configuration:completionHandler:)` adaydır; hedef editörün klasör açma davranışı ayrıca doğrulanır. Terminal dizini için özel adaptör gerekir. Rastgele `cd` metni veya shell string birleştirme yapılmaz. [API](https://developer.apple.com/documentation/appkit/nsworkspace/open%28_%3Awithapplicationat%3Aconfiguration%3Acompletionhandler%3A%29).
- **Monitör olayı:** CoreGraphics ekran yeniden yapılandırma callback'i adaydır. Display ID'nin yeniden başlatmalar arasında kalıcı kimlik olduğu varsayılmaz. Debounce, uykudan dönüş ve aynı model iki monitör senaryosu gerekir. İlk özellik yalnız öneri üretir. [Callback API](https://developer.apple.com/documentation/coregraphics/cgdisplayregisterreconfigurationcallback%28_%3A_%3A%29).
- **Ses:** CoreAudio üzerinden cihaz listeleme/default cihaz seçimi araştırılır. Bazı çıkışlar yazılımsal ses seviyesini desteklemez; toplantı uygulamaları kendi cihaz seçimini tutabilir. Sistem default değişimi bütün uygulamalara uygulanmış sayılmaz. Uygulamaya özel mikrofon/cihaz garantisi yoktur.
- **Pencereler:** Accessibility izni ve hedef uygulama uyumluluğu gerektiren ayrı deney. Tam ekran, Spaces, minimize pencere ve çoklu monitör ayrı senaryodur. İlk sürüm buna izin istemez.
- **Focus/parlaklık:** Desteklenen public API ve ürün talebi doğrulanmadan yol haritasına kesin taahhüt eklenmez.

Bu gelecek maddeler API doğrulama gündemidir; doğrulanmış çalışan entegrasyonlar değildir.

## İzin ilkesi

V0.1 açılışında Accessibility, Input Monitoring, Screen Recording, Microphone veya Automation talebi olmamalıdır. Kullanıcı klasör seçimine bağlı OS erişim akışı olabilir. Beklenmedik izin talebi, gereken özelliği ve API'yi araştırmayı gerektirir; sırf hatayı aşmak için entitlement eklenmez. App Sandbox kapalı olması TCC'yi devre dışı bırakmaz.
