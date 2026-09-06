# DM-022 erişilebilirlik ve görsel inceleme kaydı

Tarih: 6 Eylül 2026. Cihaz: MacBook Pro Mac16,7, arm64, macOS 26.6.2 (25G83). Build: yerel imzalı Debug, macOS deployment target 14.0. İnceleme DM-024 XCUITest fixture'larıyla gerçek SwiftUI/AppKit penceresinde yapıldı; kişisel profil verisi kullanılmadı.

## Doğrulananlar

| Alan | Sonuç | Kanıt |
| --- | --- | --- |
| Klavye ana akışı | Geçti | ⌘N profil oluşturdu, ⇧⌘U URL satırı ekledi, ⌘S geçerli taslağı kaydetti; Escape aktif run'ı iptal etti. Sıra ve silme kontrolleri metinli standart Button olarak klavye odak zincirinde. Kullanıcıya atanmış global kısayol ortak runner'ı tetikliyor. |
| Erişilebilirlik ağacı | Geçti | Profil çalıştırma, onboarding, kurtarma, kaydetme, URL alanı, run sonucu ve iptal kontrolleri XCUITest accessibility ağacında etiket/identifier ile bulundu ve çalıştırıldı. Durum satırları simge ile metni birleştiriyor. |
| Renge bağlı olmayan durum | Geçti | Başarılı, hata, zaman aşımı, iptal ve atlama durumlarının her biri ayrı SF Symbol ve açıklayıcı metin taşıyor; renk yardımcı gösterim. |
| Uzun ve yerelleştirilmiş metin | Geçti | 60 karakterlik Türkçe profil adı editörde kullanılabildi. Onboarding Türkçe açık temada ve İngilizce koyu temada 820 × 620 başlangıç penceresinde görüntülendi; içerik dar yükseklikte ScrollView ile erişilebilir. |
| Açık/koyu tema | Geçti | Sistem renkleri, `.secondary`, `.bar` ve semantik uyarı renkleri kullanılıyor; onboarding TR açık ve EN koyu ekran görüntüleri gözle incelendi. Metin ve birincil düğmeler okunur, kesilme veya üst üste binme görülmedi. |
| Reduce Motion | Geçti | Ürün akışında özel animasyon, zaman tabanlı geçiş veya zorunlu hareket yok; sistem kontrollerinin varsayılan davranışı kullanılıyor. |

## Açık manuel kontroller

VoiceOver'ın gerçek sesli okuma sırası, Full Keyboard Access ile her bir sıra düğmesine teker teker Tab/Space erişimi ve minimum macOS 14 cihazındaki görünüm bu makinede manuel olarak yapılmadı. Otomatik accessibility ağacı ve klavye kısayolları geçti; bu üç kontrol DM-026 gerçek cihaz/release matrisinde açık kalır ve beta paketi için tamamlanmış sayılmaz.
