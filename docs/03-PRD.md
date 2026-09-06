# Ürün gereksinimleri — v0.1

Durum: uygulanmış v0.1 ürün sözleşmesi. DM-001–003 ve DM-005–024 tamamlandı; DM-004 kullanıcı görüşmeleri ile DM-025 sonrası beta/yayın hazırlığı sürüyor.

## Hedef

Kullanıcı uygulamalarını, klasörlerini ve web adreslerini sıralı bir profile kaydeder; menü çubuğundan veya kendi atadığı global kısayoldan başlatır; hangi isteğin kabul edildiğini ve hangisinin başarısız olduğunu görür.

## Platform ve ürün kararları

- macOS 14 ve üzeri; v0.1 için test edilen Apple Silicon cihazlar desteklenir. Intel desteği test yapılana kadar ilan edilmez.
- Swift 6 dil modu; SwiftUI arayüz ve AppKit entegrasyonu.
- İlk dağıtım doğrudan indirilebilir, Developer ID imzalı ve notarize uygulama olarak planlanır. Mac App Store hedeflenmez.
- V0.1 App Sandbox kapalıdır; Hardened Runtime açık yayın hedefidir. TCC izinleri bundan bağımsızdır.
- İlk arayüz İngilizce ve Türkçe; sistem dilini izler. Kod isimleri İngilizce, geliştirme belgeleri Türkçe.
- Sunucu, kullanıcı hesabı, ağ senkronizasyonu, uygulama içi AI ve telemetri yoktur.

## İşlevsel gereksinimler

| ID | Gereksinim | Kabul kriteri |
| --- | --- | --- |
| FR-01 | Menü çubuğu uygulaması | İlk açılışta onboarding, sonraki açılışlarda menü simgesi; ayarlar/editör kapanınca süreç yaşamaya devam eder; Çıkış çalışır |
| FR-02 | Profil yönetimi | Oluştur, yeniden adlandır, çoğalt, sil ve sırala; yeniden başlatmada sıra ve içerik korunur |
| FR-03 | Eylem düzenleme | openApplication, openFolder, openURL eklenir, silinir, sıralanır ve devre dışı bırakılır |
| FR-04 | Uygulama açma | Kullanıcının seçtiği .app bundle kimliği çözülür; kurulu değilse açıklayıcı hata; zaten açıksa etkinleştirme isteği yapılır |
| FR-05 | Klasör açma | Kullanıcı NSOpenPanel ile klasör seçer; ilk sürüm Finder'da açar; bulunamayan/erişilemeyen klasör için yeniden seçme sunulur |
| FR-06 | URL açma | Yalnızca geçerli http/https URL'leri varsayılan tarayıcıya gönderilir; localhost ve özel ağ adreslerine izin verilir |
| FR-07 | Sıralı çalıştırma | Profilin kaydedilmiş snapshot'ı sıra korunarak çalışır; paralel ikinci run reddedilir |
| FR-08 | Sonuç ve hata | Her eylem için kabul/başarısız/zaman aşımı/atlanmış/iptal durumu; kısmi başarının açık özeti |
| FR-09 | Global kısayol | Profil başına kullanıcı tarafından atanan, başlangıçta boş kısayol; iç çakışma reddi; uygulama odakta değilken çalışır |
| FR-10 | Yerel kalıcılık | Sürümlü JSON, atomik yazma, doğrulanmış yedek; bozuk/yeni sürüm veri sessizce ezilmez |
| FR-11 | İptal | İptal sonrası sıradaki eylem başlatılmaz; açılmış uygulama/sekme kapanmaz |
| FR-12 | Onboarding ve erişilebilirlik | Kullanıcı ilk profili yardım almadan oluşturabilir; tüm işlevler klavye ve VoiceOver ile erişilebilir |
| FR-13 | Gizlilik | Dosya yolları, bookmark verileri ve tam URL'ler tanılama loguna yazılmaz; izin istemeden tarama yapılmaz |
| FR-14 | Tercihler | Oturum açılışında başlatma varsayılan kapalı; gerçek sistem kaydı durumu gösterilir; son run sonucu yalnızca bellekte tutulur |

## Validasyon ve kapasite

En fazla 50 profil, profil başına 30 eylem; 1–60 karakter kırpılmış profil adı, 1–80 karakter isteğe bağlı eylem etiketi. Aynı isimli profiller büyük/küçük harf ve Unicode normalizasyonuyla denetlenir; UUID kimliktir. Boş profil taslak olarak kaydedilebilir ancak çalıştırılamaz. En az bir etkin eylem şarttır. Ayrıntılı boyut ve JSON kuralları [veri modelinde](06-DATA-MODEL.md).

Her eylemin kayıtlı timeout değeri v0.1'de 10 saniyedir. Profil toplam süresi en fazla 60 saniye; aktif eylemin kalan bütçesi buna göre kısalır. Süreler tasarım hedefidir, OS işlemini geri alamaz. Varsayılan hata politikası `continue`; alternatif `stop`. Kullanıcı tekrar çalıştırırsa URL ve klasör pencerelerinin yeniden açılabileceği anlaşılır biçimde belirtilir.

## V0.1 kapsamı dışında

Shell komutu/script çalıştırma; AppleScript; editör/terminal dizin adaptörleri; tarayıcı sekmelerini okuma, kapatma veya tekrar kullanım garantisi; ses/mikrofon ayarları; Focus modu; ekran parlaklığı; pencere taşıma ve Spaces yönetimi; ortamı otomatik algılama; profil içe/dışa aktarma; bulut; otomatik güncelleme; eklenti pazarı; uygulama kapatma; undo/rollback; uygulama içi hazır olma veya web sayfası yüklenme kontrolü.

İlk fikrin terminal, ses ve monitör davranışları ürün vizyonundadır; MVP kabul kriteri değildir. [Yol haritası](11-ROADMAP.md) bunları ayrı sürümlere bağlar.

## İşlevsel olmayan hedefler

| ID | Hedef | Ölçüm |
| --- | --- | --- |
| NFR-01 | Boşta düşük maliyet | Release build, 5 dakika boşta ortalama süreç CPU < %1 ve RSS < 100 MB; donanım/OS ile raporla |
| NFR-02 | Tepkisel arayüz | Isınmış uygulamada menü/profil listesi ilk görünümü p95 < 150 ms; 30 ölçüm, 50 profil × 30 eylem fixture |
| NFR-03 | Güvenli kalıcılık | Yazma kesintisinde eski geçerli ana dosya veya doğrulanmış yedek geri alınabilir; testte veri kaybı yok |
| NFR-04 | Kararlı yürütme | Çift tıklama, gecikmiş callback ve iptal yarışında eylem bir kez dispatch edilir; sahte adaptör testleri |
| NFR-05 | Erişilebilirlik | Klavye ile tam ana akış, VoiceOver etiketleri, yalnız renge dayanmayan durumlar |

Bu performans değerleri ölçülmüş sonuç değil kabul hedefidir. Hedef tutmazsa ölçüm ve gerekçeyle yeniden değerlendirilir; sessizce başarılı sayılmaz.

## V0.1 tamamlanma koşulu

FR-01–14 ve ilgili test senaryoları geçer; minimum desteklenen macOS ile kullanılan güncel kararlı macOS üzerinde manuel akış doğrulanır. Bilinen engelleyici veri kaybı, beklenmedik çalıştırma veya çökme hatası kalmaz. Derleme, lisans, gizlilik ve yayın kontrolleri tamamlanır. Desteklenmeyen/denenmeyen cihazlar açık belirtilir.
