# Performans ve cihaz matrisi

Tarih: 2026-09-06. Görev: DM-026. Sonuçlar sentetik fixture ve gerçek fiziksel Mac sürecinden alınmıştır. Erişilmeyen OS/cihaz durumları başarılı gösterilmez.

## Release performans sonucu

| Ölçüm | Fixture / yöntem | Sonuç | Hedef | Durum |
| --- | --- | ---: | ---: | --- |
| Isınmış profil görünümü | 50 profil × 30 eylem, 1 warm-up ardından 30 Ayarlar→Profiller geçişi | p95 **24,024 ms**; min 18,467 ms; max 24,743 ms | p95 < 150 ms | Geçti |
| Boşta CPU | Aynı 50 × 30 fixture, yalnız menü ajanı, 300 saniye, 5 saniye aralıkla 60 örnek | ortalama **%0,0**, max %0,0 | ortalama < %1 | Geçti |
| Boşta RSS | Aynı süreç ve örnekler | ortalama **76,598 MiB**, max 78,109 MiB | < 100 MB | Geçti |

Ölçüm uygulaması Xcode Release yapılandırması ve arm64 hedefiyle oluşturuldu. Cihaz `Mac16,7`, işletim sistemi macOS `26.6.2`, kernel build `25.6.0`, Xcode `26.1.1 (17B100)` idi. Menü ölçümü uygulama içindeki `ProcessInfo.systemUptime` noktalarıyla hesaplanır; XCUITest yalnız geçişi tetikler ve değeri okur. Boşta ölçümü gerçek process PID'sini `ps` ile örnekler. İlk RSS örneği süreç yerleşmeden önce 1,344 MiB'dir ve beş dakikalık ortalamaya dahildir.

Ham sonuçlar oluşturulan `.build/performance/menu/result.json` ve `.build/performance/idle/result.json` dosyalarındadır; `.build` Git'e eklenmez. Menü ölçüm JSON'u test `.xcresult` içine `DM026-Menu-Performance` eki olarak da saklanır.

Tekrar üretme:

```bash
scripts/generate_performance_fixture.py .build/performance/idle/profiles.json
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/run_performance_ui.sh
scripts/measure_idle.py \
  --executable .build/performance-ui/Build/Products/Release/Launchestra.app/Contents/MacOS/Launchestra \
  --profile-directory .build/performance/idle \
  --duration 300 --interval 5 \
  --output .build/performance/idle/result.json
```

## İşletim sistemi ve cihaz matrisi

| Alan | Mevcut kanıt | Durum / açık parça |
| --- | --- | --- |
| Güncel fiziksel Apple Silicon Mac | Mac16,7 / arm64 / macOS 26.6.2 üzerinde paket, build, UI, OS ve performans kanıtı | Geçti |
| Minimum macOS 14 | Deployment target 14.0; `arm64-apple-macos14.0` derlemesi geçti | Fiziksel/VM macOS 14 koşusu yok; açık |
| Intel Mac | V0.1 Apple Silicon hedefi | Kapsam dışı; DM-303 değerlendirmesi |
| OS-01 uygulama açma | Safari kapalı/açık ve bulunamayan uygulama ayrımı gerçek Launch Services smoke ile ölçüldü | Mevcut cihazda geçti |
| OS-02 klasör/bookmark | Unicode geçici klasör ve taşınmış bookmark geçti; bozuk bookmark fallback yapmadı | Dış disk çıkarma ve gerçek erişim reddi açık |
| OS-03 URL | HTTPS ve localhost kabulü, geçersiz şema reddi geçti; kabul ile sayfa hazır olma ayrıldı | Mevcut cihazda geçti |
| OS-04 kısayol | Turkish-QWERTY-PC, Finder önde tek tetik, basılı tutma ve OS çakışma kanıtı | İngilizce fiziksel düzen koşusu açık |
| OS-05 login item | Gerçek kullanıcı oturumunda `notFound → enabled → notRegistered`, ilk durum geri yüklendi | Tam logout/login yeniden başlatma açık |
| UI-04 tema/metin | Türkçe açık ve İngilizce koyu ekranlar; 60 karakter profil adı | Geçti |
| UI-04 VoiceOver | Erişilebilir etiket ve identifier otomasyonu mevcut | Gerçek VoiceOver ses sırası açık |
| UI-04 Full Keyboard Access | Ana komutlar ve sıra düğmeleri UI testinde çalışıyor | Sistem Full Keyboard Access ile manuel sıra açık |

## Karar

NFR-01 ve NFR-02 performans eşikleri bu cihazda geçmiştir. DM-026'nın bütün cihaz matrisi kabulü; minimum macOS 14 ortamı, dış disk/erişim reddi ve gerçek yardımcı teknoloji kontrolleri bulunmadığı için açık kalır. Bu eksikler performans başarısını geçersiz kılmaz ancak destek kapsamının tümünü kanıtlamaz.
