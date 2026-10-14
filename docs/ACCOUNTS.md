# Hesaplar: Apple ve Google ile giriş

Derin'de hesap isteğe bağlı. Giriş yapan kullanıcının gökyüzü (yıldızlar, Işık, takımyıldızlar,
rozetler, sözler, satın alınan sesler ve temalar) Firestore'da `users/{uid}` belgesinde saklanır.
Telefondaki kopya her zaman çalışmaya devam eder; internet yokken de uygulama aynen kullanılır,
bağlantı gelince eşitlenir.

- **İlk giriş**: Bu telefonda hesapsız kazanılan ilerleme hesaptakine eklenir, hiçbir şey silinmez.
- **İki telefon**: İki tarafta da değişiklik varsa birleştirilir (oturumların hepsi kalır, Işık iki
  taraftaki kazanç ve harcamaya göre toplanır). Kurallar: `Packages/OdakCore/Sources/OdakCore/Merge.swift`.
- **Çıkış**: Son bir eşitleme yapılır, ilerleme hesapta kalır ve bu telefondan kaldırılır.
- **Hesabı silme** (App Store bunu şart koşar): Ayarlar → Hesap → Hesabı sil. Kimlik bir kez daha
  doğrulanır, Firestore belgesi ve Firebase kullanıcısı silinir, Apple girişi iptal edilir.

Bunlar çalışsın diye senin yapman gereken adımlar aşağıda. Hepsi tarayıcıdan yapılır, Mac gerekmez.
`GOOGLE_SERVICE_INFO_PLIST` secret'ı eklenene kadar TestFlight sürümleri hesapsız çalışır,
giriş ekranı "Hesaplar bu sürümde henüz açık değil" der.

## 1. Firebase projesi

1. https://console.firebase.google.com → **Create a project** → ad: `Derin`. Google Analytics'i
   kapatabilirsin.
2. Proje açılınca **Add app → iOS**. Apple bundle ID: `com.beyzaerdogan.derin`, App nickname: `Derin`.
   App Store ID'yi boş bırak. **Register app**. Plist'i bu adımda indirme (Google'ı açtıktan sonra
   indireceğiz), kalan adımları **Next** ile geç.

## 2. Giriş yöntemleri

**Build → Authentication → Get started → Sign-in method**:

1. **Apple** → Enable → Save. Diğer alanları şimdilik boş bırakabilirsin (aşağıdaki 6. adım).
2. **Google** → Enable → "Support email" olarak kendi adresini seç → Save.

## 3. Firestore

1. **Build → Firestore Database → Create database**. Konum: `eur3 (europe-west)`. **Production mode**.
2. **Rules** sekmesine `firebase/firestore.rules` dosyasının içeriğini yapıştır → **Publish**.
   (Her kullanıcı yalnızca kendi belgesini okuyup yazabilir.)

## 4. GoogleService-Info.plist → GitHub secret

1. **Project settings** (sol üstteki dişli) → **Your apps** → Derin (iOS) → **GoogleService-Info.plist**
   dosyasını indir. Google girişini açtıktan sonra indirdiğin için içinde `REVERSED_CLIENT_ID` olmalı.
2. https://github.com/beyzaerdogaan/Odak/settings/secrets/actions → **New repository secret**.
   Name: `GOOGLE_SERVICE_INFO_PLIST`. Value: plist dosyasını Not Defteri ile açıp **tüm içeriğini**
   yapıştır. **Add secret**.

TestFlight iş akışı bu secret'tan plist'i oluşturur ve Google'ın dönüş adresini (URL scheme)
uygulamaya kendisi ekler. Dosya repoya eklenmez.

## 5. Sign in with Apple yetkisi

Bir şey yapman gerekmiyor: TestFlight iş akışı `com.beyzaerdogan.derin` kimliğinde
**Sign in with Apple** özelliğini App Store Connect API ile kendisi açar. İş akışı bu adımda
hata verirse: https://developer.apple.com/account/resources/identifiers/list → `com.beyzaerdogan.derin`
→ **Sign In with Apple** kutusunu işaretle → **Save**.

## 6. App Store'a çıkmadan önce: Apple hesap silme iptali

TestFlight için gerekmez. App Store incelemesi, hesabı silinen kullanıcının Apple girişinin de iptal
edilmesini ister. Bunun için Firebase'in Apple anahtarına ihtiyacı var:

1. https://developer.apple.com/account/resources/authkeys/list → **+** → ad: `Derin Sign in with Apple`,
   **Sign in with Apple** kutusu → Configure → Primary App ID: `com.beyzaerdogan.derin` → Save →
   Continue → Register → `.p8` dosyasını indir, **Key ID**'yi not al.
2. Firebase → Authentication → Sign-in method → **Apple** → "OAuth code flow configuration" bölümüne
   Team ID'ni, Key ID'yi ve `.p8` dosyasının içeriğini gir. Services ID alanı yalnızca web girişi
   için; boş bırakılabilir. **Save**.

## Sonra

Bu adımlardan sonra TestFlight için yeni bir derleme iste. Uygulama ilk açılışta bir kez giriş
ekranı gösterir; sonrasında Ayarlar → Hesap bölümünden giriş yapılabilir.
