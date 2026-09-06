# ADR-001 — Native macOS uygulaması

Tarih: 2026-09-05. Durum: kabul; DM-001–003 proje ve entegrasyon temeliyle doğrulandı.

## Bağlam

Ürün menü çubuğu, uygulama açma, kullanıcı seçimi ve ileride cihaz olaylarına dayanıyor. İlk kullanıcı MacBook sahibi; başka platform gereksinimi yok. Tek geliştiricinin küçük, anlaşılabilir bir kod tabanını sürdürebilmesi amaçlanıyor.

## Karar

Swift 6 dil modu, SwiftUI ve AppKit. Minimum macOS 14; ilk doğrulanacak architecture arm64. Xcode app projesi ve yerel Swift package. Domain saf Swift; platform adaptörleri ayrı target. İlk üçüncü parti aday yalnız kısayol kütüphanesi.

## Alternatifler

- Tauri/Rust: Çok platformlu çekirdek ihtiyacı olmadığı için ilk aşamada UI/platform köprüsü ve ek araç zinciri getirir.
- Electron: Web UI deneyimiyle başlayabilirdi; ancak ürünün native sistem entegrasyonu ağırlığı nedeniyle seçilmedi.
- Tek dev App target: Başlangıcı kolaylaştırır; motor/depolama test izolasyonunu zorlaştırdığı için küçük Core/Platform ayrımı tercih edildi.

Bu karşılaştırma performans benchmark'ı değildir. FlowBridge'in mevcut Rust mimarisi Launchestra için gereksinim oluşturmaz.

## Sonuç

Native SDK öğrenimi ve tam Xcode gerekir. macOS 13 desteği ilk sürümde yoktur. Intel ancak gerçek doğrulama sonrası ilan edilir. DM-001/002/003 araç ve API uyumunu kanıtlar; başarısız deney gerekçeli revizyon gerektirebilir.
