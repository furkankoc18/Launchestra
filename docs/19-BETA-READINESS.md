# 0.1.0 Beta 1 hazırlık raporu

Tarih: 2026-09-07. Bu rapor DM-025–029 arasındaki yerel çıktı ile dış yayın kapılarını ayırır.

## Hazır yerel çıktı

- Uygulama: Launchestra 0.1.0, build 1.
- Bundle kimliği: `io.github.furkankoc18.Launchestra`.
- Hedef: thin arm64 Mach-O, macOS 14.0+.
- Kategori: `public.app-category.productivity`.
- Archive: `.build/release-0.1.0-beta.1/Launchestra.xcarchive`.
- Dağıtım: `dist/0.1.0-beta.1/Launchestra-0.1.0-beta.1-arm64.zip` ve `.dmg`.
- Paket içeriği: uygulama, MIT LICENSE, beta notu, KeyboardShortcuts lisans bildirimi ve kaynak commit kaydı.
- Kaynak commit/tag: `b09555900d49aec296b5d4b702f9d3e99b693aed` / `v0.1.0-beta.1`.

Archive `codesign --verify --deep --strict` kontrolünü geçti. CodeDirectory `adhoc,runtime` bayraklarını taşıyor, TeamIdentifier yok ve entitlements sözlüğü boş. Bu, Hardened Runtime'ın yerel archive üzerinde etkin olduğunu gösterir; Developer ID imzası değildir.

ZIP ve DMG açılarak aynı içerik doğrulandı. ZIP içindeki uygulama yeni, izole bir profil diziniyle başlatıldı ve iki saniye sonra çalışmayı sürdürdü. İki artifact için `shasum -a 256 -c SHA256SUMS.txt` geçti.

| Artifact | SHA-256 |
| --- | --- |
| `Launchestra-0.1.0-beta.1-arm64.zip` | `b953368683f58927dd1e90aa6652817832f5a6a49bbb518b89b34ba5770e8b1f` |
| `Launchestra-0.1.0-beta.1-arm64.dmg` | `b1d41df180f7958653a272bcc19f3f8a25c1c19e2d83f4954fb5be548ce08dbd` |

## Doğrulama

| Kontrol | Sonuç |
| --- | --- |
| Yerel CI eşi | 71 Swift package testi geçti; unsigned arm64 Debug app build geçti |
| UI regresyonu | 15 ürün senaryosu geçti; performans testi normal suite'te opt-in olmadığı için atlandı |
| Güncellenen sürüm testi | Ayarlar ekranı 0.1.0/build 1 tek testi geçti |
| Release performans | 50 × 30 fixture, 30 örnek p95 24,024 ms; hedef 150 ms |
| Release idle | 5 dakika/60 örnek; CPU ortalama %0,0, RSS ortalama 76,598 MiB, max 78,109 MiB |
| Launch Services | Gerçek OS-01/02/03 smoke 1 test geçti |
| Login item | Yeni bundle kimliğiyle `notFound → enabled → notRegistered`; ilk kapalı durum geri geldi |
| Codesign bütünlüğü | Geçti |
| Gatekeeper assessment | Beklendiği gibi reddedildi; ad-hoc imza |
| Stapler | Beklendiği gibi ticket bulunamadı |

## Açık yayın kapıları

1. Keychain'de geçerli code-signing identity sayısı `0`; Developer ID Application sertifikası yok.
2. Developer ID imzası olmadığından Apple notarization gönderimi ve staple yapılamıyor.
3. Kaynak kod ve `v0.1.0-beta.1` etiketi [GitHub deposuna](https://github.com/furkankoc18/Launchestra) gönderildi. GitHub Private Vulnerability Reporting ve gerçek Release URL'si henüz yok.
4. Minimum macOS 14 cihaz/VM, dış disk/erişim reddi, gerçek VoiceOver/Full Keyboard Access matrisi açık.
5. DM-004 görüşmeleri 0/5; DM-030 için yayımlanmış beta ve gerçek kullanıcı geri bildirimi yok.

Bu kapılar tamamlanana kadar artifact public, notarize beta olarak adlandırılmaz. Gatekeeper'ı global kapatma talimatı verilmez.
