# Ürün ve kullanıcı analizi

Durum: tasarım hipotezleri; çevrimiçi ad taraması yapıldı, gerçek kullanıcı görüşmeleri 0/5. Ayrıntı: [kullanıcı ve ad doğrulaması](16-USER-AND-NAME-VALIDATION.md).

## Problem

MacBook kullanıcıları masa, ev ve hareket hâlindeki çalışma arasında geçiş yaparken aynı uygulama, klasör ve bağlantıları tekrar açıyor. İşin maliyeti tek bir uygulamayı açmak değil, doğru kaynakları hatırlayıp hazırlama adımlarını tekrarlamak. Launchestra bu başlangıç rutinini kaydedilebilir bir profile dönüştürür.

## Birincil kullanıcı

Birden fazla proje veya müşteriyle çalışan geliştirici/tasarımcı. Gün içinde en az iki çalışma bağlamı kullanır. Mevcut editörünü, tarayıcısını ve dosya düzenini korumak ister. Script yazmadan bir açılış sırası tanımlamayı önemser.

İkincil kullanıcı: ders/araştırma kaynaklarını tekrar açan öğrenci; toplantı ve üretim araçlarını ayrı kullanan uzaktan çalışan. İlk sürüm pazarlaması birincil kullanıcıya odaklanır.

## İşler ve senaryolar

| Kullanıcı işi | Örnek | İlk sürümün karşılığı |
| --- | --- | --- |
| Bir projeye başlamak | Safari, Finder klasörü, görev panosu | Üç eylemli profil |
| Derse hazırlanmak | Not uygulaması, ders klasörü, kaynak URL'si | İkinci profil |
| Tekrarlanan adımları hatırlamamak | Her sabah aynı kaynakları açmak | Menüden veya atanmış kısayoldan çalıştırma |
| Sorunun nerede olduğunu görmek | Taşınmış klasör açılmıyor | Eylem bazında hata ve yeniden seçme |

## Değer önerisi

“Çalışmaya başlamak için kullandığın uygulamaları, klasörleri ve bağlantıları bir kez seç; sonra tek profilden aç.” Başlangıç vaadi budur. Çalışma oturumunun eksiksiz geri yüklenmesi, açık belge durumunun saklanması veya tüm uygulamaların kontrolü vaat edilmez.

## Doğrulama planı

DM-004 kapsamında 5 hedef kullanıcıdan, mevcut çalışma başlangıcını göstermesi istenir. Gerçek kişi/kurum isimleri rıza olmadan kaydedilmez. Sorular: Hangi adımlar tekrarlanıyor? Ne sıklıkta? Bugünkü çözüm nedir? Son unutulan adım neydi? Profili ertesi gün tekrar kullanır mı?

6 Eylül 2026 itibarıyla katılımcı görüşmesi yapılmadı. Çevrimiçi ürün/ad taraması görüşme yerine sayılmaz ve talebi doğrulamaz.

İlk prototip için önerilen karar eşiği: 5 kişiden en az 3'ü yardım almadan profil oluşturabilsin; en az 3'ü bir hafta içinde en az 3 farklı gün kullandığını bildirsin. Bunlar hedeflerdir, ölçülmüş sonuç değildir. Başarısızlıkta önce kurulum akışını ve hedef kullanıcıyı düzelt; özellik sayısını büyütme.

## Başarı ölçümü

Kullanıcının kendi eski rutini ile yeni profil akışı aynı kaynak seti üzerinde karşılaştırılır. Hazırlık süresi, yanlış açılan kaynak sayısı ve hatayı düzeltme süresi kaydedilir. Uygulama içine telemetri eklemek gerekmez; gönüllü görüşme ve yerel test notları yeterlidir. GitHub yıldızı temel ürün başarısı göstergesi değildir.

## Açık kaynak yaklaşımı

İlk katkılar: hata senaryoları, çeviriler, gerçek macOS uyumluluk raporları ve erişilebilirlik düzeltmeleri. Profil paylaşımı v0.2'ye, çalıştırılabilir eklenti sistemi ileri değerlendirmeye bırakılır. Gelir modeli ilk sürüm hedefi değildir; sürdürülebilirlik için ileride gönüllü sponsorluk değerlendirilebilir.
