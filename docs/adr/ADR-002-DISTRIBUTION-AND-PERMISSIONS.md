# ADR-002 — Dağıtım ve izin sınırı

Tarih: 2026-09-05. Durum: tasarım için kabul; yayın yapılmadı.

## Bağlam

V0.1 yalnız uygulama/klasör/URL açar. İleride terminal, ses ve pencere entegrasyonları düşünülebilir; bugün bunlar için izin istemek gereksizdir. İlk dağıtımın Mac App Store inceleme/sandbox uyarlamasına bağlı olmaması tercih edildi.

## Karar

Doğrudan Developer ID imzalı/notarize dağıtım; Release Hardened Runtime açık, App Sandbox v0.1'de kapalı. Bu seçim NSWorkspace açma için sandbox'ın kesin imkânsız olduğu iddiasına dayanmaz; ürünün başlangıç dağıtım tercihidir.

V0.1 Accessibility, Input Monitoring, Automation, Screen Recording veya Microphone kullanmaz. Kullanıcının seçtiği kaynaklarda TCC kısıtları geçerlidir. Bookmark, izin verilmiş sayılma yöntemi değildir.

## Alternatifler ve sonuç

App Sandbox + Mac App Store ileride ayrı uyumluluk projesi olabilir. Bugünkü karar daha az izolasyon getirir; bu nedenle action allowlist, script bulunmaması ve en az veri yaklaşımı önemlidir. İmza/notarization hesabı olmadan yerel geliştirme sürer fakat resmî dağıtım hazır sayılmaz.

DM-002 izin davranışını, DM-023 tanılamayı ve DM-028 imzalı paketi doğrular. [Apple dağıtım kaynağı](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
