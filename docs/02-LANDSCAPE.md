# Alternatifler ve konumlandırma

İnceleme tarihi: 2026-09-06. Bu çalışma kısa bir alternatif taramasıdır; kapsamlı pazar araştırması, kullanıcı görüşmesi veya marka uygunluğu kanıtı değildir.

| Alternatif | Kaynakta görülen odak | Launchestra için çıkarım |
| --- | --- | --- |
| [Kero](https://kero.sh/) | Terminal merkezli projeler, kalıcı oturumlar, dosyalar ve Git | Kendi terminal çalışma alanını üretmek yerine mevcut uygulamaları açan küçük bir araç olarak konumlan |
| [AeroSpace](https://github.com/nikitabobko/AeroSpace) | macOS için döşemeli pencere yöneticisi | Pencere yönetimini ilk sürüme alarak ürün ve teknik kapsamı büyütme |
| [Quay](https://github.com/manustays/quay) | Yerel geliştirme servislerini menü çubuğundan başlatma/durdurma | Servis/process yönetimini ilk sürümde üstlenme |
| [DeskCue](https://deskcue.kr/) | Toplantı öncesi uygulama, dosya, klasör ve bağlantıları profil ile birlikte açma; çalışma alanını gizleme/geri yükleme | Açma profili odağında doğrudan güncel alternatif var; sade yerel kullanım, anlaşılır sonuç ve açık kaynak konumunu somutlaştır |
| Kullanıcının mevcut manuel rutini | Proje hipotezi; görüşmelerle incelenecek | Asıl kabul ölçütü aynı rutini daha az adımla tamamlamak |

Tablodaki konumlandırma önerileri bizim çıkarımlarımızdır. Rakipte belirli bir özelliğin hiç bulunmadığı veya Launchestra'nın ilk olduğu iddia edilmez.

## Yayın adı kararı

“DeskMode” adı boş değildir. [Apple App Store'daki DeskMode](https://apps.apple.com/us/app/deskmode-standing-desk-timer/id6781822294) masa aktivitesi ürünüdür ve Apple Silicon Mac uyumluluğu listeler. [Deskmode Suite](https://wordpress.org/plugins/deskmode-suite/) aktif bir WordPress yazılımıdır ve `deskmode.app` alanını kullanır. Bu ürünler Launchestra profil fikriyle aynı işlevi sunmasa da eski ad, yazılım ve Mac yüzeyinde karışıklık riski taşır.

Yakın işlevli [DeskCue](https://deskcue.kr/) da `Desk…` ailesinde güncel bir macOS ürünüdür. Bu nedenle `DeskMode` yayın adı olarak elendi ve kullanıcıya görünen ad **Launchestra** seçildi. İç proje/modül kimlikleri veri uyumluluğu için beta kimlik göçüne kadar korunur. Ön tarama hukuki uygunluk sonucu değildir; ayrıntı ve resmî arama kaynakları [DM-004 kaydındadır](16-USER-AND-NAME-VALIDATION.md).

## Savunulabilir ürün yönü

İlk sürümün avantajı özellik sayısı değil, kolay profil oluşturma ve anlaşılır sonuç bildirimi olmalıdır. V0.2'de yerel dosya yollarını paylaşmadan profil şablonu aktarımı; v0.3'te monitör bağlı olduğunda kullanıcıya doğru profili önerme ürün kimliğini güçlendirebilir. Bu yönlerin talep gördüğü henüz kanıtlanmadı.

## Yapılacak doğrulama

- DM-004: Hedef kullanıcıların mevcut araçlarını ve neden yeterli/yetersiz bulduklarını kaydet.
- DM-004: Launchestra yayın adı seçildi; beş gerçek görüşmeyi tamamla.
- İlk beta sonrası: En çok tekrar kullanılan üç profil tipini görüşmelerden çıkar.
- Talep yalnızca pencere yerleşimine çıkarsa mevcut araç entegrasyonu mu yoksa ürün yönü değişikliği mi gerektiğini karar kaydına al.

Rakip yıldız sayıları, fiyatları ve kullanıcı sayıları bu kararı vermek için gerekli olmadığından kaydedilmedi.
