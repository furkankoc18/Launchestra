# Geliştirmeye başlangıç

## Hedef ve sınır

Bu proje GPT-5.6 Sol ile geliştirme için hazırlanmıştır. Kullanıcının henüz seçmediği ürün ayrıntıları açık varsayımlar olarak karara bağlanmıştır; rutin kodlama kararları için tekrar tekrar onay beklenmez. DM-001–003 ve DM-005/006 tamamlanmış, DM-004 görüşme erişimi beklemektedir; sonraki görevlerin sözleşmeleri bu belgelerde tutulur.

## İlk oturum

1. `/Users/furkankoc/Desktop/projects/DeskMode/` klasörünü proje olarak aç. Uygulamanın kullanıcı tarafından seçilen kökü burasıdır.
2. Codex'te geliştirme modeli olarak **GPT-5.6 Sol** seç. Bu belge model ayarını otomatik değiştirmez.
3. [AGENTS.md](AGENTS.md), [STATUS.md](STATUS.md), [PRD](docs/03-PRD.md), [mimari](docs/05-ARCHITECTURE.md) ve [TODO](TODO.md) içindeki sıradaki görevi oku.
4. [PROMPTS.md](PROMPTS.md) içindeki başlangıç promptunu kullan.
5. TODO bağımlılık sırasıyla ilerle. Tüm görevleri tek devasa değişiklikte uygulamayı hedefleme.

## Ortamda doğrulanmış bilgiler

5 Eylül 2026 tarihinde bu arm64 makinede macOS 26.6.2 (25G83), Xcode 26.1.1 (17B100), Xcode Swift 6.2.1 ve CLI Swift 6.2.3 doğrulandı. Etkin global developer path hâlâ Command Line Tools olduğundan proje komutları oturuma özgü `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` kullanır. App build'i, paket testleri ve yerel imzalı UI testleri bu seçimle geçti; global `xcode-select` değiştirilmedi.

## Okuma rotaları

| Yapılacak iş | Gerekli belgeler |
| --- | --- |
| Model/depolama | PRD, veri modeli, ilgili TODO, test planı |
| Menü/profil editörü | PRD, UX, mimari, ilgili TODO |
| Uygulama açma/kısayol | macOS entegrasyonları, çalıştırma motoru, güvenlik |
| Hata düzeltme | STATUS, ilgili davranış sözleşmesi, başarısız test |
| Sürüm hazırlığı | Test planı, sürüm planı, gizlilik, katkı |

Her oturumda tüm belgeleri prompta yapıştırmak gerekmez. Kısa kalıcı kurallar AGENTS.md'de, ayrıntılar ilgili belgede tutulur.

## İlk gösterim

Kullanıcı “Çalışma” profilini oluşturur, Safari ekler, kendi seçtiği klasörü Finder'da açacak bir adım ekler ve bir HTTPS adresi ekler. Kaydeder, uygulamayı yeniden açar, profili menüden çalıştırır ve üç adımın sonucunu görür. Sonra kullanıcı tarafından atanmış kısayolla aynı akışı başlatır.

Terminali belirli dizinde açma ve editöre proje gönderme ayrı uyumluluk adımlarıdır. İlk gösterim bu entegrasyonlara bağlı değildir.

## Belge önceliği

Kapsam için PRD, veri biçimi için DATA-MODEL, yürütme semantiği için EXECUTION-ENGINE kaynak kabul edilir. TODO bu sözleşmeleri uygular. Çelişki bulunursa sessiz bir üçüncü davranış üretme; ilgili belgeleri aynı değişiklikte tutarlı hale getir ve karar kaydı ekle. Kullanıcının güncel talimatı doküman varsayımlarından önce gelir.
