# Derin'i TestFlight'a çıkarmak

Mac gerekmez. Derleme, imzalama ve yükleme GitHub Actions'ta bir macOS makinesinde yapılır.
Senin yapman gerekenler Apple ve GitHub tarafındaki hesap adımları. Hepsi tarayıcıdan yapılır.

## 1. Apple Developer Program

1. https://developer.apple.com/programs/enroll üzerinden Apple Developer Program'a katıl (yıllık ücretli).
   Bireysel hesap yeterli. Onay birkaç saat ile birkaç gün sürebilir.
2. Onaylandıktan sonra https://developer.apple.com/account → **Membership details** bölümündeki
   **Team ID**'yi (10 karakter, örn. `A1B2C3D4E5`) bir kenara yaz.

## 2. Bundle ID

Uygulamanın kimliği `com.beyzaerdogan.derin`. Başka bir önek istersen GitHub'da `BUNDLE_ID_PREFIX`
değişkenini değiştir (aşağıda), uygulama `<önek>.derin` olur.

1. https://developer.apple.com/account/resources/identifiers/list → **+** → **App IDs** → **App**.
2. Description: `Derin`, Bundle ID: **Explicit** → `com.beyzaerdogan.derin`.
3. Capabilities listesinde şimdilik bir şey işaretleme. **Continue → Register**.

## 3. App Store Connect'te uygulama kaydı

1. https://appstoreconnect.apple.com/apps → **+** → **New App**.
2. Platform **iOS**, Name **Derin** (alınmışsa “Derin: Odak” gibi bir varyant), Primary Language **Turkish**,
   Bundle ID olarak 2. adımdakini seç, SKU: `derin-ios`.

## 4. App Store Connect API anahtarı (imzalama ve yükleme için)

1. https://appstoreconnect.apple.com/access/integrations/api → **Team Keys** → **+**.
2. Name: `GitHub Actions`, Access: **Admin** (sertifikaları otomatik oluşturabilmesi için gerekli).
3. **Download API Key** ile `.p8` dosyasını indir. Sadece bir kez indirilebilir, sakla.
4. Sayfadaki **Issuer ID** ve anahtarın **Key ID** değerlerini not et.

## 5. GitHub secret'ları

Depo → **Settings → Secrets and variables → Actions**.

**Secrets** sekmesi → **New repository secret**:

| Ad | Değer |
|---|---|
| `APPLE_TEAM_ID` | 1. adımdaki Team ID |
| `ASC_KEY_ID` | 4. adımdaki Key ID |
| `ASC_ISSUER_ID` | 4. adımdaki Issuer ID |
| `ASC_KEY_P8` | `.p8` dosyasının tüm içeriği (Not Defteri ile aç, `-----BEGIN PRIVATE KEY-----` dahil hepsini yapıştır) |

**Variables** sekmesi (isteğe bağlı):

| Ad | Değer |
|---|---|
| `BUNDLE_ID_PREFIX` | Varsayılan `com.beyzaerdogan` dışında bir önek istersen |
| `SPOTIFY_CLIENT_ID` | 8. adım, Spotify hesabı bağlama için |

## 6. İlk TestFlight yüklemesi

1. Depoda varsayılan dalın `main` olması gerekiyor (Settings → General → Default branch), yoksa
   **Run workflow** düğmesi görünmez.
2. **Actions → TestFlight → Run workflow** (Screen Time kutusu kapalı kalsın).
   Ya da bir sürüm etiketi gönder: `v1.0.0`.
3. İş bitince derleme App Store Connect → uygulaman → **TestFlight** sekmesinde birkaç dakika içinde
   “Processing” olarak görünür. İşlenince:
   - **Internal Testing** → **+** ile bir grup oluştur, kendini ekle. Apple incelemesi gerekmez.
   - iPhone'una **TestFlight** uygulamasını kur, davet e-postasındaki bağlantıyla Derin'i yükle.
4. İlk yüklemede **Export Compliance** sorulmaz (uygulama şifreleme kullanmıyor diye işaretli).

Her yeni yüklemede derleme numarası otomatik artar.

## 7. Uygulama engelleme için Apple izni (Family Controls)

Diğer uygulamaları kilitlemek Apple'ın Screen Time API'sini kullanıyor. TestFlight ve App Store için
Apple'dan ayrıca izin istemek gerekiyor. İzin gelene kadar uygulama engelleme olmadan çalışır
(odak, yıldızlar, Işık, sesler, her şey çalışır; sadece diğer uygulamalar kilitlenmez).

1. https://developer.apple.com/contact/request/family-controls-distribution adresinden başvur.
   Kısa açıklama: “Derin is a focus timer. During a session the user picks apps to block with
   FamilyActivityPicker; shields are lifted when the session ends.”
2. Onay e-postası gelince: Identifiers → `com.beyzaerdogan.derin` → **Family Controls** ve
   **App Groups** yeteneklerini işaretle. App Groups için `group.com.beyzaerdogan.derin` grubunu oluştur.
   Aynısını eklentiler için de yap (`.activity-monitor`, `.shield-configuration`, `.shield-action`;
   ilk Screen Time derlemesi bunları otomatik kaydeder, sonra yeteneklerini işaretlemen yeterli).
3. **Actions → TestFlight → Run workflow**, bu kez **Screen Time** kutusunu işaretle.
   Kalıcı yapmak için `SCREEN_TIME` değişkenini `YES` yap.

## 8. Spotify (isteğe bağlı)

Olmadan da çalışır: önerilen listeler Spotify uygulamasında açılır. Kullanıcının kendi listeleri
ve uygulamadan çalma için:

1. https://developer.spotify.com/dashboard → **Create app**.
2. Redirect URI: `derin://spotify-callback`, API: **Web API**.
3. Client ID'yi GitHub'da `SPOTIFY_CLIENT_ID` değişkenine yaz.
4. Spotify geliştirici modunda en fazla 25 kullanıcıya izin verir; herkese açmak için Spotify'a
   “extended quota” başvurusu gerekir.

## 9. Zenit aboneliği

Uygulama `derin.zenit.monthly` ve `derin.zenit.yearly` ürünlerini arar.

1. App Store Connect → uygulaman → **Monetization → Subscriptions** → grup adı **Zenit**.
2. İki otomatik yenilenen abonelik: Product ID'ler yukarıdaki gibi, süreler 1 ay ve 1 yıl.
3. Fiyatı burada belirlersin (tasarımdaki [FİYAT]). Uygulamadaki satın alma ekranı fiyatı App Store'dan okur.
4. Abonelik satabilmek için **Business → Agreements** altındaki Paid Apps sözleşmesini ve banka/vergi
   bilgilerini tamamla. TestFlight'ta satın alımlar sandbox'tır, ücret alınmaz.

## Mac'in olursa

```sh
brew install xcodegen
xcodegen generate          # ya da: xcodegen generate --spec project-screentime.yml
open Odak.xcodeproj
```

Kendi Team ID'ni `Config/Local.xcconfig` dosyasına `DEVELOPMENT_TEAM = A1B2C3D4E5` olarak yazabilirsin
(git'e girmez).
