# Kullanıcı deneyimi sözleşmesi

## Arayüz yaklaşımı

Yerel macOS bileşenleri, sistem yazı tipi ve açık/koyu tema kullanılır. Birincil işlem “Profili çalıştır”; profil düzenleme ayrı pencerededir. Menü popup genişliği 340 pt; yönetim penceresi 820 × 620 pt başlar, içerik minimum 760 × 560 pt ve pencere yeniden boyutlanabilir. Onboarding ve kurtarma içeriği dar yükseklikte kaydırılır.

## Ekranlar

| Ekran | İçerik | Durumlar |
| --- | --- | --- |
| Onboarding | Ürün amacı, İlk profili oluştur, menü simgesinin konumu | İlk açılış, kapatma, tekrar açma |
| Menü | Profil listesi, kısayollar, son run özeti, Profilleri yönet, Ayarlar, Çıkış | Boş, hazır, çalışıyor, kısmi hata, depolama sorunu |
| Profil yöneticisi | Solda profiller; sağda isim, hata politikası, eylemler, kısayol | Seçim yok, yeni taslak, kirli taslak, kaydetme hatası |
| Eylem editörü | Tür seçimi ve türe özgü alanlar | Eksik, geçerli, bulunamayan kaynak |
| Sonuç paneli | Eylem sırası, durum, süre, hata, Düzenle | Başarılı, kısmi, başarısız, iptal, timeout |
| Ayarlar | Girişte başlat, hakkında, sürüm, gizlilik, veri klasörünü göster | Kayıtlı, izin/onay bekliyor, devre dışı, hata |
| Kurtarma | Bozuk dosya açıklaması, yedek tarihi, Yedeği kullan, Yeni yapılandırma | Doğrulanmış yedek var/yok, uyumsuz sürüm |

## Ana akış

1. İlk açılışta uygulama kendiliğinden örnek profil çalıştırmaz. Kullanıcı “İlk profilini oluştur” seçer.
2. “Çalışma” adını yazar. “Eylem ekle” ile uygulama, klasör ve URL seçer.
3. Eylemler ekranda açık sırayla görünür. Sürükle-bırak yanında Yukarı/Aşağı komutları bulunur.
4. Kaydet başarılıysa taslak kapanabilir ve menü güncellenir. Kaydetme hatası taslağı korur.
5. Menüden profile tıklanınca kaydedilmiş sürüm çalışır. Taslak değişiklikler çalıştırmaya karışmaz.
6. İlerleme `2/3 — Çalışma açılıyor` biçiminde profil adını taşır. “İptal” sıradaki eylemleri durdurur.
7. Sonuç özeti “3 açma isteği kabul edildi” veya “2 kabul edildi, 1 başarısız” der. Web sayfası yüklendi/ortam tamamen hazır iddiası yoktur.

## Düzenleme davranışı

Kaydet/İptal açık düğmelerdir. Kirli taslakla başka profile geçiş veya pencereyi kapatma: Kaydet, Değişiklikleri bırak, Düzenlemeye dön. Silme kullanıcıya profil adıyla doğrulatılır; geri dönüşü olmayan dosya silme yapılmaz, yalnız uygulama kaydı kaldırılır. Çoğaltma yeni profil ve eylem UUID'leri üretir, ada uygun bir kopya eki ekler ve kısayolu boşaltır.

Çalışan profil üzerinde değişiklikler sonraki run'a uygulanır. Çalışan profilin silinmesi run bitene kadar devre dışıdır; başka profil düzenlenebilir. Başlat düğmeleri tüm profiller için run boyunca kapalıdır, kısayol çağrıları da aynı busy sonucunu verir.

## Hatalar ve metinler

| Durum | Kullanıcı metni | Çözüm |
| --- | --- | --- |
| Uygulama eksik | “Bu uygulama bulunamadı.” | Uygulamayı yeniden seç |
| Klasör eksik/erişim yok | “Klasör açılamadı. Taşınmış veya erişim kısıtlanmış olabilir.” | Klasörü yeniden seç |
| Geçersiz URL | “http:// veya https:// ile başlayan geçerli bir adres gir.” | Alanı düzelt |
| Kısayol meşgul | “Bu kısayol kullanılamıyor.” | Başka kısayol seç |
| Zaman aşımı | “Açma isteğinin sonucu zamanında alınamadı. Kaynak yine de açılmış olabilir.” | Sonucu kontrol et; yeniden çalıştır kullanıcı kararı |
| Run iptal | “Kalan adımlar iptal edildi. Açılan kaynaklar açık kalır.” | Profili düzenle veya yeniden çalıştır |
| Depolama hatası | “Değişiklikler kaydedilemedi. Taslağın korunuyor.” | Tekrar kaydet, kullanılabilir alanı kontrol et |
| Uyumsuz veri | “Bu yapılandırma daha yeni veya desteklenmeyen bir biçim kullanıyor.” | Uyumlu uygulama sürümü kullan; dosyayı ezme |

Eylem etiketi kullanıcı arayüzünde gösterilebilir. URL query/token değerleri sonuç özetinde ve bildirimde görünmez. Ayrıntılı düzenleme ekranında kullanıcının kendi girdiği URL görünür.

## Klavye, VoiceOver ve yerelleştirme

Tab sırası görsel sırayı izler; kaydet, iptal, sil ve sıra değiştirme klavyeyle mümkündür. Simgesiz anlam taşımayan düğmelere erişilebilir ad eklenir. VoiceOver her eylemi adı ve durumu ile okur. İlerleme duyuruları yalnız adım değişiminde yapılır. Durumlar simge/metin ile ayrılır; sadece kırmızı/yeşil kullanılmaz. Reduce Motion ayarına uyulur.

Metinler String Catalog içinde anahtarlarla tutulur; FR/UX metinleri kod içinde çoğaltılmaz. Profil adları ve kullanıcı etiketleri çevrilmez. Tarih/süreler locale ile biçimlenir. Menüde uzun ad kesilebilir, tam adı erişilebilirlik etiketi ve editörde bulunur.

DM-020–022 uygulaması ilk açılışta örnek profil, hazır eylem, global kısayol veya izin isteği oluşturmadan rehberi gösterir. “Şimdilik Geç” ve “İlk Profilini Oluştur” seçimleri tamamlanma tercihini saklar; rehber menü ve Ayarlar içinden yeniden açılır. Profil oluşturma, URL ekleme, kaydetme ve iptal için sırasıyla ⌘N, ⇧⌘U, ⌘S ve Escape sağlanır; sıra düğmeleri standart klavye odağına katılır. Çalıştırma kullanıcı tanımlı global kısayol veya odaklanabilir düğme, iptal Escape ile kullanılabilir.

Kurtarma ekranı ana dosyanın eksik, bozuk veya desteklenmeyen sürüm olmasını ayrı metinlerle açıklar. Geçerli yedek yalnız kullanıcı “Doğrulanmış Yedeği Kullan” dediğinde kurulur. Yeni yapılandırma ayrı onay ister; özgün veri recovery kopyasına yazılamazsa işlem durur. Bu durumda profil çalıştırma ve düzenleme kapalı kalır.

## Menü yaşam döngüsü

Son pencere kapanınca uygulama çalışır. Çıkış sırasında run varsa “Çıkış kalan adımları durdurur” açıklamasıyla çıkış/geri dön sunulur. Yeniden açılış yarım kalmış run'ı devam ettirmez. Dock simgesi olmadan editörü öne getirme ve Cmd+Q davranışı DM-002'de gerçek cihazda doğrulanır.
