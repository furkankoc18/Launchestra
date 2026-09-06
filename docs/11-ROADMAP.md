# Yol haritası

Takvim taahhüdü yerine ölçülebilir milestone kullanılır. Tamamlanma hızı Swift/macOS deneyimine, Xcode erişimine ve gerçek cihaz testlerine bağlıdır. Bu belgeler hiçbir milestone'un uygulandığını göstermez.

| Milestone | Görevler | Kullanıcıya görünen çıktı | Çıkış kriteri |
| --- | --- | --- | --- |
| M0 — Temel ve belirsizlik | DM-001–004 | Minimal menü deneyi, doğrulanmış açma/kısayol yolu | Ortam kayıtlı, teknik deneyler gerçek sonuçlu; görüşmeler bekliyorsa ayrı kayıt |
| M1 — Çekirdek | DM-005–010 | Test edilebilir model, güvenli kayıt, deterministik runner | JSON ve motor kritik testleri geçer |
| M2 — Kullanılabilir akış | DM-011–017 | Profil oluştur → kaydet → çalıştır → sonuç gör | Üç eylemli dikey akış, hata/iptal ekranı |
| M3 — Günlük kullanım | DM-018–024 | Kısayol, tercihler, kurtarma, erişilebilirlik | V0.1 işlevleri ve hedefli testler tamam |
| M4 — Beta hazırlığı | DM-025–028 | Tekrarlanabilir build, ölçüm raporu, hazır paket | CI, cihaz matrisi, lisans ve dağıtım checklist'i |
| M5 — Yayın ve geri bildirim | DM-029–030 | Yetkili yayın ve ilk kullanıcı gözlemleri | Gerçek yayın kanıtı ve beta bulguları |

DM-004 görüşmeleri geliştirmeyi gereksiz durdurmaz; teknik M0 tamamlanabilir. Görüşme bulguları ürün yönünü değiştiriyorsa kapsam önce PRD'de güncellenir. Yayın erişimi olmaması yerel paket/test işlerinin yapılmasını engellemez.

## Önerilen ilk geliştirme sırası

DM-001 → DM-002 → DM-003 → DM-005 → DM-006 → DM-007 → DM-008 → DM-009 → DM-010. Sonra DM-011–017 ile UI dikey akışı. DM-004 kullanıcı araştırması uygun zamanda kullanıcı tarafından yürütülebilir. Bu sıra bağımlılık rehberidir; aynı görev içinde farklı katmanlarda küçük değişiklikler yapılabilir.

## V0.2 — Paylaşım ve proje adaptörleri

- DM-101: Sürümlü taşınabilir profil import/export. Yerel yollar/bookmark/kısayollar export edilmez; kullanıcı hedef makinede kaynakları bağlar. İçe aktarma hiçbir şeyi çalıştırmaz, önizleme ve yeni UUID üretimi gerekir.
- DM-102: Belirlenmiş editörlere klasör açma adaptörleri. Desteklenen uygulama/sürüm listesi ve kurulu değil fallback davranışı.
- DM-103: Terminali belirli dizinde açma. Önce teknik deney; kamuya açık/supported yol, özel karakter güvenliği ve gerekiyorsa Automation izni ayrı tasarım.
- DM-104: Beta bulgularına göre profil şablonları. Şablonlar inert veri olur.

Bu sürüm başlarken veri şeması ve PRD genişletilir. V0.1 çekirdeğine henüz kullanılmayan şablon/adapter engine eklenmez.

## V0.3 — Çalışma ortamı ve ses

- DM-201: Monitör bağlantısı/ayrılmasına göre profil **önerisi**. Debounce, uyku/uyanma ve kimlik belirsizliği testleri.
- DM-202: Kullanıcının etkinleştirdiği ortam kuralı; çakışmada öncelik ve manuel override. Otomatik run ancak ayrı açık ürün kararıyla.
- DM-203: Ses çıkışı, mikrofon varsayılanı ve desteklenen cihazlarda ses seviyesi; uygulamaya özel override sınırlarının görünür olması.

## V0.4 ve sonrası — Talebe bağlı

- DM-301: Accessibility ile sınırlı pencere yerleşimi; public API sınırları ve çoklu monitör testleri.
- DM-302: İmzalı otomatik güncelleme altyapısı ve bağımlılık güvenliği.
- DM-303: Intel için gerçek cihaz/build doğrulamasına bağlı Universal dağıtım değerlendirmesi.

Cloud sync, LLM, çalıştırılabilir eklenti pazarı ve ücretli plan için şu anda geliştirme kararı yoktur.

## Bir milestone'u kapatma

Kabul kriterleri doğrulanır, STATUS ve TODO gerçek sonuçlarla güncellenir, kalan riskler yazılır. Tasarım belgesi tamamlanması kod görevi tamamlanması değildir. Performans ölçülmediyse hedefi sağlandı diye işaretleme. Tekrarlanan hatalar görev boyutunu küçültmeyi veya teknik deneyi gerektirir; daha fazla özellik eklemeyi değil.
