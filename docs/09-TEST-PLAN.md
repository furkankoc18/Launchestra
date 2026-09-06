# Test ve doğrulama planı

## Test katmanları

Domain/depolama/motor otomatik testleri deterministic olmalıdır; gerçek uygulama veya tarayıcı açmaz. Platform smoke ve UI testleri ayrı, açıkça başlatılan testlerdir. Varsayılan CI kullanıcının kişisel klasörlerine dokunmaz, global kısayol kaydetmez ve login item ayarı değiştirmez.

Saf mantık için Swift Testing tercih edilir; UI için XCTest/XCUITest. Foundation ve AppKit adaptörleri protokol arkasında taklit edilir. Runner sahte clock/scheduler kullanır; timeout testi gerçek 10/60 saniye beklemez. Geçici dosyalar testin kendi dizininde tutulur.

## İzlenebilir test matrisi

| Test ID | Gereksinim | Senaryo ve beklenen sonuç | Katman |
| --- | --- | --- | --- |
| UT-01 | FR-02/03 | Model JSON round trip; UUID, sıra ve disabled korunur | Unit |
| UT-02 | FR-02 | İsim boş/sınır/Unicode/case çakışması; doğru reddet | Unit |
| UT-03 | FR-06 | http/https ve localhost/IPv6 kabul; diğer şemalar, userinfo, bozuk port reddet | Unit |
| UT-04 | FR-10 | Kapasite/boyut/bilinmeyen tür/yeni schema; özgün dosya değişmez | Unit/integration |
| ST-01 | FR-10 | İlk kayıt, tekrar kayıt, revision çakışması; doğru dosya ve state | Storage |
| ST-02 | FR-10 | Temp/backup/replace aşamasına enjekte hata; geçerli ana dosya veya backup korunur | Storage |
| ST-03 | FR-10 | Ana dosya yok/bozuk + sağlam/bozuk/yok backup; doğru kurtarma durumu | Storage |
| ST-04 | FR-10 | Yeni sürüm store; read-only, otomatik downgrade yok | Storage |
| ST-05 | FR-10 | İkinci writer kilidi alamaz; dış değişiklikte yazma durur | Integration |
| EX-01 | FR-07 | Sıra ve tek dispatch; disabled skip; sahte dispatcher çağrı listesi | Unit |
| EX-02 | FR-08 | Continue/stop × preflight/runtime failure; doğru terminal result | Unit |
| EX-03 | FR-07 | Aynı anda 10 start; yalnız bir run | Unit |
| EX-04 | FR-11 | Preflight/dispatch/iki adım arası iptal; yeni action başlamaz | Unit |
| EX-05 | FR-08 | Action ve total deadline; geç callback, callback iki kere, hiç callback yok | Unit |
| EX-06 | FR-07 | Snapshot değişmez; eski run olayı yeni run'a işlenmez | Unit |
| EX-07 | FR-08 | Her run/action için tek terminal olay; bekleme bitince kilit serbest | Unit |
| KB-01 | FR-09 | Duplicate shortcut, rebind/delete, save failure, registration failure | Unit + smoke |
| UI-01 | FR-01/02/03 | İlk açılış, profil ekle, düzenle, kaydet, restart sonrası aynı içerik | UI |
| UI-02 | FR-02 | Kirli taslakla geçiş; kaydet/at/geri dön; disk hata halinde taslak kalır | UI |
| UI-03 | FR-07/08/11 | Fake runner ilerleme, busy, partial, cancel ve timeout ekranları | UI |
| UI-04 | FR-12 | Klavye sırası, VoiceOver, uzun TR/EN metin ve dark/light | Manuel |
| OS-01 | FR-04 | Safari kapalı/açık; kurulu olmayan app; kabul ve hata ayrımı | Manuel |
| OS-02 | FR-05 | Klasör taşı/sil, dış disk çıkar, erişim reddi, Unicode yol | Manuel |
| OS-03 | FR-06 | Varsayılan tarayıcı, offline/localhost; kabul ile yüklenme ayrımı | Manuel |
| OS-04 | FR-09 | Arka plan kısayolu, basılı tutma, düzen değiştirme, OS çakışması | Manuel |
| OS-05 | FR-14 | Login item aç/kapat; OS'ten devre dışı bırak; yeniden login | Manuel |
| SEC-01 | FR-13 | Loglara hassas URL/yol/bookmark girmiyor; app başlangıcında beklenmedik TCC yok | Otomatik + manuel |
| PERF-01 | NFR-01/02 | 50×30 fixture, menü p95 ve 5 dk idle CPU/RSS | Manuel ölçüm |
| REL-01 | Release | İmzalı/notarize paket temiz kullanıcıda açılır, sürüm/build doğru | Manuel |

## DM-001–003 doğrulama kaydı — 2026-09-05

| Kapsam | Sonuç | Kanıt |
| --- | --- | --- |
| Paket/Core/Platform | Geçti | 13 Swift Testing testi; 1 gerçek OS testi varsayılan olarak atlandı |
| App build | Geçti | Unsigned arm64 Debug, Swift 6, `arm64-apple-macos14.0` |
| UI yaşam döngüsü | Geçti | 3 XCTest: menü ajanı launch, pencere close/reopen ve arka plan global kısayol |
| OS-01 deney alt kümesi | Geçti | Safari kapalı ve açık durumda Launch Services isteğini kabul etti |
| OS-02 deney alt kümesi | Geçti | Özel karakterli geçici klasör Finder'a gönderildi; taşınan bookmark yeni konumu çözdü |
| OS-03 deney alt kümesi | Geçti | localhost ve HTTPS kabul edildi; `javascript:` handler çağrılmadan reddedildi |
| KB-01 deneyleri | Geçti | Duplicate, rebind/remove, save/registration failure, held-key ve JSON testleri |
| OS-04 deney alt kümesi | Geçti | `Turkish-QWERTY-PC` altında Finder öndeyken `⌘⌥⌃⇧K` tam bir kez tetiklendi; `⌘⌥⌃⇧Q` OS çakışması verdi |

Test cihazı arm64 Mac16,7, macOS 26.6.2 (25G83), Xcode 26.1.1 (17B100)'dür. Minimum macOS 14 cihazı, İngilizce klavye düzeni, dış disk/erişim reddi ve uyku/uyanma henüz test edilmedi; aşağıdaki gerçek cihaz listesini tamamlamaz.

## DM-005/006 doğrulama kaydı — 2026-09-06

| Test ID | Sonuç | Kapsam |
| --- | --- | --- |
| UT-01 | Geçti | Belgelenmiş JSON ve üç action discriminator round-trip; sıra, UUID ve optional alanlar korunuyor |
| UT-02 | Geçti | Trim, 60/61 karakter, canonical Unicode/case çakışması ve Türkçe `I/ı` sabit locale davranışı |
| UT-03 | Geçti | HTTP/HTTPS, localhost, IPv4/IPv6; scheme, credentials, control, whitespace ve bozuk/taşan port reddi |
| UT-04 | Geçti | Bilinmeyen/eksik alan, action type, schema 999, negatif revision, 50×30 ve 10 MiB sınırı |
| ST-01 | Geçti | İlk create revision 1; ikinci replace revision 2; backup revision 1 |
| ST-02 | Geçti | Sekiz pre-commit fault noktası; eski main korunuyor, temp dosyası kalmıyor, bozuk main backup'a kopyalanmıyor |
| ST-05 | Geçti | Revision ve SHA-256 fingerprint çakışması; aynı dizinde ikinci writer lock alamıyor |

Varsayılan paket suite'i toplam 33 test geçirdi ve yalnız opt-in Launch Services smoke testini atladı. Repository testlerinin tamamı UUID'li geçici dizinlerde çalıştı; kullanıcı Application Support verisine dokunmadı.

## DM-007–011 doğrulama kaydı — 2026-09-06

| Kapsam | Sonuç | Kanıt |
| --- | --- | --- |
| DM-007 / OS-02 alt kümesi | Geçti | Geçici klasör bookmark'ı taşıma sonrası çözüldü; bozuk bookmark lastKnownPath'a düşmedi; stale yenileme revision 7→8 kaydedildi |
| DM-008 / SEC-01 alt kümesi | Geçti | Fake workspace ile üç API kabulü, missing app, URL allowlist, erişim/red kodları ve sentetik hassas yolun hata sonucuna sızmaması |
| EX-01/02/03 | Geçti | Sıralı continue/stop, preflight/runtime ayrımı, disabled ve 1 başarılı run + 9 busy |
| EX-04/05/07 | Geçti | İptal sonrası yeni dispatch yok; callbacksiz timeout, total preflight timeout, geç callback ve tek terminal event/bitmiş stream |
| UI-01 kabuk alt kümesi | Geçti | Geçici boş, profilli ve bozuk depolar; Profiller penceresini kapatıp Ayarlar hedefiyle yeniden açma; süreç açık kaldı |
| App build/UI suite | Geçti | Unsigned arm64 Debug build; 5 yerel imzalı XCTest |

Varsayılan paket suite'i 52 test geçirdi ve yalnız kullanıcı uygulamalarını açan opt-in Launch Services smoke testini atladı. Timeout testleri sahte saatle gerçek 10/60 saniye beklemedi; dosya testleri yalnız UUID'li geçici dizinlere yazdı.

## DM-012–017 doğrulama kaydı — 2026-09-06

| Kapsam | Sonuç | Kanıt |
| --- | --- | --- |
| DM-012 / UT-02 / ST-01 | Geçti | Yeni/yeniden adlandırılmış/sıralanmış/silinmiş profiller, yeni profil/action UUID'li ve kısayolsuz benzersiz kopya; repository yeniden açılışında sıra korundu |
| DM-013/014 / UT-03 | Geçti | Action kimliği ve sırası, duplicate ad, geçersiz URL ve 50×30 kapasite kuralları; editörde uygulama/klasör/URL, etiket, enable, drag ve Yukarı/Aşağı kontrolleri |
| UI-01/02 editör alt kümesi | Geçti | Boş depoda Oluştur, profil adı, Save uygunluğu, kirli geçiş uyarısı, hatalı/geçerli URL ve JSON kaydı |
| UI-03 partial / SEC-01 | Geçti | Sahte üç eylemli run partial bitti; sonuç sırası ve host adları korundu, query sentinel'i marker ve sunuma sızmadı |
| UI-03 iptal | Geçti | Kontrollü bekleyen dispatcher sırasında yönetim penceresi İptal düğmesi terminal cancelled sonucu üretti |
| EX-03/04/06 | Geçti | Tek busy kapısı, kalan dispatch'in durması, immutable snapshot ve geç callback sonrası yeni run ayrımı |
| Gerçek üç eylem smoke | Geçti | Ürün `ProfileRunner`→`WorkspaceDispatcher` yolu Safari, geçici Finder klasörü ve localhost URL için sırayla üç accepted sonucu verdi |
| App build/UI suite | Geçti | Varsayılan optimizasyonlu unsigned arm64 Debug build; 8 yerel imzalı XCTest |

Warnings-as-errors paket suite'i **57 test** geçirdi ve yalnız opt-in gerçek sistem testi varsayılan çalışmada atlandı. Ardından `DESKMODE_RUN_OS_SMOKE=1 --filter realWorkspaceSmoke` ile seçilen gerçek sistem testi **1 test** geçti. Tam imzalı UI suite'i **8 test** geçirdi. UI testleri geçici profil dizini ve yalnız davranışı azaltan sahte dispatcher launch argument'ları kullandı; gerçek profile deposuna dokunmadı. Gerçek smoke dış alan adı kullanmadı ve hedeflerin hazır/yüklenmiş olduğunu ölçmedi.

## DM-018 doğrulama kaydı — 2026-09-06

| Kapsam | Sonuç | Kanıt |
| --- | --- | --- |
| JSON / recorder dönüşümü | Geçti | `RecordedShortcut` ile domain `ShortcutBinding` Carbon değerleri canonical modifier sırasıyla çift yönlü eşlendi; recorder doğrudan profil draft binding'ine bağlı |
| KB-01 duplicate/rebind/remove | Geçti | Aynı chord iki profile verilmeden önce reddedildi; değişen ve silinen atamalarda eski listener task'ları temizlendi |
| KB-01 transactional kayıt | Geçti | Sistem çakışması repository yazımından önce durdu; yazma hatasında önerilen listener tetiklenemedi ve eski aktif listener çalışmayı sürdürdü |
| Yeniden açılış | Geçti | JSON'dan yüklenen kaydedilmiş profil seti listener registry'yi yeniden kurdu; key-up profil UUID'sini bir kez üretti |
| Ürün global kısayolu | Geçti | Geçici JSON'daki `⌘⌥⌃⇧K`, Finder öndeyken gerçek global event ile `AppModel.run` ve sahte ürün dispatcher'ı üzerinden tamamlandı |
| App build/UI suite | Geçti | Optimizasyonlu unsigned arm64 Debug build; 9 yerel imzalı XCTest |

DM-018 sonunda warnings-as-errors paket suite'i **61 test**, tam imzalı UI suite'i **9 test** geçirdi. Global event testi kullanıcının gerçek profil deposuna dokunmadı ve dış kaynak açmayan sahte dispatcher kullandı. İngilizce klavye düzeni ve minimum macOS 14 cihazı doğrulaması gerçek cihaz listesinde açık kalır.

## DM-019 doğrulama kaydı — 2026-09-06

| Kapsam | Sonuç | Kanıt |
| --- | --- | --- |
| Login item wrapper | Geçti | İlk durum okuması kayıt üretmedi; enable/disable çağrıları backend'in dönen gerçek durumuyla eşleşti |
| Sistemden değişiklik ve onay | Geçti | Dış durum yenilemesi, `requiresApproval` gösterimi ve pending kaydın kaldırılması fake backend ile doğrulandı |
| Kayıt hatası | Geçti | Hata çağırana iletildi ve arayüz için sahte `enabled` state üretilmedi |
| Ayarlar UI | Geçti | Kapalı/açık geçişi, gerçek bundle version/build, veri klasörü yolu ve Finder düğmesi imzalı UI testinde doğrulandı |
| OS-05 gerçek oturum | Geçti | Yerel imzalı bundle gerçek `SMAppService.mainApp` ile `notFound → enabled → notRegistered` geçti; ilk kapalı durum geri yüklendi |
| Startup güvenliği | Geçti | Normal AppModel kurulumu yalnız login-item durumunu okuyor; otomatik kayıt veya profil run girişi çağırmıyor |

DM-019 sonunda warnings-as-errors paket suite'i **66 test**, tam imzalı UI suite'i **10 test** geçti. İlk UI denemesi gerçek login-item kaydının tetiklediği macOS Control Center bildirimi nedeniyle kesildikten sonra bildirimden bağımsız temiz toplu koşu 10/10 tamamlandı. OS-05 testinden sonra ayar kapalıdır ve smoke argümanı ayrıca ortam değişkeni olmadan sistem durumunu değiştiremez.

## DM-020–024 doğrulama kaydı — 2026-09-06

| Kapsam | Sonuç | Kanıt |
| --- | --- | --- |
| DM-020 / UI-01 | Geçti | İlk kurulum onboarding'i, boş profil oluşturma, atlama, daha sonra yeniden açma ve kalıcı geri dönen kullanıcı durumu doğrulandı; başlangıçta run/kısayol/login-item üretilmedi |
| DM-020/022 / UI-04 alt kümesi | Geçti | 167 TR/EN String Catalog anahtarı derlendi; Türkçe açık ve İngilizce koyu tema onboarding ekran görüntüleri 820 × 620 pencerede gözle incelendi; 60 karakter Türkçe profil adı taşmadan kabul edildi |
| DM-021 / ST-03/04 | Geçti | Eksik, bozuk ve schema 999 ana dosya ile sağlam/bozuk/yok backup ayrımları; read-only yeni schema; restore/reset öncesi özgün recovery kopyası ve kopyalama hatasında durma |
| DM-021 / UI-02 | Geçti | Bozuk store ekranında doğrulanmış backup restore edildi; reset ikinci kullanıcı onayıyla yapıldı; iki akışta da özgün bozuk ana dosyanın recovery kopyası korundu |
| DM-022 / klavye ve AX | Geçti | ⌘N, ⇧⌘U, ⌘S, Escape ve çalıştırma girişi gerçek XCUITest event'leriyle çalıştı; onboarding, recovery, editör, sonuç ve iptal kontrolleri accessibility ağacında bulundu |
| DM-023 / SEC-01 | Geçti | Kapalı alan kümesi unit sentinel testinden geçti. PID ile sınırlandırılmış gerçek Console örneğinde profil adı, URL host/yol/query, bookmark ve ham hata metni yoktu; run/action/bitiş aynı geçici run UUID'sini taşıdı |
| DM-024 / UI-01/02/03 | Geçti | İzole create→save→restart→partial run→edit→başarılı run, cancel→restart→retry, store corruption, kısayol ve ayar regresyonları 15/15 geçti |
| Paket ve app build | Geçti | Swift warnings-as-errors ile 71 paket testi; yalnız opt-in OS smoke atlandı. Unsigned arm64 Debug app build'i geçti |

DM-020–024 testleri UUID'li geçici profil dizinleri, ayrı UserDefaults suite'leri ve sistem hedefi açmayan sahte dispatcher kullandı. Gerçek kullanıcı profil dosyası ve login-item kaydı değiştirilmedi. Gerçek VoiceOver ses sırası, Full Keyboard Access ile her sıra düğmesi ve minimum macOS 14 görünümü DM-026'ya açık devredildi.

## Fixture seti

Boş store; üç eylemli normal profil; yalnız disabled; 50×30 sınır; sınır üstü; bozuk JSON; schemaVersion 999; bilinmeyen action; duplicate UUID; duplicate kısayol; geçersiz bookmark; eski revision; query içinde test token'i bulunan URL. Tüm veriler sentetiktir, gerçek bookmark üreten testler geçici klasörde çalışır.

Repo fixture dosyaları geliştirme sırasında oluşturulur. En az bir JSON örneği [DATA-MODEL](06-DATA-MODEL.md) ile birebir schema doğrulama testine alınır; belge ile kodun ayrışması görünür olur.

## Gerçek cihaz kontrol listesi

- [ ] Minimum macOS 14 Apple Silicon üzerinde ana akış.
- [x] Test gününde kullanılan güncel kararlı macOS Apple Silicon üzerinde ana akış; Mac16,7, macOS 26.6.2 (25G83), yerel imzalı Debug, 2026-09-06; izole ana UI akışı 15/15 geçti.
- [ ] Açık/koyu tema, Türkçe/İngilizce, dar editör penceresi. TR açık ve EN koyu onboarding 820 × 620'de geçti; dar editörün tam matrisi açık.
- [ ] Klavye ve VoiceOver ile profil oluşturma ve çalıştırma.
- [ ] Menü uygulamasının uyku/uyanma sonrası çalışması.
- [ ] Ağ olmadan uygulama yönetimi; URL sonucu hakkında doğru metin.
- [ ] Dış disk bağlı/ayrılmış klasör sonucu.
- [x] İptal sonrası geç gelen OS sonucu ve yeniden başlatma. Sahte saat/dispatcher unit testleri ve yerel imzalı cancel→restart→retry UI akışı Mac16,7 üzerinde geçti.
- [ ] Girişte başlatma kapalı/açık ve sistemde sonradan kapatılmış. Otomatik kayıt/aç/kapat/geri yükleme Mac16,7, macOS 26.6.2, yerel imzalı Debug ile 2026-09-06 tarihinde geçti; Sistem Ayarları'ndan sonradan kapatma ve yeniden login alt senaryoları açık.
- [ ] İmzalı Release build üzerinde TCC ve Gatekeeper davranışı.

Her madde cihaz/OS/build/tarih ve gerçek sonuçla işaretlenir. İkinci OS veya donanım yoksa yapılmamış kontrol yazılır; daha dar destek beyanı ile beta kararı kayıt altına alınır. Intel/çoklu monitör ses senaryoları v0.1 desteği gibi gösterilmez.

## Performans protokolü

Release build ve ölçüm cihazı kaydedilir. Başka ağır iş yükleri kapalıyken 50 profil × 30 eylem yüklenir. 30 menü açma ölçümünde p95; 5 dakika idle süreç CPU ortalaması ve RSS örnekleri alınır. Instruments/signpost veya uygun yerel ölçüm aracı kullanılabilir. Sonuçlar ölçülen değerlerdir; otomatik launch callback süresi kullanıcı çalışma ortamının hazır olma süresi diye raporlanmaz.

## Bitti tanımı

Görev düzeyinde ilgili testler ve etkilenen hedef derlemesi geçer. Milestone sonunda geniş regression seti bir kez çalışır. Yayın için matristeki v0.1 maddelerinin sonucu ve istisnaları kaydedilir. Hedefli kontroller başarılıyken gerekçesiz test tekrarı yapılmaz. Belge değişikliği tek başına uygulama testlerinin çalıştırılmasını gerektirmez; link/ID/tutarlılık kontrolü yeterlidir.
