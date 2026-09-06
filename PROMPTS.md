# Hazır geliştirme promptları

Bu promptları GPT-5.6 Sol seçilmiş Launchestra görevinde kullan. İç proje dizini, hedefi ve modülleri şimdilik `DeskMode` adını korur. Modeli belge metniyle değiştirmen gerekmez. Her prompt gerçek uygulama davranışı ve doğrulamaya yöneliktir.

## 1. İlk oturum

```text
Launchestra'yı /Users/furkankoc/Desktop/projects/DeskMode/ içinde geliştireceğiz.
AGENTS.md, STATUS.md, docs/03-PRD.md, docs/05-ARCHITECTURE.md ve
TODO.md içindeki DM-001'i oku. DM-001'i uygula.

Hedef: macOS 14+ Swift 6 uygulama iskeleti ve yerel DeskModeKit paketini
kurmak; gerçek araç zinciriyle derleme/test durumunu kanıtlamak.
Belgelerde tarif edilen özellikleri uygulanmış kabul etme.
FlowBridge bu projenin dışında. Sadece bu proje içinde çalış.

Tam Xcode yoksa kullanılabilir Swift paket işlerini tamamla, uygulama
derlemesini yapılmış sayma ve somut engeli STATUS.md'ye kaydet.
Sonunda ilgili doğrulamaları, DM-001 durumunu ve sonraki işi yaz.
```

## 2. Sıradaki görev

```text
AGENTS.md, STATUS.md ve TODO.md'yi incele. Bağımlılıkları tamamlanmış
ilk uygulanabilir geliştirme görevini seç ve kabul kriterlerine kadar
tamamla. İlgili sözleşme belgelerini ihtiyaç oldukça oku.
Rutin yerel uygulama ve test kararlarını kendin ver.
Kapsamı sonraki sürüm özelliklerine genişletme.
İlgili testleri ve etkilenen hedef derlemesini çalıştır; gerçek sonuçları
TODO.md ve STATUS.md'ye yaz. Bu görevden sonra sonucu bildir.
```

## 3. Belirli milestone'u tamamlatma

```text
Launchestra M2 milestone'unu tamamla: DM-011–DM-017.
Önce bağımlılıkları ve gerçek kod durumunu doğrula; eksik bir zorunlu
önkoşul varsa kapsam içindeki önkoşulu tamamlayıp devam et.
Her görevi kullanıcı akışı, kabul kriteri ve ilgili testlerle bitir.
Gerekli kontroller geçtikçe ilerle; sırf daha fazla inceleme için aynı
kontrolleri tekrarlama. Milestone sonunda uygulamayı derle,
manuel olarak denediğin/deneyemediğin akışları açıkça ayır.
TODO ve STATUS'u güncelle; yayın veya push yapma.
```

## 4. Veri/motor doğruluk incelemesi

```text
Launchestra'nın mevcut veri ve çalıştırma kodunu docs/06-DATA-MODEL.md,
docs/08-EXECUTION-ENGINE.md ve docs/09-TEST-PLAN.md ile karşılaştır.
Önce gerçek veri kaybı, çift dispatch, timeout/iptal ve eski callback
sorunlarını araştır. Bulguları dosya/satır ve yeniden üretim kanıtıyla ver.
Bu görev incelemedir; kodu değiştirme. Bulgu yoksa kapsadığın testleri
ve doğrulanmamış platform davranışlarını belirt.
```

## 5. Bir hatayı düzeltme

```text
Hata: [gözlenen davranış ve yeniden üretim adımları].
Beklenen davranış: [ilgili FR/Test ID veya kullanıcı sonucu].
Mevcut kod ve ilgili sözleşmeyi incele, nedeni belirle ve düzelt.
Hatanın tekrarını yakalayan en küçük anlamlı testi ekle/güncelle.
Gerekli derleme ve ilgili testleri çalıştır. Alakasız refactor ekleme.
Değişiklik, doğrulama ve kalan sınırlamayı bildir; STATUS'u güncelle.
```

## 6. Arayüz tamamlama

```text
docs/04-UX-SPEC.md ve mevcut native bileşenleri temel alarak
[ekran/akış] işini tamamla. Boş, yükleniyor, hata ve başarılı durumları
gerçek state modeline bağla. İngilizce/Türkçe, açık/koyu tema ve
klavye kullanımını doğrula. UI'ı açıp görsel olarak inceleyebiliyorsan
incele; yapamadığın manuel doğrulamayı açık belirt.
Dekoratif yeni özellik yerine bu akışın kullanılabilirliğini tamamla.
```

## 7. Yayın hazırlığı

```text
DM-027 ve DM-028 kapsamındaki Launchestra beta paketini hazırlanabilir
ve denetlenebilir hâle getir. docs/14-RELEASE.md'yi izle.
Gerçek test/build sonuçlarını topla; sürüm, lisans, gizlilik ve paket
kontrollerini tamamla. Sertifika/yayın erişimi yoksa yerel hazırlığı
bitirip eksik olanı somutlaştır. İmzalanmamış paketi notarize diye sunma.
Bu prompt GitHub'a yayınlama, push veya kullanıcıya mesaj gönderme
yetkisi vermez. Sonunda hazır artifact ve kalan yayın adımını bildir.
```
