# GPT-5.6 Sol ile geliştirme rehberi

## Model ve yaklaşım

Kullanıcının seçimi **GPT-5.6 Sol**; teknik model adı `gpt-5.6-sol`. Resmî model sayfası bu adı doğrular. Bu proje model erişimi, API anahtarı veya ücretli servis gerektiren bir uygulama geliştirmeyi hedeflemez. Sol, kodlama aracıdır. [Model kaynağı](https://developers.openai.com/api/docs/models/gpt-5.6-sol).

Resmî prompting rehberi tekrar eden talimatları azaltmayı, hedef/kısıt/kanıt ve bitiş kriterlerini açık tutmayı önerir. Bu yüzden kısa AGENTS.md yanında göreve göre okunacak ayrıntı belgeleri kullanıyoruz. [GPT-5.6 prompting rehberi](https://developers.openai.com/api/docs/guides/model-guidance?model=gpt-5.6#prompting-best-practices).

Bu projeye özgü öneri: normal özellik görevlerinde mevcut reasoning ayarını koruyarak başla; sıfırdan seçim gerekiyorsa `medium` makul başlangıçtır. Veri kaybı/iptal yarışları gibi zor görevlerde eksik kriter veya test varsa önce onları düzelt; daha yüksek effort'u gerçek sonuç iyileşmesine göre değerlendir. Bu bir model performans garantisi değildir. API parametrelerini Codex UI ayarlarıyla eşitleyen varsayım yapılmaz.

## Bağlam paketi

Kalıcı kısa rehber [AGENTS.md](../AGENTS.md), ilerleme [STATUS.md](../STATUS.md), görev otoritesi [TODO.md](../TODO.md). Ajan bunlardan sonra yalnız ilgili davranış sözleşmesini açar. AGENTS.md'nin çalışma dizini kapsamı önemlidir; bu nedenle DeskMode kökünde çalış. [Codex AGENTS.md rehberi](https://learn.chatgpt.com/docs/agent-configuration/agents-md).

## Her görev için yeterli girdi

1. Görev ID ve kullanıcıya görünen hedef.
2. İlgili belgeler ve mevcut kod kanıtı.
3. Kapsam sınırı ve tamamlanma kriteri.
4. Çalıştırılacak ilgili doğrulama; ortam engeli varsa alternatif kanıt.

Görevler dosya sayısıyla yapay biçimde sınırlandırılmaz; bir davranışı uçtan uca tamamlayacak küçük kapsam seçilir. Örneğin profil kaydetme görevi model, repository, view model ve testte değişiklik gerektirebilir.

## Çalışma döngüsü

Mevcut durumu oku → ilgili sözleşmeyi anla → kapsam içindeki değişikliği uygula → uygun test/derlemeyi yap → sonucu ve devam bilgisini kaydet. Her adım için kullanıcıdan tekrar izin istemek gerekmez. Tamamlanma kanıtı yoksa kutuyu işaretleme. Uyumsuz API davranışında kaynak veya yerel SDK kontrolü yap; hayalî API veya shell fallback ekleme.

Bir görev tamamlandıktan sonra yalnız yeni değişiklik/failure kanıtı gerektiriyorsa testi tekrarla. Kullanıcı çoklu görev tamamlamayı istemişse kabul kriterleriyle ilerlemeyi sürdür; promptta tek görev istendiyse görev sonunda sonuç bildir. Bu rehber kendiliğinden başka ajan/model başlatma veya yayın yetkisi vermez.

## Devir çıktısı

```text
Tamamlanan: DM-0xx — somut davranış
Değişiklikler: kritik dosyalar ve nedenleri
Doğrulama: çalıştırılmış komutlar ve sonuçlar
Manuel kontrol: yapıldı / yapılmadı, cihaz ve senaryo
Engel: varsa somut eksik; tahminî başarı yok
Sonraki: bağımlılıkları karşılanmış görev ID'si
```

## Yaygın hata biçimleri ve düzeltme

| Gözlenen sorun | Düzeltme |
| --- | --- |
| Bir görev tüm uygulamanın yeniden tasarımına dönüyor | Tek kullanıcı davranışını ve PRD kapsamını promptta belirt |
| Kod var, doğrulama yok | Görevin kabul örneğini ve etkilenen build hedefini ver |
| Gecikmiş callback yanlış run'ı değiştiriyor | EX-05/06 fake event dizisini ekle, completion gate sözleşmesini okut |
| Yeni kısayol kaydolmadan etkinleşiyor | JSON tek otorite ve save-failure KB-01 senaryosunu göster |
| Tam Xcode yokken build başarılı deniyor | Gerçek komut çıktısını ve yapılmayan UI kontrolünü raporlat |
| Her oturum eski planı tekrar üretiyor | STATUS içindeki sonraki görevi ve uygulama isteğini açık ver |

Bu tablo Sol'un kesinlikle bu hataları yapacağı iddiası değil, projeye özgü hata önleme rehberidir.
