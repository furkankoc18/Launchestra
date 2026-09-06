# Kullanıcı ve yayın adı doğrulaması

Durum tarihi: 2026-09-06. DM-004 araştırmasının çevrimiçi tarama kısmı tamamlandı; gerçek kullanıcı görüşmeleri 0/5 olduğu için görev tamamlanmış sayılmaz.

## Kanıt sınırı

Bu belge üç kanıt türünü ayrı tutar:

- **Doğrulanmış çevrimiçi bulgu:** Aşağıdaki bağlantılarda tarama tarihinde görülen ürün/ad kullanımı.
- **Ürün hipotezi:** Launchestra'nın hedef kullanıcısı ve sağlayacağı yarar; görüşmeler olmadan ölçülmüş talep değildir.
- **Bekleyen görüşme kanıtı:** Beş hedef kullanıcının kendi rutini ve prototip davranışı. Katılımcı yanıtı olmadan doldurulmaz.

## Elenen çalışma adı

| Bulgu | Kaynak | Etki |
| --- | --- | --- |
| “DeskMode - Standing Desk Timer” adlı ürün App Store'da yayında; iPhone/Apple Watch ürünü olmakla birlikte Apple Silicon Mac ve macOS 14 uyumluluğu listeleniyor | [Apple App Store](https://apps.apple.com/us/app/deskmode-standing-desk-timer/id6781822294), [ürün sitesi](https://deskmodeapp.co.uk/) | Tam ad ve Mac dağıtım yüzeyi çakışıyor; yayın adı olarak yüksek karışıklık riski |
| “Deskmode Suite” adı aktif bir WordPress ürünü ve `deskmode.app` alan adı tarafından kullanılıyor | [WordPress.org](https://wordpress.org/plugins/deskmode-suite/), [ürün sitesi](https://www.deskmode.app/) | Yazılım kategorisinde ikinci güncel kullanım; alan adı da müsait değil |
| “DeskMode” adı başka bir bulut/RDP hizmetinde kullanılıyor | [DeskMode Cloud](https://deskmode.github.io/deskmode/) | Arama sonucu ve depo adı gürültüsü oluşturuyor |
| Resmî marka veri tabanları metin/benzerlik ve ülke bazında ayrıca aranmalı | [WIPO Global Brand Database](https://www.wipo.int/en/web/global-brand-database), [EUIPO TMview](https://www.tmdn.org/tmview/), [USPTO arama rehberi](https://www.uspto.gov/trademarks/search/federal-trademark-searching) | Bu kısa tarama hukuki marka uygunluğu veya tescil görüşü değildir |

Bu bulgular nedeniyle `DeskMode` yayın adı olarak elendi. İç Xcode hedefi, Swift modülleri ve `Application Support/DeskMode` yolu mevcut geliştirme ve kullanıcı verisini kırmamak için geçici teknik kimlik olarak korunur.

## Seçilen ad: Launchestra

**Karar tarihi:** 2026-09-06. Kullanıcıya görünen ürün ve yayın adı **Launchestra**'dır. Ad, “launch” ve “orchestra” sözcüklerini birleştirir: bir profil içindeki uygulama, klasör ve web adreslerini tanımlı sırayla açan ürün davranışını anlatır. Türkçe ve İngilizce ürün metninde aynı yazım kullanılır.

| Ön kontrol | 2026-09-06 bulgusu | Sınır |
| --- | --- | --- |
| [Apple iTunes Search API](https://itunes.apple.com/search?term=Launchestra&entity=macSoftware&country=us&limit=200); `macSoftware`, ABD/Türkiye/Birleşik Krallık/Almanya/Kanada/Avustralya | Tam adı `Launchestra` olan sonuç bulunmadı | App Store kaydı veya gelecekteki kullanım garantisi değildir |
| [GitHub kullanıcı araması](https://github.com/search?q=Launchestra&type=users) ve [repository araması](https://github.com/search?q=Launchestra&type=repositories) | Tam adlı kullanıcı veya repository bulunmadı | Gizli, dizine alınmamış veya sonradan açılacak depoları kapsamaz |
| [npm](https://www.npmjs.com/search?q=Launchestra), [PyPI](https://pypi.org/search/?q=Launchestra) ve [crates.io](https://crates.io/search?q=Launchestra) | Tam adlı paket bulunmadı | Bütün yazılım ekosistemlerini kapsamaz |
| DNS: `launchestra.com`, `.app`, `.dev`, `.io` | Tarama anında çözümlenen kayıt bulunmadı | Alan adının satın alınabilir olduğunu veya hak doğurduğunu kanıtlamaz |
| Genel web tam ad ve marka sorgusu | Dizine alınmış güncel tam ad kullanımı bulunmadı | Benzer yazımlar ve hukuki sınıflar ayrıca incelenmelidir |

Bu ön tarama isim seçmek için yeterli ayırt edicilik sinyali verdiği için görünen uygulama adı ve ürün paketi `Launchestra.app` adına geçirildi. Kalıcı bundle ID ve repository adı DM-027/028 sırasında taşınacak. Resmî benzerlik ve ilgili mal/hizmet sınıfı taraması yapılmadan marka tesciline uygunluk sonucu verilmez; başvuru öncesinde [WIPO](https://www.wipo.int/en/web/global-brand-database), [EUIPO TMview](https://www.tmdn.org/tmview/) ve [USPTO](https://www.uspto.gov/trademarks/search/federal-trademark-searching) üzerinde uzman incelemesi gerekir.

## Mevcut çözüm araştırması

Kaynaklı alternatifler ve ürün ayrımları [LANDSCAPE](02-LANDSCAPE.md) belgesindedir. Çevrimiçi tarama, insanların bu araçları neden seçtiğini veya Launchestra profilini tekrar kullanıp kullanmayacağını kanıtlamaz. Bu sorular görüşmeyle ölçülür.

## Görüşme protokolü

Hedef: gün içinde en az iki çalışma bağlamı kullanan geliştirici, tasarımcı, öğrenci veya uzaktan çalışan beş kişi. Katılımcı kendi başlangıç rutinini gösterir; yönlendirici özellik listesi okunmaz.

1. Son çalışma başlangıcında hangi uygulama, klasör ve bağlantıları açtığını göster.
2. Bu rutini haftada kaç gün ve kaç farklı bağlam için tekrarlıyorsun?
3. Bugün bunu nasıl hatırlıyor veya hızlandırıyorsun?
4. En son unuttuğun ya da yanlış açtığın kaynak neydi ve etkisi ne oldu?
5. Integration Lab değil, ilk profil prototipi hazır olduğunda yardım almadan bir profil oluştur.
6. Bir haftalık gönüllü denemede kaç farklı gün kullandığını ve neden kullanmadığın günleri anlat.

Kişi/şirket adı, özel dosya yolu, müşteri URL'si veya ekran içeriği kaydedilmez. Anonim `P-01`…`P-05` kimliği kullanılır.

| Katılımcı | Rol/bağlam | Tekrarlanan adımlar ve sıklık | Mevcut çözüm | Son unutulan adım | Yardımsız profil | 1 haftada kullanım | Durum |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P-01 | Bekliyor | Bekliyor | Bekliyor | Bekliyor | Bekliyor | Bekliyor | Görüşülmedi |
| P-02 | Bekliyor | Bekliyor | Bekliyor | Bekliyor | Bekliyor | Bekliyor | Görüşülmedi |
| P-03 | Bekliyor | Bekliyor | Bekliyor | Bekliyor | Bekliyor | Bekliyor | Görüşülmedi |
| P-04 | Bekliyor | Bekliyor | Bekliyor | Bekliyor | Bekliyor | Bekliyor | Görüşülmedi |
| P-05 | Bekliyor | Bekliyor | Bekliyor | Bekliyor | Bekliyor | Bekliyor | Görüşülmedi |

## Karar eşiği

Beş kişiden en az üçünün yardım almadan profil oluşturması ve en az üçünün bir hafta içinde üç farklı gün kullanması hedeflenir. Şu an pay `0/5`; bu başarısız ürün sonucu değil, ölçüm yapılmadığı anlamına gelir. Katılımcı erişimi sağlanana kadar DM-004 bekler; DM-005 ve sonraki teknik görevler ilerleyebilir.
