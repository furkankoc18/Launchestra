# Güvenlik tasarımı ve bildirim

Durum: v0.1 beta adayının güvenlik sözleşmesi. Kaynak kod [Launchestra GitHub deposunda](https://github.com/furkankoc18/Launchestra) yayımlanmıştır; desteklenen binary sürüm ve özel güvenlik bildirim kanalı henüz yoktur. Kaynak bağımlılığı/lisans incelemesi tamamlanmıştır.

## Tehdit modeli

Korunan varlıklar: yerel profil dosyaları, kullanıcının dosya yolları ve URL'leri, istem dışı eylem başlatmama, sistem ayarları ve signing secrets. Güven sınırları: UI girdisi→domain validasyonu; JSON→domain; domain→OS açma çağrıları; callback→run state; uygulama→tanılama logu.

| Tehdit | Savunma |
| --- | --- |
| URL veya klasör adının komuta dönüşmesi | Shell/script yok; tipli NSWorkspace çağrısı, URL allowlist |
| JSON dosyasıyla desteklenmeyen action çalıştırma | Strict version/type/alan validasyonu; auto-run yok |
| Tekrarlanan tıklama veya callback | Tek run gate, run/action ID ve complete-once |
| Bozuk/çok büyük dosya | Önce boyut kontrolü, sınırlar, sağlam backup, read-only hata |
| Bookmark/path veya URL token sızıntısı | Ham içerik loglanmaz, issue şablonunda anonimleştirme |
| İzinleri gereksiz genişletme | MVP'de AX/Input Monitoring/Automation yok; deneyle gerekçe |
| CI signing sırrının fork'a sızması | Ayrı yetkili release işi, secrets izolasyonu |
| Gelecek profil import'undan istem dışı çalıştırma | V0.1 import yok; ileride inert önizleme ve kaynak yeniden eşleme |

## Sınırlar

Launchestra kullanıcı hesabı yetkileriyle çalışan yerel, sandbox dışı bir uygulama olarak tasarlanmıştır. Aynı kullanıcı yetkisindeki kötü amaçlı programın profil veya uygulama dosyalarını değiştirmesine karşı tam izolasyon iddiası yoktur. Bookmark dosya erişim yetkisi veya şifreleme değildir. Şifre/token saklama hizmeti sunulmaz.

Kaydedilmiş URL'nin açılması varsayılan tarayıcıya ağ isteği yaptırabilir; Launchestra hedef sitenin güvenilirliğini denetlediğini söylemez. URL kaydetme/ön kontrol sırasında kendi ağıyla fetch yapmaz. HTTPS'i ürün olarak teşvik eder ama localhost geliştirici akışı için HTTP geçerlidir.

## Zorunlu uygulama kontrolleri

- Gizli shell fallback, `osascript` veya kullanıcı metninden program çalıştırma eklenmez.
- Uygulama açılınca veya JSON yüklenince profil kendiliğinden başlamaz.
- Kısayol profili çalıştırmak için açık kullanıcı ataması gerektirir.
- OS hatası veya timeout sonrası otomatik retry/rollback yoktur.
- Yeni izin, ağ istemcisi, updater veya import özelliği eklendiğinde tehdit modeli güncellenir.

DM-023 uygulaması dışarıdan serbest metin kabul etmeyen `DiagnosticRecord` tipi üzerinden yalnız olay, geçici UUID, sabit `RunErrorCode` ve tamsayı süre alanlarını OSLog'a yazar. Sentinel unit testi ile gerçek Console örneği URL yolu/query, profil adı, bookmark ve ham hata metninin kayda girmediğini doğruladı. Telemetri, crash-upload SDK'sı ve Launchestra tarafından başlatılan ağ istemcisi bulunmuyor.

## Açık bildirme

Özel güvenlik bildirim kanalı henüz kurulmadı. Gerçek depo `https://github.com/furkankoc18/Launchestra` adresindedir; GitHub Private Vulnerability Reporting depo ayarlarından etkinleştirilmelidir. Bu DM-027'nin açık yayın kapısıdır; kanal etkinleştirilmeden özel bildirim bağlantısı varmış gibi gösterilmez.

Hassas yol, URL token'i, private key veya kullanılabilir exploit ayrıntısını public issue'ya koymayın. Özel kanal hazır değilse genel, sır içermeyen bir iletişim isteğiyle bakımcıya ulaşın. Hedef yanıt süresi henüz taahhüt edilmemiştir.
