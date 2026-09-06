# ADR-004 — Sıralı açma, açık sonuç ve iptal

Tarih: 2026-09-05. Durum: tasarım için kabul; uygulama bekliyor.

## Bağlam

macOS uygulama/kaynak açma işlemleri harici yan etkilerdir. Bir URL'nin açılması veya app launch kabulü, hedef içeriğin hazır olduğunu garanti etmez. Bu işlemleri güvenilir bir transaction gibi geri almak mümkün kabul edilemez.

## Karar

Tek run, immutable snapshot, sıralı dispatch; continue/stop hata politikaları. Süreler 10 saniye/action ve 60 saniye/run. Timeout yalnız beklemeyi sonlandırır. Kullanıcı iptali kalan dispatch'leri durdurur; açılmış kaynakları kapatmaz. Otomatik retry veya rollback yok.

Preflight kaynak hatası + stop → hiçbir dispatch yok. Runtime hata + stop → zaten kabul edilenler kalır. Her action/run için tek terminal olay; late callback koruması run/action ID ve tek tamamlanma kapısıyla sağlanır.

## Alternatifler

Paralel dispatch daha hızlı görünebilir fakat sıra, odak ve hata görünürlüğünü zorlaştırır. Tam oturum restore/rollback, hedef uygulamaların özel state bilgisi ve kapatma yetkileri gerektirir; ilk ürün vaadi değildir.

## Sonuç

Tekrar çalıştırma yeni sekme/pencere oluşturabilir. UI “hazır” yerine kabul/başarısız sonuçlarını belirtir. Run değişiklikleri kayıtlı profil verisine otomatik yazılmaz. Ayrıntılı kaynak [EXECUTION-ENGINE](../08-EXECUTION-ENGINE.md); DM-009/010 ve EX testleri bu kararı doğrular.
