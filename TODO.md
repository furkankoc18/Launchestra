# Launchestra geliştirme görevleri (`DeskMode` iç projesi)

Durum tarihi: 2026-09-07. DM-001–003 ile DM-005–024 tamamlandı. DM-004 ad seçimi tamamlandı; gerçek kullanıcı erişimi bekliyor.

Kullanım: `[ ]` yapılmadı, `[x]` kabul kriterleri kanıtlandı. Devam eden/engelli görev için ilgili başlığın altına kısa durum notu yaz. Tahminler takvim değil göreli büyüklük: S küçük, M orta, L birkaç alt oturum gerektirebilir. Tek görev gereksiz büyürse aynı ID altında somut alt maddelere böl.

Her görev için ortak teslim koşulu: ilgili kontrollerin gerçek sonucu, STATUS devri, değişmiş sözleşmenin güncellenmesi. “Test geçti” ancak komut gerçekten çalıştıysa yazılır. Uygulama testleri [test planındaki](docs/09-TEST-PLAN.md) ID'lerle eşleşir.

## M0 — Başlangıç ve teknik deneyler

### DM-001 — Proje ve araç zinciri başlangıcı

- [x] Tamamlandı — Önkoşul: yok. Boyut: M. İlgili: FR-01.
- **Çıktı:** App/Xcode hedefleri, paylaşılan DeskMode scheme, DeskModeKit Core/Platform paketleri ve temel test hedefleri; gerçek araç sürümü kaydı.
- **Kabul:** macOS 14 deployment target ve Swift 6 açık. App derlenir; saf paket testi koşar. Bundle/team alanları sahte yayın kimliği gibi sunulmaz. Tam Xcode engelinde yapılabilir paket işleri tamamlanır, app build kutusu açık kalır.
- **Doğrulama:** [DEVELOPMENT](docs/10-DEVELOPMENT.md) komutları; schema/kod özellikleri henüz tamamlanmış diye işaretlenmez.
- **Kanıt (2026-09-05):** arm64 Debug app build'i ve 13 paket testi geçti. macOS 14 deployment target, Swift 6 modu, paylaşılan scheme, Core/Platform ve UI test hedefleri gerçek Xcode ile doğrulandı.

### DM-002 — NSWorkspace, bookmark ve menü teknik deneyi

- [x] Tamamlandı — Önkoşul: DM-001 app hedefi. Boyut: M. İlgili: FR-01/04/05/06.
- **Çıktı:** Üç açma isteği ve yaşam döngüsünü kanıtlayan minimal uygulama deneyi; MACOS-INTEGRATIONS'a gerçek bulgular.
- **Kabul:** Kapalı/açık app, Finder klasörü, URL, taşınmış bookmark ve pencereyi kapattıktan sonra çalışan menü test edilir. Sonuç kabulü ile hazır olma ayrılır. Shell fallback kullanılmaz.
- **Doğrulama:** OS-01/02/03'ün deney alt kümesi; OS/Xcode ve kullanılan gerçek API imzaları kayıtlı.
- **Kanıt (2026-09-05):** gerçek Launch Services smoke testi Safari'yi kapalı ve açık durumda, özel karakterli geçici klasörü Finder'da, localhost ve HTTPS URL'lerini açtı. Taşınan Unicode klasör bookmark testi ile çözüldü. İmzalı UI testi pencereyi kapatıp yeniden oluştururken menü ajanı sürecinin çalıştığını doğruladı. Dış disk ve erişim reddi daha sonraki tam OS-02 matrisi için açık bırakıldı.

### DM-003 — Kısayol bağımlılığı ve kayıt deneyi

- [x] Tamamlandı — Önkoşul: DM-001. Boyut: M. İlgili: FR-09.
- **Çıktı:** KeyboardShortcuts'ın doğrulanmış sabit sürümü, lock dosyası ve JSON binding için küçük adaptör kanıtı.
- **Kabul:** Arka planda tek tetikleme, çakışma, rebind/unregister, basılı tutma ve Türkçe klavye kontrolü. Geçerli seçilen sürümde custom storage API'si derlenir. İlk açılışta kısayol atanmaz.
- **Doğrulama:** KB-01 deneyleri; dependency lisans/sürümü DEVELOPMENT'a kayıt.
- **Kanıt (2026-09-05):** KeyboardShortcuts 3.0.1 tam sürüme ve revision'a kilitlendi; custom Binding recorder derlendi. JSON round-trip, atanmamış durum, duplicate, rebind/remove, save failure, OS registration failure ve basılı tuş testleri geçti. Türkçe-QWERTY-PC düzeninde Finder öndeyken `⌘⌥⌃⇧K` gerçek global event ile tam bir kez tetiklendi; `⌘⌥⌃⇧Q` bu sistemde OS çakışması verdi.

### DM-004 — Kullanıcı ve isim doğrulaması

- [ ] Tamamlandı — Önkoşul: yok. Boyut: M; gerçek kullanıcı erişimine bağlı. İlgili: ürün hipotezi.
- **Çıktı:** 5 hedef kullanıcı görüşmesinin anonim özeti, mevcut çözüm ve çalışma adı araştırması.
- **Kabul:** Gerçek kanıt/varsayım ayrılır; isim uygunluğu kesin garanti gibi sunulmaz. Kullanıcı erişimi yoksa görev engelli kalır; teknik geliştirme sürer. İnsanlara mesaj gönderme için ayrıca oturum yetkisi gerekir.
- **Doğrulama:** PRODUCT-ANALYSIS karar eşiği ve LANDSCAPE güncellemesi.
- **İlerleme/engel (2026-09-06):** Çevrimiçi ürün, alan adı ve resmî marka arama kaynakları tarandı. `DeskMode` yayın adı olarak elendi; kullanıcıya görünen yayın adı **Launchestra** seçildi. App Store'un altı bölgesi, GitHub, npm, PyPI, crates.io ve temel alan adlarında yapılan ön taramada tam ad kullanımı bulunmadı; bu hukuki marka görüşü değildir. Görüşme sayısı 0/5'tir. Katılımcı/yanıt olmadan anonim görüşme özeti üretilemeyeceği için görev açık; protokol ve kanıt [DM-004 kaydında](docs/16-USER-AND-NAME-VALIDATION.md).

## M1 — Model, depolama ve motor

### DM-005 — Domain modeli ve validasyon

- [x] Tamamlandı — Önkoşul: DM-001 paket hedefi. Boyut: M. İlgili: FR-02/03/06/10.
- **Çıktı:** ProfileStore/Profile/ActionKind/ShortcutBinding tipleri, açık Codable ve pure validator.
- **Kabul:** DATA-MODEL örneği decode olur; unknown field/type/version reddedilir; kapasite, Unicode isim ve URL kuralları uygulanır. Tipler AppKit import etmez.
- **Doğrulama:** UT-01–04; sınır ve olumsuz fixture'lar.
- **Kanıt (2026-09-06):** Açık discriminator'lı bütün v1 tipleri, katı Codable ve saf validator eklendi. DATA-MODEL içindeki JSON doğrudan testte decode/validate/round-trip edildi. Bilinmeyen alan/tür, eksik alan, yeni schema, kapasite, UUID, Unicode ad, tarih, URL/port, app/folder ve shortcut sınır testleri geçti; Core yalnız Foundation kullanır.

### DM-006 — Güvenli JSON repository

- [x] Tamamlandı — Önkoşul: DM-005. Boyut: L. İlgili: FR-10.
- **Çıktı:** JSONProfileRepository actor, revision/fingerprint kontrolü, writer lock, atomik temp/backup/replace.
- **Kabul:** İlk create ve sonraki replace ayrı işler. Backup yalnız doğrulanmış ana veriden üretilir. Hata kaydedildi sanılan UI state üretmez; ikinci writer yazamaz. Geçici test dizini kullanılabilir.
- **Doğrulama:** ST-01/02/05; yazmanın her kritik noktasına fault injection.
- **Kanıt (2026-09-06):** `JSONProfileRepository` actor; 10 MiB okuma kapısı, revision ve SHA-256 fingerprint kontrolü, süreç içi + advisory writer lock, fsync edilmiş benzersiz temp, doğrulanmış backup ve atomik create/replace uygulandı. İlk/ikinci kayıt, revision/dış değişiklik, ikinci writer, bozuk main/backup ve sekiz pre-commit hata noktası test edildi; hatalarda eski main korundu.

### DM-007 — Bookmark çözümü ve kaynak onarma

- [x] Tamamlandı — Önkoşul: DM-002, DM-005/006. Boyut: M. İlgili: FR-05/10.
- **Çıktı:** FolderReference oluşturma/çözme/yenileme; başarısız çözüm için typed error.
- **Kabul:** Taşınmış klasör mümkünse bookmark'tan çözülür; stale yenileme revision kontrollüdür. lastKnownPath'a sessiz fallback yok. Normal bookmark sandbox/TCC izni gibi yorumlanmaz.
- **Doğrulama:** Geçici klasör entegrasyon testi ve OS-02; kişisel klasörlere test yazımı yok.
- **Kanıt (2026-09-06):** `FolderReferenceService` actor normal bookmark oluşturma/çözme ve typed hata ayrımını uyguluyor. Geçici dizin taşıma testi bookmark'ın yeni konumu buldu; bozuk bookmark mevcut `lastKnownPath` olsa da fallback yapmadı. Sahte stale bookmark yenilemesi repository'ye store revision 7 ile gönderildi ve revision 8 olarak commit edildi.

### DM-008 — Tipli sistem açma adaptörü

- [x] Tamamlandı — Önkoşul: DM-002, DM-005, DM-007. Boyut: M. İlgili: FR-04/05/06/13.
- **Çıktı:** Application resolver, URL allowlist ve MainActor WorkspaceDispatcher.
- **Kabul:** Üç izinli action gerçek public API ile açılır; uygulama bulunamazsa typed error. Callback yalnız accepted/rejected kanıtı üretir; URL fetch yapılmaz. Shell ve AppleScript yok.
- **Doğrulama:** Fake API eşleme testleri ve OS-01/02/03 smoke; log privacy kontrolü.
- **Kanıt (2026-09-06):** MainActor `WorkspaceDispatcher`, ayrı bookmark actor'ı ve merkezi HTTP/HTTPS allowlist ile üç public açma API'sini uyguluyor. Sahte `WorkspaceClient` testleri kabul/red, bulunamayan uygulama, erişim hatası ve URL reddini sabit hata kodlarına eşledi; hata çıktısında sentetik hassas yol bulunmadı. Önceki opt-in OS-01/02/03 Launch Services smoke kanıtı geçerlidir; bu turda kullanıcı uygulamalarını yeniden açmamak için tekrar çalıştırılmadı.

### DM-009 — Runner ve olay sözleşmesi

- [x] Tamamlandı — Önkoşul: DM-005. Boyut: L. İlgili: FR-07/08.
- **Çıktı:** ProfileRunner actor, immutable snapshot, busy kilidi, preflight, sıralı action ve RunEvent/Result.
- **Kabul:** Continue/stop kaynak/runtime hata ayrımı EXECUTION-ENGINE ile aynı; disabled skip; aynı anda tek run; terminal olay bir kez. Testler sahte dispatcher kullanır.
- **Doğrulama:** EX-01/02/03/06/07. Gerçek platforma bağlanma DM-015'te.
- **Kanıt (2026-09-06):** `ProfileRunner` actor immutable `Profile` snapshot, await öncesi global busy kilidi, tüm etkin kaynaklar için preflight, array sıralı tek dispatch, disabled/policy skip ve sıralı `RunEvent` akışı üretir. Continue/stop preflight ve runtime hata matrisleri, 1 başarılı + 9 busy çağrı, terminal olay tekliği ve biten event stream sahte dispatcher testlerinde geçti. AppModel→Runner ürün bağlantısı daha sonra DM-015 ile tamamlandı.

### DM-010 — Timeout ve iptal güvenilirliği

- [x] Tamamlandı — Önkoşul: DM-008/009. Boyut: L. İlgili: FR-08/11.
- **Çıktı:** Clock/deadline adaptörü, callback/timer/cancel tek tamamlanma kapısı; preflight bütçesi.
- **Kabul:** 10s action/60s total; iptal sonrası yeni dispatch yok; hiç gelmeyen callback UI'ı sonsuza kadar bekletmez. Late callback ikinci run'ı değiştirmez; timer/listener temizlenir. Harici işlemin geri alındığı iddia edilmez.
- **Doğrulama:** EX-04/05/07; fake clock ve kontrollü yarış sıraları, gerçek süreyi bekleyen test yok.
- **Kanıt (2026-09-06):** `RunnerClock` ile preflight dahil 60 saniye toplam, eylem başına 10 saniye bütçe uygulanıyor. AsyncStream tabanlı tek-sonuç kapısı callback/timer/cancel yarışında ilk sonucu alıp timer ve iptal aboneliğini temizliyor. Kontrollü testler iptalin yeni dispatch'i durdurduğunu, callbacksiz action'ın anında sahte saatle timeout olduğunu ve geç callback'in sonraki run'ı değiştirmediğini doğruladı.

## M2 — Kullanılabilir dikey akış

### DM-011 — Uygulama kabuğu ve menü

- [x] Tamamlandı — Önkoşul: DM-001/002, DM-005/006. Boyut: M. İlgili: FR-01.
- **Çıktı:** Composition root, AppModel, MenuBarExtra ve tek yönetim penceresi.
- **Kabul:** Boş/profilli/depolama hatalı state gösterilir; ayarlar/editör yeniden açılır; son pencere kapanınca app sürer, Çıkış çalışır. View içinde OS/JSON işlemi yok.
- **Doğrulama:** UI-01 kabuk alt kümesi ve gerçek yaşam döngüsü smoke.
- **Kanıt (2026-09-06):** Ürün `MenuBarExtra` içeriği, MainActor `AppModel`, repository composition root ve profiller/ayarlar arasında geçen tek `ManagementWindowController` eklendi. Boş, profilli ve bozuk depolama durumları sentetik geçici depolarla gerçek app sürecinde görüldü; yönetim penceresi kapatılıp Ayarlar hedefiyle yeni pencere olarak açıldı ve menü ajanı çalışmayı sürdürdü. İlk kabuk aşamasında beş imzalı UI testi geçti; CRUD/editör alanları daha sonra DM-012/013 ile tamamlandı.

### DM-012 — Profil CRUD ve taslak kaydetme

- [x] Tamamlandı — Önkoşul: DM-006/011. Boyut: M. İlgili: FR-02.
- **Çıktı:** Oluştur, adlandır, çoğalt, sil, sırala; save/cancel taslak modeli.
- **Kabul:** Kopyanın profil/action UUID'leri yeni, shortcut null; isim benzersiz. Kirli taslak geçişleri UX'e uygun; kaydetme hatasında veri ve taslak korunur.
- **Doğrulama:** UT-02, ST-01, UI-01/02; restart sonrası sıra.
- **Kanıt (2026-09-06):** `ProfileDraft` kaydedilmiş snapshot'tan ayrıldı; oluşturma, yeniden adlandırma, benzersiz adlı ve kısayolsuz çoğaltma, silme ve kalıcı sıralama ürün arayüzüne bağlandı. Kirli taslakta hedef değiştirme ve pencere kapatma Kaydet/Bırak/Dön seçeneklerini kullanıyor; repository hatası draft'ı kapatmıyor. Yeni kimlik ve isim kuralları unit testte, sıra ise repository yeniden oluşturulduktan sonra storage testinde geçti.

### DM-013 — Eylem editörleri

- [x] Tamamlandı — Önkoşul: DM-005/007/012. Boyut: M. İlgili: FR-03/04/05/06.
- **Çıktı:** .app seçici, folder seçici, URL alanı; etiket, enable ve sıralama kontrolleri.
- **Kabul:** Yanlış tür dosyalar ve geçersiz URL kaydedilemez. Kaynak seçimi yalnız veri oluşturur, uygulama çalıştırmaz. Sürükleme yanında klavye ile sıra değişir; boş profil taslak olarak kalabilir.
- **Doğrulama:** UT-03 ve UI-01; dosya seçimini iptal etmek eski alanı bozmaz.
- **Kanıt (2026-09-06):** `.applicationBundle` filtreli uygulama seçici Bundle ID üretmeden girdiyi kabul etmiyor; klasör seçici bookmark oluşturuyor; her iki seçim de yalnız draft'ı değiştiriyor ve seçim iptalinde eski değeri koruyor. URL, etiket, etkinlik, kaldırma, sürükleme ve Yukarı/Aşağı sıralama kontrolleri eklendi. Eylem UUID/sıra korunumu ile URL reddi unit testte, URL ekleme ve kaydetme imzalı UI testinde geçti.

### DM-014 — Form hataları ve çalıştırma uygunluğu

- [x] Tamamlandı — Önkoşul: DM-012/013. Boyut: S. İlgili: FR-02/03/07.
- **Çıktı:** Inline validation, etkin eylem yoksa disabled run, açık hata politikası seçimi.
- **Kabul:** Alan hataları düzeltilebilir mesajlı; 50/30 kapasite sınırı kontrollü. Kaydedilmemiş taslak menü run'ına sızmaz.
- **Doğrulama:** Form view-model testleri, boş/disabled/limit UI senaryoları.
- **Kanıt (2026-09-06):** Ad/çakışma/etiket/kaynak/URL hataları editörde düzeltilebilir metinle gösteriliyor ve Kaydet'i kapatıyor; 50 profil ve 30 eylem sınırlarında ekleme düğmeleri kapanıyor. Hata politikası draft alanıdır. Menü yalnız repository'den yüklenmiş `profiles` snapshot'ını çalıştırıyor; etkin eylemi olmayan profilde başlatma kapalı. Limit ve form validator testleri geçti.

### DM-015 — Menüden profili çalıştırma

- [x] Tamamlandı — Önkoşul: DM-008/010/011/014. Boyut: M. İlgili: FR-07/08.
- **Çıktı:** AppModel→Runner→Workspace bağlantısı, menü ilerlemesi ve busy davranışı.
- **Kabul:** Kaydedilmiş üç eylemli profil sırayla dispatch edilir; art arda tıklama ikinci run yaratmaz; bütün başlatma girişleri aynı gate'i kullanır.
- **Doğrulama:** UI-03 fake sistem; gerçek üç eylemli smoke; EX-03.
- **Kanıt (2026-09-06):** MainActor `AppModel`, `ProfileRunner` ve `WorkspaceDispatcher` ürün composition root'unda bağlandı. Run token'ı ikinci başlangıcı bütün profil düğmelerinde kapatıyor; ilerleme menüde ve yönetim penceresinde ortak state'ten gösteriliyor. Sahte üç eylemli UI run testi geçti. Opt-in gerçek smoke Safari, geçici Finder klasörü ve yalnız `http://localhost:65535/deskmode-smoke` hedefini sıralı çalıştırıp üç accepted sonucu üretti; dış alan adı kullanılmadı.

### DM-016 — Sonuç ve hata paneli

- [x] Tamamlandı — Önkoşul: DM-015. Boyut: M. İlgili: FR-08/13.
- **Çıktı:** Sıralı action durumları, toplam özet, hata mesajı ve düzenlemeye dönüş.
- **Kabul:** accepted/partial/failed/timedOut ayrımı doğru; tam URL/query veya bookmark loga/özete sızmaz; gerçek hedef readiness iddiası yok. Son run yalnız bellekte.
- **Doğrulama:** UI-03 ve SEC-01; bütün terminal state'ler.
- **Kanıt (2026-09-06):** Sonuç görünümü snapshot sırasını, action durumunu, süreyi, terminal özeti ve profile dönüşü gösteriyor. Uygulama/klasör için güvenli ad, URL için yalnız host kullanılıyor; query, yol ve bookmark sunum modeline alınmıyor. `RunResult` terminal durum eşlemesi runner testlerinde, üç URL'li partial senaryosu ve query sentinel'inin marker/arayüz sonucuna sızmaması imzalı UI testinde geçti. Metin OS isteğinin kabulünü hedefin hazır olması olarak sunmuyor; son sonuç diske yazılmıyor.

### DM-017 — Kullanıcı iptali ve run sırasında düzenleme

- [x] Tamamlandı — Önkoşul: DM-010/015/016. Boyut: M. İlgili: FR-07/11.
- **Çıktı:** İptal düğmesi, çıkışta aktif run açıklaması, snapshot ile editör ayrımı.
- **Kabul:** Kalan adımlar iptal; açılan kaynaklar açık; çalışan profil silinemiyor. Sonraki run yeni kaydı kullanıyor; app restart otomatik devam ettirmiyor.
- **Doğrulama:** EX-04/06 ve UI-03; gecikmiş callback sonrası tekrar başlatma.
- **Kanıt (2026-09-06):** Menü ve yönetim penceresi aynı İptal eylemini kullanıyor; çıkış sırasında aktif run varsa kalan adımları durduracağı açıklanıp kullanıcı kararı alınıyor. Çalışan profil kimliği silme kontrolünü kapatırken draft düzenlemesi sonraki kayda devam ediyor; runner mevcut değer snapshot'ını koruyor ve aktif run state'i kalıcı depoya yazılmıyor. İptal UI testi ile kalan dispatch, snapshot, gecikmiş callback ve sonraki run testleri geçti.

## M3 — Günlük kullanım

### DM-018 — Profil kısayolları

- [x] Tamamlandı — Önkoşul: DM-003/012/015. Boyut: M. İlgili: FR-09.
- **Çıktı:** JSON taslağa bağlı recorder ve kaydedilmiş profil setinden listener yönetimi.
- **Kabul:** Duplicate reddi, yeniden atama/silme temizliği, OS kayıt hatası görünür. Save failure yeni binding'i etkinleştirmez. Kısayol aynı runner busy/cancel sözleşmesini kullanır.
- **Doğrulama:** KB-01/OS-04; tekrar açılışta kayıtlı bağlar.
- **Kanıt (2026-09-06):** Editördeki custom-binding recorder seçimi doğrudan profil taslağındaki `ShortcutBinding` alanına ve sürümlü JSON depoya yazıyor; ilk açılışta kısayol atanmıyor. Tek kayıt otoritesi kaydedilmiş profil setidir. Duplicate ve macOS sistem çakışması yazmadan önce görünür hata veriyor. Listener'lar iki aşamalı hazırlanıyor: repository kaydı başarısız olursa önerilen bağ hiç etkinleşmiyor ve eski listener çalışmayı sürdürüyor; başarılı kayıtta rebind/remove temizliği yapılıyor. Yeniden yüklenen bağın Finder öndeyken gerçek global `⌘⌥⌃⇧K` olayıyla ürünün ortak `AppModel.run` yolunu tam bir kez tetiklediği imzalı UI testinde doğrulandı. Warnings-as-errors paket suite'i 61, tam UI suite'i 9 test geçti.

### DM-019 — Tercihler ve login item

- [x] Tamamlandı — Önkoşul: DM-011. Boyut: M. İlgili: FR-14.
- **Çıktı:** Ayarlar, SMAppService wrapper, hakkında/sürüm ve veri klasörünü göster.
- **Kabul:** Girişte başlat varsayılan kapalı, gerçek sistem durumundan türetilir; kayıt reddi/onay bekleme açıklanır. Uygulama startup'ta kendi kendine profile başlamaz.
- **Doğrulama:** Wrapper fake state testleri ve OS-05 gerçek kullanıcı oturumu.
- **Kanıt (2026-09-06):** `SMAppService.mainApp` yalnız `LoginItemService` sınırından kullanılıyor; uygulama açılışta sadece gerçek sistem durumunu okuyor ve kullanıcı seçmeden kayıt oluşturmuyor. Ayarlar görünümü kapalı/açık/onay bekliyor/bulunamadı durumlarını, macOS Giriş Öğeleri bağlantısını, gerçek bundle sürüm/build bilgisini ve repository veri klasörünü gösteriyor. Sahte backend testleri kayıt, kaldırma, dış değişiklik, onay ve hata davranışlarını doğruladı. İmzalı gerçek kullanıcı oturumunda OS-05 kaydı `notFound → enabled → notRegistered` geçti ve başlangıçtaki kapalı durum geri yüklendi; hiçbir profil otomatik çalıştırılmadı. Warnings-as-errors paket suite'i 66 test, imzalı UI suite'inin 10 senaryosu geçti.

### DM-020 — Onboarding ve yerelleştirme

- [x] Tamamlandı — Önkoşul: DM-012/013/019. Boyut: M. İlgili: FR-12.
- **Çıktı:** İlk profil akışı, menü konumu anlatımı, TR/EN String Catalog.
- **Kabul:** Önceden uygulama çalıştıran hazır profil veya atanmış global shortcut yok. İlk açılışta gereksiz izin istemiyor; onboarding daha sonra yeniden açılabilir. Metinler sığar.
- **Doğrulama:** UI-01/04; ilk kurulum ve geri dönen kullanıcı.
- **Kanıt (2026-09-06):** Kalıcı ilk açılış durumu, boş ve inert ilk profil akışı, atlanabilir/yeniden açılabilir onboarding ve 167 anahtarlı TR/EN String Catalog eklendi. İlk açılış, geri dönen kullanıcı, Türkçe ve İngilizce UI testi geçti. Türkçe açık ve İngilizce koyu tema ekran görüntülerinde 820 × 620 pencerede kesilme/üst üste binme görülmedi; başlangıçta kısayol, login item veya profil run oluşturulmadı.

### DM-021 — Bozuk veri ve kurtarma UI'sı

- [x] Tamamlandı — Önkoşul: DM-006/011/012. Boyut: M. İlgili: FR-10.
- **Çıktı:** Backup doğrulama, read-only uyumsuz veri, explicit restore/reset ekranı.
- **Kabul:** Ana dosya yok/bozuk/yeni sürüm ayrılır. Kullanıcı restore/reset seçmeden veri ezilmez; özgün veri recovery kopyası olmadan silinmez; kopya yazılamazsa işlem durur.
- **Doğrulama:** ST-03/04, UI-02 kurtarma senaryoları.
- **Kanıt (2026-09-06):** Repository ana dosya eksik, bozuk ve desteklenmeyen schema durumlarını ayrı bildiriyor; yalnız doğrulanmış backup restore edilebiliyor ve yeni schema otomatik downgrade edilmiyor. Restore/reset kullanıcı seçimine bağlı, actor üzerinde atomik ve önce özgün ana veriyi benzersiz recovery kopyasına yazıyor; kopya başarısızsa ana veri değişmiyor. Storage testleri ile gerçek UI'daki restore ve onaylı reset senaryoları geçti; kurtarma kararı verilmeden run kapalı.

### DM-022 — Erişilebilirlik ve görsel doğrulama

- [x] Tamamlandı — Önkoşul: DM-016/017/018/020/021. Boyut: M. İlgili: FR-12, NFR-05.
- **Çıktı:** Klavye akışı, VoiceOver etiketleri, odak ve tema düzeltmeleri.
- **Kabul:** Profil oluştur/sırala/kaydet/çalıştır/iptal tümü klavye ile; durum yalnız renk değil. 60 karakter adlar ve TR/EN dar pencerede taşmaz; Reduce Motion uyumu.
- **Doğrulama:** UI-04 gerçek UI incelemesi ve kısa kanıt notu; yapılmayan kontrol açık bırakılır.
- **Kanıt (2026-09-06):** ⌘N, ⇧⌘U, ⌘S ve Escape ana akışta doğrulandı; çalıştırma butonu klavye erişimli, sıra kontrolleri standart metinli Button ve atanmış global kısayol ortak runner'a bağlı. Durumlar SF Symbol + metin kullanıyor ve özel animasyon yok. Accessibility ağacındaki ana kontroller XCUITest ile çalıştırıldı; 60 karakter Türkçe ad, TR açık/EN koyu tema görselleri incelendi. Gerçek VoiceOver ses sırası, Full Keyboard Access ile her sıra düğmesi ve macOS 14 görünümü DM-026 matrisinde açıkça bırakıldı. Ayrıntı [inceleme kaydında](docs/17-ACCESSIBILITY-AND-VISUAL-REVIEW.md).

### DM-023 — Gizli veri içermeyen tanılama

- [x] Tamamlandı — Önkoşul: DM-008/016/021. Boyut: M. İlgili: FR-13.
- **Çıktı:** OSLog olay/kod/süre politikası ve privacy redaction yardımcıları.
- **Kabul:** URL query, kullanıcı yolu, bookmark, profil ismi ve ham NSError açıklaması loglanmaz. Opt-in dışında dış ağ yok; telemetry/crash-upload SDK yok. Gizlilik metni gerçek davranışla eşleşir.
- **Doğrulama:** SEC-01 sentinel string testleri; gerçek Console örneği kontrollü incelenir.
- **Kanıt (2026-09-06):** `DiagnosticRecord` yalnız kapalı olay kümesi, her çalıştırmada üretilen geçici run/action UUID'leri, sabit `RunErrorCode` ve tamsayı süre kabul ediyor. Unit sentinel testi geçti. Kontrollü gerçek Console kaydında profil adı, host/yol/query, bookmark ve ham hata metni bulunmadı; run başlangıcı, üç action ve bitiş aynı geçici run kimliğiyle eşleşti. Telemetri, crash-upload ve ağ istemcisi eklenmedi; PRIVACY/SECURITY gerçek davranışla güncellendi.

### DM-024 — Uçtan uca regresyon

- [x] Tamamlandı — Önkoşul: DM-017–023. Boyut: M. İlgili: FR-01–14.
- **Çıktı:** İzole test verisi ve fake dispatcher ile ana UI regresyonları; eksik kritik testlerin tamamlanması.
- **Kabul:** Create→save→restart→run→partial→edit→run akışı; cancel/retry; store corruption. Testler gerçek kullanıcı profiline veya global kısayola dokunmaz.
- **Doğrulama:** Unit/storage/engine suite, UI-01/02/03 ve app build.
- **Kanıt (2026-09-06):** Geçici profil dizini ve sahte dispatcher ile create→save→restart→partial run→edit→başarılı run, cancel→restart→retry, bozuk store restore/reset ve klavye akışı eklendi. Warnings-as-errors paket suite'i 71 test geçti ve yalnız opt-in gerçek OS smoke'u atladı; yerel imzalı tam UI suite'i 15/15 geçti. Son unsigned arm64 app build'i ayrıca doğrulandı; testler gerçek profil deposuna dokunmadı ve dış hedef açmadı.

## M4 — Beta hazırlığı

### DM-025 — Tekrarlanabilir CI

- [x] Tamamlandı — Önkoşul: DM-001/024. Boyut: M. İlgili: NFR/Release.
- **Çıktı:** macOS CI, seçili Xcode kaydı, paket testleri/app build, artifact sonuçları.
- **Kabul:** Fork PR secrets alamaz; gerçek bağımlılıklar kilitli; gereken workflow izinleri sınırlı. CI'da mümkün olmayan GUI işleri manuel release kontrolünde kalır.
- **Doğrulama:** Yerel eş komutlar; dış CI çalışması erişim varsa gerçek run bağlantısıyla, yoksa pending.
- **Kanıt (2026-09-07):** `.github/workflows/ci.yml`, `macos-15` üzerinde tam Xcode 26.1.1 kontrolü, kilitli dependency ile warnings-as-errors paket testi, unsigned arm64 app build'i ve 14 günlük log artifact'ı ekledi. Fork/PR işi yalnız `contents: read` kullanır, checkout credential'ını saklamaz ve signing secret içermez. GUI suite yalnız manuel opt-in'dir. `scripts/verify.sh` yerel eşinde 71 test ve app build geçti. İlk public `main` ve tag push'larının iki gerçek [GitHub Actions koşusu](https://github.com/furkankoc18/Launchestra/actions) da başarıyla tamamlandı.

### DM-026 — Performans ve cihaz matrisi

- [ ] Tamamlandı — Önkoşul: DM-024. Boyut: M; cihaz erişimine bağlı. İlgili: NFR-01/02, OS testleri.
- **Çıktı:** Release ölçüm raporu ve macOS 14/güncel kararlı sürüm matrisi.
- **Kabul:** 50×30 fixture, 30 menü ölçümü, 5 dakika idle; gerçek cihaz/OS verisi. Eksik OS testi başarılı gibi gösterilmez; iyileştirme gerekiyorsa yeni ölçümle kanıtlanır.
- **Doğrulama:** PERF-01, OS-01–05, UI-04 sonuçları.
- **İlerleme/engel (2026-09-06):** Mac16,7 / arm64 / macOS 26.6.2 üzerinde Release 50×30 fixture ile 30 ölçüm p95 24,024 ms; 5 dakika/60 örnek idle CPU ortalama %0,0, RSS ortalama 76,598 MiB ve max 78,109 MiB ile eşikler geçti. Ham JSON ve yeniden üretim betikleri hazır. Minimum macOS 14 cihazı, dış disk/erişim reddi, İngilizce fiziksel klavye, logout/login, gerçek VoiceOver ve Full Keyboard Access ortamı bulunmadığı için görev açık; [matriste](docs/18-PERFORMANCE-AND-DEVICE-MATRIX.md) başarılı gösterilmedi.

### DM-027 — Açık kaynak ve ürün belgeleri

- [ ] Tamamlandı — Önkoşul: DM-024. Boyut: M. İlgili: yayın hazırlığı.
- **Çıktı:** Gerçek kurulum/derleme README'si, kullanıcı senaryoları, doğru CHANGELOG, lisans ve katkı metinleri.
- **Kabul:** MIT seçimi/telif sahibi kesinleştirilir ve standart LICENSE eklenir. Depo/güvenlik kanalı gerçek değerlerle tamamlanır. Çalışmayan gelecek özellik mevcut gibi tanıtılmaz; kişisel veri içermeyen ekran görüntüleri.
- **Doğrulama:** Link/komut kontrolü; temiz checkout talimatları; SECURITY/PRIVACY gerçek kodla karşılaştırma.
- **İlerleme/engel (2026-09-07):** MIT `LICENSE` (`furkankoc`), KeyboardShortcuts 3.0.1 lisans bildirimi ve katkı/gizlilik/güvenlik/beta metinleri eklendi. Public README İngilizce olarak gerçek klon adresi, kaynak kurulum, Xcode, ilk kullanım, izin, veri, sorun giderme, test ve mimari adımlarıyla genişletildi. Onboarding'e ek olarak profil listesi, düzenleyici ve sonuç ekranlarının TR/EN, kişisel veri içermeyen kırpılmış görselleri yeniden üretilebilir UI testiyle üretildi; son İngilizce koşu 1/1 geçti. Kaynak kod ve beta etiketi [gerçek depoya](https://github.com/furkankoc18/Launchestra) gönderildi. GitHub Private Vulnerability Reporting henüz etkin olmadığı için görev bu son kabul kapısıyla açıktır.

### DM-028 — İmzalama ve yerel beta paketi

- [ ] Tamamlandı — Önkoşul: DM-025/026/027. Boyut: L; Developer ID erişimine bağlı.
- **Çıktı:** Kalıcı bundle ID, Release archive, ZIP/DMG, checksum ve test kaydı.
- **Kabul:** İmza/Hardened Runtime/notarization/staple gerçekten kontrol edilir; sertifika yoksa yerel hazırlık tamam, imzalı yayın kısmı pending kalır. Gizli bilgiler repoya girmez.
- **Doğrulama:** RELEASE checklist, REL-01; artifact sürüm/build tutarlılığı.
- **İlerleme (2026-09-07):** Kalıcı bundle kimliği `io.github.furkankoc18.Launchestra`, sürüm `0.1.0`, build `1` olarak ayarlandı. `v0.1.0-beta.1` kaynak commit'inden thin arm64 Release archive, ZIP/DMG ve doğrulanmış SHA-256 dosyası üretildi; paket içeriği ve izole profil diziniyle açılış geçti. Ad-hoc imza `runtime` bayraklı ve bütünlük kontrolü geçiyor. Bu makinede 0 geçerli code-signing identity bulundu; `spctl` paketi reddetti ve stapler ticket bulamadı. Developer ID/notarization/staple kısmı gerçek sertifika sağlanana kadar açıktır.

## M5 — Yayın ve geri bildirim

### DM-029 — Yetkili beta yayını

- [ ] Tamamlandı — Önkoşul: DM-028 ve kullanıcının yayın yetkisi. Boyut: S.
- **Çıktı:** Gerçek repository/release URL, v0.1.0 sürümü, paket/checksum ve bilinen sınırlar.
- **Kabul:** Hazırlanmış paketin aynısı yayımlanır. Onay verilmemiş dış yazı/push yapılmaz. İndirme ve temiz kurulum yayın sonrası doğrulanır; hata varsa kullanıcıya açık release notu.
- **Doğrulama:** Gerçek release kaydı ve paket checksum eşleşmesi.
- **İlerleme (2026-09-07):** `main` ve annotated `v0.1.0-beta.1` etiketi `https://github.com/furkankoc18/Launchestra` adresine gönderildi. Developer ID/notarization eksik olduğu için ZIP/DMG GitHub Release olarak yayımlanmadı; gerçek Release URL'si ve yayın sonrası temiz indirme testi açıktır.

### DM-030 — Beta geri bildirimi ve v0.2 kararı

- [ ] Tamamlandı — Önkoşul: DM-029 ve gerçek beta kullanıcı verisi. Boyut: M.
- **Çıktı:** Hata öncelikleri, gönüllü kullanım görüşmeleri, sonraki sürüm kapsam kararı.
- **Kabul:** Ölçülmüş geri bildirim ile hipotez ayrılır; veri kaybı/çift dispatch önce çözülür. V0.2 maddeleri talebe göre seçilir; otomatik olarak tamamı başlatılmaz.
- **Doğrulama:** PRODUCT-ANALYSIS eşiği ve ROADMAP/STATUS güncellemesi.

## Sonraki sürüm kuyruğu

Bu maddeler v0.1 tamamlanmadan uygulama kapsamına alınmaz; ayrıntıları [ROADMAP](docs/11-ROADMAP.md) içindedir.

- [ ] DM-101 — Taşınabilir import/export; önkoşul DM-030, ayrı şema/güvenlik tasarımı.
- [ ] DM-102 — Editör klasör adaptörleri; önkoşul DM-030, uygulama uyumluluk deneyi.
- [ ] DM-103 — Terminal çalışma dizini; önkoşul DM-030, shell/izin sınırı deneyi.
- [ ] DM-104 — İnert profil şablonları; önkoşul DM-101.
- [ ] DM-201 — Monitör olayından profil önerisi; önkoşul DM-030, debounce/kimlik deneyleri.
- [ ] DM-202 — Ortam kuralları ve manuel override; önkoşul DM-201.
- [ ] DM-203 — Ses cihazı/volume adaptörü; önkoşul DM-030, CoreAudio ve cihaz deneyleri.
- [ ] DM-301 — Pencere yerleşimi; önkoşul DM-030, Accessibility/Spaces ürün kararı.
- [ ] DM-302 — Güvenli otomatik güncelleme; önkoşul DM-029, imzalı updater tasarımı.
- [ ] DM-303 — Intel/Universal değerlendirmesi; önkoşul DM-026, gerçek Intel testi.
