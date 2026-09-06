# ADR-003 — Sürümlü yerel JSON

Tarih: 2026-09-05. Durum: tasarım için kabul; uygulama bekliyor.

## Bağlam

İlk kapasite 50 profil × 30 eylem. Karmaşık sorgu, cihazlar arası eşitleme ve çoklu kullanıcı yok. Verinin bozulmaması ve şema değişikliklerinin görünür olması önemlidir.

## Karar

Tek sürümlü JSON store, array tabanlı sıra, UUID kimlikleri. Repository actor, revision/fingerprint kontrolü, uygulama ömürlü tek yazıcı kilidi, atomik dosya replace ve son doğrulanmış backup. Yeni/bilinmeyen şemada salt okunur hata; otomatik downgrade veya boş sıfırlama yok.

Profil içerikleri/kısayollar aynı otoritede. Onboarding UserDefaults; run sonuçları bellek. V0.1 yerel bookmark içeren veri taşınabilir export formatı değildir.

## Alternatifler

SwiftData/Core Data veya SQLite daha karmaşık sorgu/migration ihtiyaçlarında değerlendirilebilir. Bu ölçekte ek veritabanı katmanı gerekli görülmedi. Tüm profilleri UserDefaults'a koymak açık şema/yedek/kurtarma sözleşmesini daha belirsiz bırakır.

## Sonuç

Her kayıtta store yeniden yazılır; kapasite bilinçli sınırlıdır. Güvenli yazım ve crash recovery doğru uygulanmalıdır; “JSON basit” ifadesi veri kaybı riskini ortadan kaldırmaz. Strict unknown-field politikası her şema genişlemesinde version artışı gerektirir. DM-005/006/021 ve ST testleri kanıttır.
