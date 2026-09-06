# Gerçek proje durumu

Son güncelleme: 2026-09-07.

## Tamamlanan

- [x] **DM-001–003:** Swift 6/macOS 14 proje temeli, NSWorkspace/bookmark/menu deneyleri ve KeyboardShortcuts 3.0.1 adaptörü.
- [x] **DM-005–010:** Katı v1 veri modeli, atomik/revision kontrollü repository actor, bookmark/Workspace adaptörleri ve tek-run timeout/iptal motoru.
- [x] **DM-011–017:** Menü çubuğu kabuğu, kalıcı profil/eylem CRUD, doğrulama, çalıştırma, sonuç ve iptal akışları.
- [x] **DM-018–024:** Global profil kısayolları, login item/ayarlar, TR/EN onboarding, açık veri kurtarma, erişilebilirlik/tema, privacy-safe OSLog ve uçtan uca regresyonlar.
- [x] **Yayın adı ve kimliği:** Kullanıcıya görünen ad `Launchestra`; ürün/binary `Launchestra.app`; kalıcı bundle kimliği `io.github.furkankoc18.Launchestra`; sürüm `0.1.0`, build `1`.
- [x] **DM-025:** Minimum izinli GitHub Actions workflow'u, kilitli action/dependency sürümleri, paket testleri, arm64 app build'i, log artifact'ı ve yerel `scripts/verify.sh` eşi.
- [x] **DM-026 performans kısmı:** Mac16,7/macOS 26.6.2 Release 50×30 fixture; 30 ölçüm p95 24,024 ms. Beş dakika idle CPU ortalama %0,0, RSS ortalama 76,598 MiB/max 78,109 MiB.
- [x] **DM-027 yerel belge kısmı:** MIT LICENSE, KeyboardShortcuts bildirimi, gerçek README/katkı/gizlilik/güvenlik/beta notları, TR/EN kişisel veri içermeyen kırpılmış ekran görüntüleri.
- [x] **DM-028 yerel paket kısmı:** arm64 Release archive, ad-hoc Hardened Runtime imzası, ZIP/DMG, checksum, içerik ve izole profil diziniyle açılış doğrulaması.

## Doğrulama özeti

- `scripts/verify.sh`: warnings-as-errors **71 package testi geçti**, bir opt-in OS testi atlandı; unsigned arm64 Debug app build geçti.
- İmzalı Debug UI suite: **15 ürün testi geçti**; yeni DM-026 testi normal suite'te opt-in olmadığı için atlandı. Sürüm beklentisi 0.1.0'a güncellendikten sonra ilgili Ayarlar testi ayrıca geçti.
- Release performans: 50 profil × 30 eylem, 30 görünüm ölçümü p95 **24,024 ms**; 300 saniye/60 boşta örnek CPU **%0,0**, RSS **76,598 MiB** ortalama.
- Gerçek Launch Services smoke: Safari/Finder/HTTP(S) kabul alt kümesi **1 test geçti**; kabul hedefin hazır olduğu anlamına gelmez.
- Gerçek login item: yeni bundle kimliğiyle `notFound → enabled → notRegistered`; ilk kapalı durum geri yüklendi ve profil otomatik çalışmadı.
- Archive: thin arm64, minimum macOS 14.0, boş entitlements, CodeDirectory `adhoc,runtime`; `codesign --verify --deep --strict` geçti.
- ZIP/DMG: app, LICENSE, THIRD_PARTY_NOTICES, RELEASE_NOTES ve kaynak commit kaydı; mount/extract ve checksum doğrulaması geçti.
- Gatekeeper `spctl` ad-hoc imzayı reddetti; `stapler` ticket bulamadı. Bunlar Developer ID/notarization eksikliğinin beklenen gerçek sonuçlarıdır.
- Markdown: 38 dosyanın yerel bağlantıları çözüldü; workflow YAML parse ve scheme XML kontrolü geçti; `git diff --check` temiz.

## Açık görevler ve dış kapılar

- [ ] **DM-004:** Beş gerçek hedef kullanıcı görüşmesi **0/5**. Ad araştırması ve Launchestra kararı tamam.
- [ ] **DM-026:** Minimum macOS 14 cihaz/VM, dış disk çıkarma/erişim reddi, İngilizce fiziksel klavye, tam logout/login, gerçek VoiceOver ve Full Keyboard Access koşuları yok.
- [ ] **DM-027:** Public depo olmadığı için gerçek repository URL'si ve GitHub Private Vulnerability Reporting kanalı yok.
- [ ] **DM-028:** Keychain'de geçerli signing identity sayısı `0`; Developer ID Application imzası, notarization ve staple yapılamadı.
- [ ] **DM-029:** Git remote yok; `gh` kurulu/oturum açık değil; public Release URL'si ve yayın sonrası indirme testi yok.
- [ ] **DM-030:** DM-029 tamamlanmadan ve gerçek beta kullanıcıları olmadan geri bildirim/v0.2 kararı üretilemez.
- [ ] **DM-101+ kuyruğu:** ROADMAP gereği DM-030 ölçülmüş geri bildirimi olmadan başlanmaz.

## Yerel artifact

- Archive: `.build/release-0.1.0-beta.1/Launchestra.xcarchive`
- ZIP: `dist/0.1.0-beta.1/Launchestra-0.1.0-beta.1-arm64.zip`
- DMG: `dist/0.1.0-beta.1/Launchestra-0.1.0-beta.1-arm64.dmg`
- Checksum: `dist/0.1.0-beta.1/SHA256SUMS.txt`

Artifact kaynak commit'i `b09555900d49aec296b5d4b702f9d3e99b693aed`, yerel annotated tag `v0.1.0-beta.1` değeridir. ZIP SHA-256 `b953368683f58927dd1e90aa6652817832f5a6a49bbb518b89b34ba5770e8b1f`, DMG SHA-256 `b1d41df180f7958653a272bcc19f3f8a25c1c19e2d83f4954fb5be548ce08dbd` değeridir. `dist/` ve `.build/` üretilmiş yerel çıktıdır, Git'e eklenmez.

## Sonraki iş

Yerelde tamamlanabilen beta hazırlığı bitmiştir. Bir sonraki somut adım public GitHub deposu/güvenlik kanalını kurmak ve Developer ID Application sertifikasıyla aynı kaynak commit'inden imzalı-notarize paketi yeniden üretmektir. Bundan sonra DM-029 beta yayını ve gerçek DM-030 geri bildirim döngüsü yapılabilir.

## Oturum devri

```text
Tarih: 2026-09-07
Tamamlanan: DM-025; DM-026 performans; DM-027 yerel OSS belgeleri; DM-028 ad-hoc yerel paket
Doğrulama: 71 package test, unsigned build, 15 ürün UI testi + sürüm rerun, Release performans/idle, OS smoke, login item, archive/codesign, ZIP/DMG/checksum
Karar: Launchestra 0.1.0 build 1; io.github.furkankoc18.Launchestra; MIT/furkankoc; Apple Silicon/macOS 14+
Açık gerçek engel: macOS 14 ve yardımcı teknoloji cihaz matrisi; Developer ID/notarization; public GitHub repo/security channel; beta kullanıcı geri bildirimi
Sonraki görev: DM-026 dış cihaz matrisi + DM-027/028 dış kimlik kapıları, ardından DM-029
```
