# Geliştirme ortamı ve derleme sözleşmesi

## Araç zinciri

Hedef ve doğrulanan proje ayarı Swift 6 dil modu ile macOS deployment target 14.0'dır. 5 Eylül 2026 tarihinde arm64 Mac16,7 üzerinde şu araçlar kullanıldı:

- macOS 26.6.2 (25G83)
- Xcode 26.1.1 (17B100), Apple Swift 6.2.1
- CLI Swift 6.2.3
- MacOSX 26.1 SDK; derleme hedefi `arm64-apple-macos14.0`

Global `xcode-select -p` Command Line Tools'u göstermeye devam eder. Tam Xcode `/Applications/Xcode.app` altında doğrulandığı için proje komutları kullanıcı ayarını değiştirmeden oturuma özgü `DEVELOPER_DIR` kullanır.

```bash
cd /Users/furkankoc/Desktop/projects/DeskMode
xcode-select -p
xcodebuild -version
swift --version
```

Başka makinede Xcode yolu kontrol edilmeden bu konumu varsayma. Xcode farklı yerdeyse doğrulanmış gerçek yolu kullan; global `xcode-select` değişikliği gerekli değildir.

## Proje oluşturma kararı

Git'e dahil edilen bir `DeskMode.xcodeproj`, paylaşılan `DeskMode` scheme'i, App target'ı ve `DeskModeUITests` target'ı oluşturulur. Yerel Swift package `Packages/DeskModeKit` Core ve Platform library target'larını içerir. Xcode proje üretim aracı varsayılan bağımlılık değildir; .pbxproj düzenlemelerinin derlenebilirliği gerçek xcodebuild ile doğrulanır.

Debug build kişisel hesap gerektirmeyen yerel geliştirmeyi desteklemeli; kimlik bilgisi ve development team repoya hardcode edilmez. Geliştirme bundle kimliği ters DNS biçiminde yerel/geçici olabilir; yayın kimliği DM-028'de sahipliği belli kalıcı kimliğe dönüştürülür. Kimlik değişimi veri ve izin davranışına etkisiyle kaydedilir.

## Doğrulanmış komutlar

Aşağıdaki komutlar en son 6 Eylül 2026 tarihinde gerçek sonuçla çalıştırıldı:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift test --package-path Packages/DeskModeKit \
  -Xswiftc -gnone -Xswiftc -warnings-as-errors

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project DeskMode.xcodeproj -scheme DeskMode \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/xcode CODE_SIGNING_ALLOWED=NO build

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project DeskMode.xcodeproj -scheme DeskMode \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath .build/signed-ui -parallel-testing-enabled NO test
```

DM-005/006 sonrasında paket suite'i 33, DM-007–011 sonrasında 52, DM-012–017 sonrasında 57, DM-018 sonrasında 61, DM-019 sonrasında 66 ve DM-024 sonunda warnings-as-errors ile 71 test geçirdi; gerçek OS smoke varsayılan olarak atlanır. Bu makinede normal debug sembol bağlama adımı bir kez `dsymutil` içinde takıldığı için paket doğrulaması `-gnone` ile yapıldı; test davranışını değiştirmez. Varsayılan optimizasyonlu unsigned arm64 app build'i geçti. DM-024 sonunda yerel “Sign to Run Locally” imzasıyla 15 UI senaryosu doğrulandı; onboarding/yerelleştirme, kurtarma, uçtan uca profil yaşam döngüsü, iptal/tekrar, kayıtlı profil kısayolu ve ayarlar/login-item görünümü bu kapsamdadır. Unsigned UI runner kullanılmaz.

Gerçek Launch Services smoke testi Safari, Finder ve varsayılan tarayıcıyı açtığı için ayrıca ve isteğe bağlı çalıştırılır:

```bash
DESKMODE_RUN_OS_SMOKE=1 \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift test --package-path Packages/DeskModeKit \
  --filter realWorkspaceSmoke
```

Bu opt-in test 1 test geçirdi. Uygulama/klasör/URL isteğinin kabulünü ölçer; hedef içeriğin hazır olduğunu ölçmez.

Gerçek login-item testi yalnız yerel imzalı app bundle üzerinden ve çift opt-in ile çalışır. İlk durum kapalıysa kayıt eder, gerçek durumu okur ve çıkmadan önce kaydı kaldırarak başlangıç durumunu geri yükler:

```bash
DESKMODE_RUN_LOGIN_ITEM_OS_SMOKE=1 \
DESKMODE_LOGIN_ITEM_SMOKE_RESULT=/tmp/deskmode-login-item-result.txt \
  .build/signed-ui-dm019/Build/Products/Debug/Launchestra.app/Contents/MacOS/Launchestra \
  --login-item-os-smoke
```

2026-09-06 koşusu `notFound → enabled → notRegistered` geçti. Bu test gerçek kullanıcı login-item durumunu kısa süreli değiştirir ve macOS arka plan öğesi bildirimi gösterebilir; UI regression testlerinden ayrı çalıştırılır.

## Kısayol bağımlılığı

`KeyboardShortcuts` tam olarak 3.0.1 sürümüne bağlıdır. `Package.resolved` revision'ı `49c3fc04ea827f816df67843bfcc57286b47ff06` değeridir. Kaynak depo Sindre Sorhus'un [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) deposudur ve incelenen paket lisansı MIT'dir. Dependency yalnız `DeskModePlatform` target'ında bulunur; uygulamada LLM/API bağımlılığı yoktur.

## Kod standartları

- Domain isimleri İngilizce; UI metinleri String Catalog; kullanıcı belgeleri Türkçe.
- Gereksiz global singleton yerine composition root'ta bağımlılık enjeksiyonu.
- Value tipleri ve açık error enum'ları; force unwrap ve sessiz `try?` ile veri hatası yutma yok.
- Clock/UUID üretimi ve dispatcher testlerde kontrol edilebilir.
- UI'da filesystem çağrısı, key registration veya launcher mantığı tutma.
- Geniş mimari framework, gereksiz protocol katmanı, otomatik kod üretimi ve kullanılmayan abstraction ekleme.
- Dependency seçildikten sonra gerçek Package.resolved kaydedilir; formatter sürümü seçilip belgelenmeden CI'ya varmış gibi eklenmez.

## CI — DM-025

`.github/workflows/ci.yml`, push ve pull request'te GitHub'ın `macos-15` runner'ında `/Applications/Xcode_26.1.1.app` yolunu ve Xcode sürümünü doğrular. Kilitli bağımlılıkla warnings-as-errors paket testlerini ve unsigned arm64 app build'ini çalıştırır; logları 14 gün artifact olarak saklar. Workflow yalnız `contents: read` iznine sahiptir ve checkout credential'ını kalıcı yapmaz. UI regresyonu yalnız manuel `workflow_dispatch` içindeki `run_ui_tests` seçeneğiyle başlar; GUI runner sonucu PR için zorunlu başarı olarak sunulmaz.

Yerel eş komut:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/verify.sh
```

2026-09-06 yerel koşusunda 71 paket testi ve unsigned arm64 Debug app build'i geçti. Uzak depo bulunmadığı için GitHub Actions run URL'si henüz yoktur; ilk push'tan sonra aynı workflow sonucu DM-025 dış kanıtına eklenir.

Fork PR'larına signing secrets verilmez. Yayın işi ayrı, tag veya yetkili manuel tetiklemedir. GitHub Actions sürümleri kurulurken gerçek sürüm/commit ve izinler doğrulanır; minimum `contents: read` ile başlanır, yalnız yayın işinde gerekli yazma yetkisi açılır. Cache başarı kanıtı yerine geçmez.

DM-026 Release performans koşuları:

```bash
scripts/generate_performance_fixture.py .build/performance/idle/profiles.json
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_performance_ui.sh
scripts/measure_idle.py \
  --executable .build/performance-ui/Build/Products/Release/Launchestra.app/Contents/MacOS/Launchestra \
  --profile-directory .build/performance/idle \
  --duration 300 --interval 5 \
  --output .build/performance/idle/result.json
```

`run_performance_ui.sh`, yalnız koşu sırasında `.build` altında bir marker oluşturduğu için normal UI suite'i pahalı 30 örnekli testi atlar. Ölçüm JSON'u `.xcresult` ekinden çıkarılır. Fixture sabit UUID namespace'i ve `example.invalid` URL'leri kullanır.

Önerilen branch biçimi `codex/dm-<id>-<kisa-ad>`. Kullanıcı başka yöntem seçerse ona uyulur. Commit/push ayrı oturum yetkisine göre yapılır; bu belge tek başına yayın yetkisi vermez.

## Yerel test izolasyonu

UI test launch argument/environment ile geçici Application Support root ve fake dispatcher sağlar. `--editor-ui-smoke`, `--profiles-ui-smoke`, `--run-ui-smoke`, `--cancel-run-ui-smoke`, `--profile-shortcut-smoke`, `--settings-ui-smoke`, `--onboarding-ui-smoke`, `--returning-user-ui-smoke`, `--recovery-ui-smoke` ve `--e2e-ui-smoke` yalnız test fixture'ı kurar veya sistem açma/login-item davranışını sahte adaptöre indirger; yeni bir ürün yetkisi vermez. `DESKMODE_PROFILE_DIRECTORY` ve `DESKMODE_DEFAULTS_SUITE` depolamayı test başına ayırır. Testler kullanıcının gerçek profillerini, kısayollarını veya login-item kaydını değiştirmez. OS smoke testleri açıkça seçilen zararsız fixture kaynaklarıyla çalışır.

## Sorun giderme

| Belirti | İlk kontrol |
| --- | --- |
| xcodebuild tam Xcode istiyor | `xcode-select -p`, kurulu Xcode ve oturum DEVELOPER_DIR |
| Menü var, editör görünmüyor | Scene kimliği, activation policy, MainActor ve DM-002 sonucu |
| App launch kabul ama içerik yok | API kabulü ile hedef app davranışını ayır; OS-01/03 |
| Kısayol iki kez çalışıyor | Eski event task unregister/cancel ve kayıt seti |
| JSON kaydedilemiyor | Revision, dosya lock, disk alanı; taslağı koru |
| İptalden sonra UI bekliyor | Completion kapısı ve iptali desteklemeyen child beklemesi |
