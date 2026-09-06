# Gizlilik — v0.1 davranışı

Bu metin DM-024 sonundaki gerçek yerel uygulama davranışını açıklar. Yayın iletişim kanalı ve dağıtım bilgileri beta hazırlığında eklenecektir.

## Yerel tutulan veriler

Profil adları, seçilen uygulama kimlikleri, klasör bookmark'ları/yol bilgileri, URL'ler ve atanmış kısayollar Application Support içinde saklanır. Onboarding tercihi UserDefaults'ta tutulur. Girişte başlatma durumu macOS'un kayıt sistemiyle yönetilir. Son çalıştırma sonucu yalnız bellekte tutulur.

Profiller ve son geçerli yedek kullanıcı silene kadar diskte kalır. Bozuk veri kurtarılırken oluşturulan recovery kopyaları ayrıca korunur; bu kopyalar da hassas kaynak bilgileri içerebilir. Otomatik bulut senkronizasyonu veya uzak profil yedeği yoktur. Kullanıcının macOS yedekleme araçları bu dosyaları ayrıca yedekleyebilir.

## Ağ ve üçüncü taraflar

V0.1 uygulaması hesap, analitik, reklam, crash upload veya LLM servisi içermez. Profil kaydederken URL içeriği indirilmez. Kullanıcı profili çalıştırdığında URL'ler varsayılan tarayıcıya gönderilir; tarayıcı ve açılan diğer uygulamalar kendi ağ/gizlilik davranışlarına sahiptir. Bu nedenle bütün çalışma akışının tamamen ağsız olduğu iddia edilmez.

OSLog tanılaması yalnız sabit olay/kod, milisaniye süre ve her çalıştırmada üretilen geçici run/action kimlikleriyle sınırlanır; tam URL, profil adı, yerel yol, bookmark ve ham `NSError` açıklaması yazılmaz. Kontrollü Console incelemesinde sentetik profil adı, URL yolu ve query sentinel'i bulunmadı. OS tanılama kaydının saklama süresini macOS yönetir; uygulama bunun için kesin gün sayısı vaat etmez.

## İzinler

V0.1 için ekran kaydı, kamera/mikrofon kaydı, tüm klavye girişini izleme veya diğer uygulamaları AppleScript ile yönetme planlanmıyor. Kullanıcının seçtiği klasöre erişirken macOS kendi izin kısıtlarını uygulayabilir. Girişte başlat kullanıcı tarafından etkinleştirilir.

## Veri kontrolü

Profil silmek o profili bir sonraki ana kayıttan kaldırır; mevcut backup/recovery kopyalarında önceki veriler bulunabilir. Tüm yerel veriyi kaldırmak isteyen kullanıcı uygulamadan çıkarak veri dizinini Finder'dan silebilir; yedekleri de kapsadığı anlatılır. Kullanıcı kaynak klasörleri veya açılan uygulamalar bu işlemle silinmez. Tam kaldırma adımları [yayın rehberinde](docs/14-RELEASE.md).

Sorular ve talepler için gerçek iletişim kanalı DM-027'de eklenecektir; bu taslakta uydurulmuş iletişim adresi yoktur.
