# DeskMode ajan talimatları

## Kapsam

DeskMode, Swift 6 + SwiftUI/AppKit ile geliştirilecek macOS 14+ menü çubuğu uygulamasıdır. İlk hedef Apple Silicon'dır. Proje kökü `/Users/furkankoc/Desktop/projects/DeskMode/` dizinidir. Komşu FlowBridge uygulaması kapsam dışıdır. DM-001–003 ve DM-005/006 uygulanmıştır; STATUS/TODO'da tamamlanmayan özellikleri varmış sayma.

## Çalışma

- Başlangıçta STATUS.md ve TODO.md'yi oku; verilen görevin bağımlılıklarını kontrol et.
- İlgili sözleşme belgelerini ihtiyaç oldukça oku. PRD kapsam, DATA-MODEL veri, EXECUTION-ENGINE yürütme için kaynaktır.
- Kullanıcı geliştirme istediğinde kapsam içindeki yerel değişiklik ve gerekli doğrulamaları tamamla; rutin tercihler için tekrar onay isteme.
- Model hedefi kullanıcının seçtiği GPT-5.6 Sol'dur. Uygulamanın içine LLM/API bağımlılığı ekleme.
- Bir görev veya yakın bağımlı küçük görev grubu üzerinde çalış. Gelecek sürüm özelliklerini kendiliğinden ekleme.
- Kullanıcı değişikliklerini koru. Kimlik, sertifika, depo adresi, ölçüm, başarılı test veya API davranışı uydurma.

## Teknik sınırlar

- Domain kodunu AppKit'ten ayır. UI MainActor üzerinde; dosya yazımı tek repository actor üzerinden yürüsün.
- MVP eylemleri yalnızca openApplication, openFolder, openURL. Shell/script, AppleScript, Accessibility, ekran kaydı ve otomatik tetikleyici MVP dışında.
- NSWorkspace başlatma kabulü hedef uygulamanın tamamen hazır olduğu anlamına gelmez.
- Bir anda tek run. İptal tamamlanmış harici işlemleri geri almaz; otomatik tekrar yoktur.
- Kullanıcı girdisini komut satırına birleştirme. URL'lerde yalnızca PRD'deki şemaları kabul et.
- JSON sürümünü ve yazma/kurtarma davranışını DATA-MODEL'e göre uygula. Bozuk veriyi sessizce sıfırlama.
- Kısayolları tek kayıt otoritesinden yönet; gizli klavye dinleme veya varsayılan global kısayol atama yapma.

## Tamamlama

Görev kabul kriterlerini ve değişen davranışın ilgili testlerini çalıştır. Gerekli kontroller geçince yeni kanıt gerektirmeyen tekrar test döngülerine girme. Kod değişiminde ilgili paketi/uygulamayı derle; ortam engelini açık yaz. Manuel testi yapılmış gibi işaretleme.

TODO durumunu, STATUS devrini ve davranış değiştiyse ilgili belgeyi güncelle. Sonuçta değişiklik, doğrulama ve kalan gerçek engeli belirt. Yayın, push veya başka kişilere mesaj gönderme bu dosyayla yetkilendirilmiş değildir; oturumda verilen kullanıcı yetkisine uy.
