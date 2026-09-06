# Katkı rehberi

Launchestra'nın Xcode hedefi, Swift modülleri ve veri dizini uyumluluk için `DeskMode` iç adını korur. Katkıdan önce [START_HERE](START_HERE.md), [PRD](docs/03-PRD.md) ve ilgili [TODO](TODO.md) maddesini okuyun.

## Çalışma biçimi

Bir PR tek kullanıcı davranışını veya belirli bir hatayı tamamlamalıdır. İlgisiz refactor ve v0.2+ özellikleri aynı değişikliğe eklemeyin. Swift kodu/isimleri İngilizce; UI metinleri TR/EN String Catalog içinde; teknik belgeler Türkçe tutulur.

Önerilen akış: ilgili görevi seç → mevcut sözleşmeyi kontrol et → uygula → ilgili test ve build → TODO/STATUS ve davranış belgesini güncelle → değişikliği kanıtıyla sun. Build komutları [DEVELOPMENT](docs/10-DEVELOPMENT.md) içinde; proje oluşturulmadan çalıştıkları iddia edilmez.

## PR açıklaması

Somut sorunu ve yeni davranışı yazın. Örneğin “Profil çalışırken ikinci tıklama ikinci bir tarayıcı sekmesi açıyordu; şimdi busy sonucu dönüyor.” Görev/FR ID'lerini, çalıştırılmış kontrolleri ve yapılmamış platform testlerini ekleyin. Tasarım kararı değişiyorsa ADR ve ilgili sözleşmeyi birlikte güncelleyin. Hazır şablon: [PR_TEMPLATE](docs/templates/PR_TEMPLATE.md).

## Test beklentisi

Veri modeli, depolama, runner veya kısayol yaşam döngüsü değişikliği gerçek hata biçimini yakalayan test gerektirir. Yalnız etiket/metin değişiminde kodu taklit eden yeni unit test yazmak gerekmez; ilgili UI doğrulaması yeterlidir. UI değişikliğinde ekranı gerçekten açıp inceleyemediyseniz bunu belirtin.

## Gizlilik ve güvenlik

Issue, ekran görüntüsü ve fixture'larda gerçek proje yollarını, URL query token'larını, bookmark verisini ve signing sırlarını paylaşmayın. Hata şablonu sentetik veri kullanır. Güvenlik açığı için [SECURITY](SECURITY.md) yönergesini izleyin; özel kanal yayın öncesinde tamamlanacak.

## Bağımlılık ve lisans

Yeni dependency bir kullanıcı/teknik ihtiyacını karşılamalı; lisans, bakım, macOS/Swift tabanı ve sürüm kilidi incelenmelidir. Launchestra kaynak kodu [MIT Lisansı](LICENSE) ile sunulur. Dağıtılan paket KeyboardShortcuts lisans bildirimini [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md) ile taşır. Başka projeden kod kopyalanırsa ilgili lisans yükümlülükleri incelenip korunur; açık kaynak etiketi tek başına kopyalama izni varsayımı değildir.

İletişimde yeniden üretilebilir kanıta odaklanın, kişisel saldırı veya kimlik bilgisi paylaşmayın. Repo yönetim adresi ve bakımcı rolleri yayın hazırlığında belirlenecektir.
