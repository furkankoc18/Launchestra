# Veri modeli ve kalıcılık sözleşmesi

Uygulama durumu: model/repository DM-005/006, bookmark yenileme DM-007 ve açık kullanıcı kararlı kurtarma akışı DM-021 kapsamında 6 Eylül 2026 tarihinde tamamlandı.

## Kayıt yeri

Platformun Application Support dizininde `DeskMode/profiles.json`; kullanıcı yolunu kodda hardcode etme. Yanında son doğrulanmış sürüm `profiles.backup.json`. Uygulama tercihlerinde onboarding bilgisi UserDefaults'ta; profil içerikleri ve kısayollar tek JSON otoritesinde tutulur. Geçici run sonuçları bellektedir, yeniden açılışta geri yüklenmez.

Bu v0.1 yerel şemadır; taşınabilir profil formatı değildir. Bookmark ve yerel yolları başka cihazda çalışır diye dışa aktarma yoktur.

## Tipler

| Tip | Alanlar |
| --- | --- |
| ProfileStore | schemaVersion: Int, revision: Int, profiles: [Profile] |
| Profile | id: UUID, name: String, createdAt/updatedAt: Date, failurePolicy: continue/stop, shortcut: ShortcutBinding?, actions: [ProfileAction] |
| ProfileAction | id: UUID, label: String?, enabled: Bool, timeoutSeconds: Int, kind: ActionKind |
| ActionKind | Açık type discriminator ve payload: openApplication / openFolder / openURL |
| ApplicationReference | bundleIdentifier: String, displayName: String |
| FolderReference | bookmarkBase64: String, lastKnownPath: String, displayName: String |
| ShortcutBinding | keyCode: Int, modifiers: [control/option/shift/command] |

Profil ve eylem sırası array sırasıdır. Eylemler arasında genel bir bağımlılık grafiği yoktur. `shortcut: null` atanmadı anlamındadır. Kalıcı enum encoding otomatik Swift enum Codable çıktısına bırakılmaz; discriminator alanı açık yazılır.

## Örnek JSON

Bu örnek yalnız uygulama ve URL içerir; bütün UUID ve tarihler örnektir. Gerçek kullanıcı bilgisi içermez.

```json
{
  "schemaVersion": 1,
  "revision": 0,
  "profiles": [
    {
      "id": "211f5889-4889-4e8d-b228-f8ccf4a8ee11",
      "name": "Çalışma",
      "createdAt": "2026-09-05T09:00:00Z",
      "updatedAt": "2026-09-05T09:00:00Z",
      "failurePolicy": "continue",
      "shortcut": null,
      "actions": [
        {
          "id": "e9a8a14d-1b52-4654-a96c-e7db8b84233a",
          "label": "Tarayıcı",
          "enabled": true,
          "timeoutSeconds": 10,
          "kind": {
            "type": "openApplication",
            "payload": {
              "bundleIdentifier": "com.apple.Safari",
              "displayName": "Safari"
            }
          }
        },
        {
          "id": "1d0b7ae3-05d3-44ef-bc53-a8bba8fc8d55",
          "label": "Yerel proje",
          "enabled": true,
          "timeoutSeconds": 10,
          "kind": {
            "type": "openURL",
            "payload": { "url": "http://localhost:3000" }
          }
        }
      ]
    }
  ]
}
```

`openFolder` payload'u `FolderReference` alanlarından oluşur. Base64 bookmark platform tarafından üretilir; örnek metin gerçek bookmark yerine kullanılmaz. `openURL` payload yalnız `url` alanı taşır. `openApplication` bir bundle identifier üzerinden o anda Launch Services'in çözdüğü uygulamayı hedefler; belirli binary sürümüne pinleme garantisi yoktur.

## Doğrulama

- Dosya okumadan önce boyut limiti: 10 MiB. En fazla 50 profil × 30 eylem.
- Profil adları trim sonrası 1–60 Swift Character; eylem etiketi null veya trim sonrası 1–80 Character. İsim karşılaştırması sabit locale ile case folding ve Unicode canonical normalization kullanır; Türkçe I/i ve birleşik Unicode testleri tanımlanır.
- Store genelinde profil UUID'leri, her profil içinde eylem UUID'leri benzersiz. Kopyalamada yeni UUID'ler oluşturulur.
- `schemaVersion == 1`, `revision >= 0`, tarihler UTC ISO-8601; fractional seconds olmadan yazılır, parser bu sözleşmeyi izler. `updatedAt >= createdAt`.
- `timeoutSeconds == 10` v0.1 için tek kabul edilen kayıt değeri. Değiştirilebilir ayar UI'sı yoktur.
- URL uzunluğu en fazla 4096 UTF-8 byte; URLComponents ile http/https, dolu host, user/password yok, ham kontrol karakteri yok. Geçersiz port reddedilir; localhost, IPv4/IPv6 ve özel ağlar kabul edilir. `javascript:`, `data:`, `file:`, özel app şemaları reddedilir.
- Bundle kimliği boş olamaz, en fazla 255 UTF-8 byte; gerçek seçilmiş .app'den alınır. Display name 1–255 Character. Kimliği yalnız katı üç-parçalı regex ile kısıtlama.
- Bookmark decode sonrası en fazla 64 KiB; lastKnownPath mutlak yol ve en fazla 4096 UTF-8 byte; yol gösterim/teşhis içindir, çözüm başarısızsa otomatik güvenilir fallback değildir.
- Kısayol en az command/control/option'dan birini içerir; shift tek başına yeterli değildir. Desteklenen normal tuş keyCode'u DM-003 adaptörüyle doğrulanır. Modifier listesinde tekrar yok; kayıtta kanonik sıra control, option, shift, command. Aynı bağ iki profile atanamaz.

Bilinen sürümde bilinmeyen action türü veya bilinmeyen şema alanı görülürse store uyumsuz kabul edilir ve özgün dosya korunur. Sessiz alan kaybı/downgrade yapılmaz. Bu katı politika yeni alan eklemenin schemaVersion artışı gerektirdiği anlamına gelir.

## Atomik kaydetme

1. Actor mevcut revision ile `expectedRevision` eşleşmesini kontrol eder. Eşleşmiyorsa `revisionConflict`; taslak korunur, UI yeniden yükleme/birleştirme seçeneği sunar.
2. Yeni belgeyi tamamen doğrula; revision'ı bir artır; encoded veriyi aynı dizindeki benzersiz geçici dosyaya yaz.
3. Geçici dosyayı yeniden decode/validate et. Gerekli dosya kapatma/senkronizasyon işlemlerini tamamla.
4. Mevcut ana dosya geçerliyse onun bytes'ını atomik olarak backup'a yaz. Bozuk ana dosyayı sağlam yedeğin üzerine yazma.
5. Yeni dosyayı aynı dosya sistemi içinde atomik replace ile ana dosya yap. İlk kayıt create yolu ayrı ele alınır.
6. Başarıdan sonra in-memory store'u yayınla. Hata olursa eski görünür state ve kullanıcı taslağı korunur; geçici dosyaları yalnız uygulamanın kendi güvenli ad alanında temizle.

Tek süreç/tek repository writer desteklenir. Çalışırken haricî JSON düzenleme ve birden fazla uygulama kopyasının aynı dosyaya yazması desteklenmez. Disk ana dosyasının son yüklenen fingerprint/revision'ı değişmişse yazma durur; kilit kaynağı kullanıcıya belirtilir. Atomik replace tek başına çoklu süreç eşgüdümü sağlamaz; ikinci yazıcıyı engelleyen uygulama ömürlü advisory file lock DM-006'da uygulanır. Kilidi alamayan kopya salt okunur kalır.

DM-006 uygulaması SHA-256 byte fingerprint'i, `fcntl(F_SETLK)` advisory write lock'ı ve aynı süreçte ikinci actor'ı engelleyen kilit kayıtçısını birlikte kullanır. Dosya ve dizin rename öncesi/sonrası senkronize edilir. İlk ana dosya `moveItem`, mevcut ana dosya aynı dosya sisteminde atomik `rename` yolunu kullanır. Repository yalnız commit tamamlandıktan sonra yeni `ProfileStore` döndürür.

## Yükleme ve kurtarma

Ana dosya yok, backup yok: boş store. Ana dosya yok ama geçerli backup varsa kurtarma ekranı; sessiz boş sıfırlama yok. Ana dosya bozuk: run ve yazma kapalı, doğrulanmış backup varsa kullanıcı seçerek geri alabilir. Özgün bozuk dosya tarihli recovery kopyası olarak korunmadan reset/restore yapılmaz. Bozuk backup geçerli kabul edilmez.

Ana dosya daha yeni/uyumsuz şemadaysa eski backup'a otomatik dönülmez. Uyumlu uygulama kullanma mesajı gösterilir. Kullanıcının yeni boş yapılandırma tercihi varsa özgün dosyayı koruyan açık işlem gerekir. Disk doluyken koruma kopyası yapılamıyorsa reset yapılmaz.

V1 için migration yoktur. V2 geldiğinde V1→V2 migration saf fonksiyon ve fixture testleriyle eklenir; migration öncesi backup alınır. Downgrade yeni şemayı yazamaz.

## Bookmark ve kısayol

Sandbox kapalı v0.1 için normal bookmark kullanılır; security-scoped entitlement/erişim çağrıları otomatik eklenmez. Bookmark taşınmış klasöre çözülebilir; stale ise başarılı çözüm sonrası yenilenir ve revision kontrollü kaydedilir. Başarısız çözümde kullanıcı yeniden seçer. Bookmark TCC izni vermez. [Apple bookmark açıklaması](https://developer.apple.com/documentation/Foundation/NSURL/BookmarkCreationOptions/withSecurityScope).

Kısayollar JSON'a ait taslak alanıdır. Recorder'ın kendi varsayılan UserDefaults depolamasını ek bir otorite olarak kullanma; custom Binding ve kayıttan sonra registration tercih edilir. Kayıt başarısızsa kısayol aktif seti değişmez. Kayıt sonrasında OS kısayolu reddederse profil saklanır, kısayol “etkinleştirilemedi” gösterilir ve menüden çalıştırma kullanılabilir.
