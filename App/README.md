# Derin (iOS)

SwiftUI, iOS 26, Liquid Glass. Tasarım: `design/derin/*.dc.html` (yeni gök atlası tasarımı).

| Klasör | İçerik |
|---|---|
| `Packages/OdakCore` | Ödül kuralları: yıldız çekilişi, Işık hesabı, seri ve bulut, katmanlar, meteor yağmurları, mağaza, sözler. Arayüzsüz, `swift test` ile test edilir. |
| `App/Screens` | Evrenin, Odak kurulumu, Odak sürüyor, Ses ve müzik, Ödül anı, Takımyıldız tamamlandı, Gökyüzüm, Koleksiyon haritası, Derin gök, Meteor yağmuru, Işık yolculuğu, Ödüller ve Zenit |
| `App/Services` | Screen Time, sentezlenen ortam sesleri, Spotify (PKCE), StoreKit 2 (Zenit), bildirimler, Odak modu kestirmeleri |
| `Extensions` | Screen Time eklentileri (yalnızca `project-screentime.yml` derlemesinde) |
| `.github/workflows` | `ios.yml` her push'ta test eder ve derler; `testflight.yml` TestFlight'a yükler |

Kurulum ve TestFlight adımları: [`docs/TESTFLIGHT.md`](../docs/TESTFLIGHT.md).
