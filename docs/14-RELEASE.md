# Derleme, paketleme ve yayın planı

Durum: 0.1.0 Beta 1 için yerel ad-hoc archive, ZIP/DMG ve checksum üretimi çalışıyor. Developer ID kimliği, notarization, public depo ve yayımlanmış paket henüz yoktur.

## Sürüm ve kanıt

İlk hedef `0.1.0` beta. `CFBundleShortVersionString` ürün sürümü, `CFBundleVersion` artan build numarası olarak yönetilir. Her artifact kaynak commit, Xcode/SDK sürümü, architecture, checksum ve test sonuçlarıyla ilişkilendirilir. Git deposu kurulmadan gerçek commit/tag değeri varmış gibi yazılmaz.

Kalıcı bundle kimliği `io.github.furkankoc18.Launchestra`, ürün sürümü `0.1.0`, build `1` ve minimum sistem `14.0` olarak ayarlandı. Kaynak kod deposu ve yayın hesabı DM-027/029'da kesinleşir. Henüz bilinmeyen URL'ler README'de çalışan indirme bağlantısı olarak gösterilmez.

## Hazırlık sırası

1. V0.1 PRD/test matrisi ve gerçek cihaz sonuçlarını kontrol et; engelleyici hataları kapat.
2. Lisans, telif sahibi, kalıcı bundle ID, güvenlik kanalı ve gizlilik metnini tamamla.
3. Release build/archive üret; Debug entitlement'larının yayın çıktısına taşınmadığını kontrol et.
4. Developer ID ile imzala; Hardened Runtime ve secure timestamp doğrula.
5. Uygun paketi Apple notary service'e gönder, sonucu/logu kontrol et; başarı sonrası ticket'ı desteklenen artifact'e staple et.
6. DMG/ZIP ve SHA-256 checksum üret; paket içeriği ve kurulumu test et.
7. Kullanıcı yayın yetkisi varsa test edilmiş aynı artifact'i yayımla. Yoksa somut artifact ve kalan yayın adımıyla hazır teslim et.

Apple, doğrudan dağıtım için Developer ID, Hardened Runtime ve notarization akışını belgeliyor. `notarytool`/`stapler` mevcut akışın araçlarıdır; `altool` seçilmez. Notarization bir ürün kalitesi testi değildir. [Apple dağıtım belgesi](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## Signing ve secret yönetimi

Team ID, sertifika private key'i, App Store Connect API private key'i ve parolalar kaynak dosyalarına yazılmaz. Yerel Keychain veya yetkili CI secret deposu kullanılır; fork PR'ları bu sırlara erişemez. Log/komut çıktısı secret göstermemelidir. Release signing kimliği Debug kimliğinden ayrılır; kalıcı kimlik değişikliğinin login item/OS izinlerine etkisi test edilir.

## Yerel beta üretimi

Tekrarlanabilir yerel paket betiği:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/build_local_beta.sh
```

Çıktı `dist/0.1.0-beta.1/` içinde arm64 ZIP, DMG ve `SHA256SUMS.txt` üretir. Her iki paket Launchestra.app, LICENSE, RELEASE_NOTES, THIRD_PARTY_NOTICES ve SOURCE_COMMIT dosyalarını taşır. Archive ve doğrulama logları `.build/release-0.1.0-beta.1/` altında kalır.

```bash
codesign --verify --deep --strict --verbose=2 \
  .build/release-0.1.0-beta.1/Launchestra.xcarchive/Products/Applications/Launchestra.app
spctl --assess --type execute --verbose=2 \
  .build/release-0.1.0-beta.1/Launchestra.xcarchive/Products/Applications/Launchestra.app
xcrun stapler validate \
  .build/release-0.1.0-beta.1/Launchestra.xcarchive/Products/Applications/Launchestra.app
(cd dist/0.1.0-beta.1 && shasum -a 256 -c SHA256SUMS.txt)
```

`--deep` doğrulama için kullanılır; hatalı signing yapısını körlemesine recursive sign ederek düzeltme önerisi değildir. ZIP staple edilmez; içindeki app ticket'lı olarak yeniden arşivlenebilir. Son dağıtılan DMG/ZIP'in tam içeriği ve imza sonucu doğrulanır.

## Yayın kontrol listesi

- [x] Tüm v0.1 görevleri ve test sonuçları gerçek durumuyla incelendi; açık cihaz/dış kapılar STATUS'ta kaldı.
- [ ] Minimum/güncel OS kontrolleri veya açık daraltılmış destek kararı var.
- [x] Veri kaybı, kendiliğinden çalıştırma ve çift dispatch regresyonları geçti; açık cihaz izin matrisi ayrıca kayıtlı.
- [x] README yalnız çalışan özellikleri anlatıyor; Terminal/ses/monitör gelecek olarak ayrıldı.
- [x] MIT lisans tercihi/telif sahibi ve standart LICENSE tamam.
- [ ] PRIVACY ve SECURITY gerçek uygulamaya uygun; özel bildirim kanalı var.
- [x] Sürüm/build ve kalıcı bundle ID doğru.
- [ ] Release imzası, entitlements, Hardened Runtime ve notarization sonucu doğrulandı.
- [x] Paket içeriği uygulama ve gereken lisans/beta/kaynak bildirimleriyle sınırlı; anahtar/log/kişisel profil yok.
- [x] Checksum ve kaynak commit paket üretim betiğiyle ilişkilendiriliyor.
- [ ] Temiz kullanıcı hesabında indirme, kurulum, açılış, profil oluşturma ve çıkış denendi.
- [ ] Yayın yetkisi mevcut; yayımlanan artifact test edilene eşit.
- [ ] Yayın sonrası indirme ve checksum kontrolü tamamlandı.

## Sertifika veya hesap yoksa

Kaynak build, unit test, unsigned/ad-hoc yerel deney ve paket hazırlığı sürdürülebilir. Bunlar notarize resmî dağıtım diye sunulmaz. Kullanıcıya Gatekeeper'ı global kapatması önerilmez. Eksik sertifika/hesap somut yayın engeli olarak STATUS'a yazılır; tamamlanan yerel işler kaybolmaz.

## Geri alma ve kaldırma

V0.1 otomatik güncelleyici içermez; yeni sürüm manuel kurulur. Hatalı sürümde release notu ve güvenilir önceki artifact bağlantısı sağlanır. Yeni schema varsa eski binary'nin veriyi ezmeyeceği test edilir; desteklenmeyen downgrade otomatik uygulanmaz. Yayın silme/geri çekme işlemleri kullanıcının verdiği yetki kapsamında yapılır.

Kaldırmada kullanıcı önce Ayarlar'dan girişte başlatmayı kapatır, uygulamadan çıkar ve .app'i kaldırır. Profiller kullanıcı silmeyi seçene kadar Application Support'ta kalır. Uygulama dışındaki kaynak klasörleri veya açılan uygulamalar silinmez. Ham App Support dizini kullanıcı isterse Finder üzerinden kaldırılabilir; ürün içinde başlangıçta tek tık veri imhası özelliği yoktur.
