# Riskler, varsayımlar ve açık kararlar

## Seçilen varsayımlar

Bu kararlar geliştirmeyi başlatmak için alınmıştır; kullanıcı değiştirirse ilgili PRD/ADR güncellenir.

| Konu | Başlangıç kararı | Değişirse etkisi |
| --- | --- | --- |
| Proje kökü | `/Users/furkankoc/Desktop/projects/DeskMode/` — kullanıcı belirledi | Taşıma ve geliştirme yolu güncellenir |
| Ürün adı | Launchestra; kullanıcıya görünen ad uygulandı | Kalıcı bundle/repository kimlik göçü DM-027/028'de tamamlanır |
| OS/donanım | macOS 14+, Apple Silicon önce | Deployment target ve test matrisi |
| Mimari | Native SwiftUI/AppKit, Swift 6 | Büyük değişiklik ADR gerektirir |
| Dağıtım | Doğrudan imzalı/notarize indirme | App Store hedefi sandbox/izin incelemesi gerektirir |
| Eylemler | Uygulama, Finder klasörü, http/https URL | Yeni action şema/runner/UI/test değiştirir |
| Lisans | MIT; telif sahibi `furkankoc` | Standart LICENSE ve üçüncü taraf bildirimleri eklendi; public repo/güvenlik kanalı DM-027/029 kapısı |
| Model | GPT-5.6 Sol ile geliştirme | Kullanıcı model seçimi; runtime değişmez |

## Risk kaydı

Olasılık/etki değerleri tasarım değerlendirmesidir, ölçülmüş istatistik değildir. İlk sorumlu proje geliştiricisidir; topluluk oluştuğunda gerçek isimle sahiplik atanır.

| ID | Risk | Olasılık / etki | Önlem ve kanıt görevi |
| --- | --- | --- | --- |
| R-01 | Global developer path tam Xcode'u göstermiyor | Düşük / düşük | DM-001 tamamlandı; komutlarda doğrulanmış `DEVELOPER_DIR` kullanılıyor, global seçim değiştirilmedi |
| R-02 | NSWorkspace accepted ama kaynak hazır değil | Yüksek / orta | Doğru ürün metni; DM-002/008/016 |
| R-03 | JSON yazma/kurtarma veri kaybı | Orta / yüksek | Atomik replace, sağlam backup, lock ve fault injection; DM-006/021 |
| R-04 | Timeout/iptal yarışında çift callback | Orta / yüksek | Complete-once, runID, fake clock; DM-010 |
| R-05 | App Sandbox veya TCC varsayımı yanlış | Orta / yüksek | Public API deneyi, en az izin, gerçek imzalı build; DM-002/028 |
| R-06 | Kısayol çakışması/tekrarlayan listener | Orta / orta | Tek kayıt otoritesi, unregister, OS hata state'i; DM-003/018 |
| R-07 | Yol/URL token'i log veya issue'ya sızar | Orta / yüksek | Redaction/sentinel test ve katkı rehberi; DM-023/027 |
| R-08 | Özellik kapsamı otomasyon motoruna büyür | Yüksek / yüksek | PRD dışı liste, aşamalı TODO; her görevde kapsam kontrolü |
| R-09 | OS sürümü ve cihaz erişimi eksik | Orta / orta | Gerçek destek beyanı, DM-026; test edilmeyeni başarılı sayma |
| R-10 | Yalnız açma profili yeterli talep bulmaz | Belirsiz / yüksek | DM-004/030 gerçek kullanım görüşmeleri |
| R-11 | İmzalama hesabı/sertifikası yok | Belirsiz / yayın engeli | DM-028 yerel hazırlığı bitir; resmi dağıtımı ayrı açık engel kaydet |
| R-12 | Bookmark dış diskte takılır veya taşımayı çözmez | Orta / orta | MainActor dışında çözüm, bütçe, yeniden seçme; DM-007/010 |
| R-13 | Ajan belgeyi uygulanmış özellik sanır | Orta / yüksek | STATUS gerçek durum, unchecked TODO, test kanıtı |
| R-14 | Ürün adı mevcut yazılımlarla veya markalarla karışır | Düşük / yüksek | Launchestra ön taramada tam çakışma vermedi; resmî benzerlik/sınıf taraması ve kalıcı kimlik göçü DM-027/028 |

## Yayın öncesi cevaplanacak sorular

- GitHub owner ve kesin repository adı hangisi olacak? Ürün adı Launchestra seçildi; DM-027'de yayın kimliği kesinleşir.
- MIT lisansında telif sahibi kim olacak? DM-027; standart LICENSE yazılmadan yayın kapısı kapanmaz.
- Kalıcı bundle identifier ve Developer ID takımı hangisi? DM-028; yerel test için yayımlanmış kimlik uydurulmaz.
- Güvenlik açıkları için özel bildirim kanalı hangisi? DM-027; hassas raporları public issue'ya yönlendirme.
- macOS 14 ve ikinci kararlı OS test cihazı sağlanabilecek mi? DM-026; yoksa destek beyanı yeniden karara bağlanır.

Bu soruların hepsini bugün kullanıcıya sorup belge hazırlığını durdurmak gerekmez. İlgili göreve gelince somut eksik ve etkisiyle ele alınır.

## Karar değişikliği yöntemi

Kararın neden değiştiğini, kullanıcı davranışına etkisini, veri/izin/test göçünü ve ilgili TODO'ları yaz. İlgili ADR'yi superseded olarak işaretleyip yeni ADR ekle. PRD, schema ve runner sözleşmesi arasında çelişki bırakma. Yeni dependency için lisans/uyum değerlendirmesi; yeni ayrıcalık için ürün gerekçesi gerekir.
