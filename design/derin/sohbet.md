# Derin — Odak ve Verimlilik Uygulaması (iOS) · Sohbet Kaydı

Tarih: 8 Ekim 2026
Tasarım: Claude'daki “Derin — Odak ve Ödül Sistemi” Design canvas'ı (11 ekran)

---

## 1. İstek: Uygulama ve ödül sistemi

> Bir odaklanma & verimlilik uygulaması yapacağız. Bu uygulama iOS için geliştirilecek, sonrasında Android için de yapacağız ama şimdilik iOS olarak düşün. Uygulama odak gerektiren herhangi bir task için kullanılabilir olacak. Kişiler odak süresi tanımlayabilecek ve bu süreçte telefona bakmamaları sağlanacak. Ekranda uygulamaları vs. bloklayabilir ama bunu kullanıcı seçimine de bırakabiliriz, daha iyi olur. Aynı zamanda arama ve mesajları da, yani genel bildirimleri de bloklayabilir. Kullanıcı bloklanacak uygulamaları kendisi seçsin. Odak süresi tamamlandığında kişiyi ödüllendirmemiz lazım. Bu ödüllendirme sistemi nasıl olabilir, bunu düşün ve tasarla.

### Yanıt

Tasarımı açık olan Design artifact'ına koydum. Beş iOS ekranı var ve birbirine bağlı, Play ile ekranlar arasında gezebilirsin: odak kurulumu, odak sürerken, ödül anı, Gökyüzüm (ilerleme) ve ödüller. Uygulamaya şimdilik **"Derin"** adını verdim. Gece göğü temasını seçtim, sıcak sarı vurgu rengini Tweaks'ten değiştirebilirsin.

#### Ödül sistemi: üç katman

**1. Yıldız (anında, görsel ödül)**
- Tamamlanan her oturum gökyüzüne bir yıldız ekler. Oturum uzadıkça yıldız büyür.
- Yıldızlar birleşip takımyıldızlara dönüşür. Bir takımyıldız tamamlanınca yeni bir tema açılır.
- Vazgeçersen yıldız söner ama odakladığın dakikalar istatistiklerde kalır. Ceza hafif ve kayıp hissi az olsun istedim.

**2. Işık (biriktirilen puan)**
- Odaklanılan her dakika = 1 Işık.
- Hiç telefona bakmadan bitirirsen +%20.
- Seri bonusu her gün +%2 artar, en fazla +%20 olur.
- Katı modda kazanç ×1.5 olur (süre bitmeden kilit açılmaz).
- Işık mağazada harcanır: gök temaları, odak sesleri, seri koruyucu "bulut". İleride Işık ile gerçek bir fidan dikilmesine katkı da eklenebilir.

**3. Kendine sözler (gerçek hayatta ödül)**
- Kullanıcı kendi ödülünü tanımlar, örneğin "10 saat odak → yeni kitap" ya da "7 gün seri → kahvaltıya çık".
- Uygulama ilerlemeyi gösterir, hedefe ulaşınca kutlar.
- Bence en güçlü motivasyon bu katman, çünkü ödülü kişi kendisi seçiyor.

**Destekleyenler:**
- **Seri:** bir gün atlanırsa seri koruyucu "bulut" o günü otomatik kapatır. Böylece seriyi kaybetme stresi azalır.
- **Rozetler:** "İlk ışık", "90 dk maraton", "Gece kuşu" gibi kilometre taşları.
- **Haftalık özet:** Gökyüzüm ekranında gösteriliyor.

#### iOS'ta bilmen gereken teknik kısıtlar

- **Uygulama engelleme:** Screen Time API ile yapılır (`FamilyControls`, `ManagedSettings`, `DeviceActivity`). Kullanıcı engellenecek uygulamaları `FamilyActivityPicker` ile kendisi seçer. Uygulama isimlerini düz metin olarak değil, sadece token olarak alırsın. App Store dağıtımı için Apple'dan **Family Controls entitlement** istemen gerekir, başvuruyu erken yap.
- **Arama ve mesajlar:** üçüncü parti bir uygulama bunları sistem genelinde susturamaz. Yapılabilecek olan: kullanıcıya bir kez "Derin" adında bir iOS Odak modu kurdurmak (favoriler arayabilsin seçeneğiyle) ve bunu Kestirmeler otomasyonuyla açmak. `SetFocusFilterIntent` ile de uygulama o moda tepki verir.
- **"Telefona bakmadın" ölçümü:** kilitli bir uygulamayı açma denemelerini `ShieldActionExtension` ile sayabilirsin. Uygulamanın arka plana geçişlerini de takip ederek bonusu hesaplarsın.

Android'de bunların karşılığı `UsageStatsManager`, Accessibility Service ve `NotificationManager` (Rahatsız Etmeyin) olur. Android'de arama ve bildirim kontrolü daha kolay.

---

## 2. İstek: Gerçek takımyıldızlar, sesler, Spotify, geniş mağaza

> Yıldız mantığı çok güzel oldu. Acaba yıldız mantığını gerçek hayata da mı taşısak? Yani gerçek hayattaki takımyıldızları oluştursa? Çok mu sayılı olur, sence ne dersin? Takımyıldızlar oluşunca onlarla ilgili bilgi ve ekstra ödül verilsin ama her bir yıldız rastgele bir takımyıldızın yıldızı olsun. Rastgele olsun ama takımyıldızı tamamlamak imkansız olmasın, sadece zor olsun. Dediğin gibi odak anında açılabilecek rahatlatıcı sesler de ekle veya Spotify üzerinden odaklanma için playlist de açabilsin, buradan Spotify'a bağlantı kursun. Mağazayı da genişletebilirsin.

### Yanıt

**Fazla mı olur?** Bence olmaz, tam tersine uygulamaya kimlik kazandırır. Gökyüzünde 88 resmi takımyıldız var ama hepsini koymak bunaltır. **16 tanınmış takımyıldızlık bir katalog** önerdim: Büyük Ayı, Avcı, Kassiopeia, Kuğu, Lir, Akrep ve burçlar gibi. Kolaydan zora 4 kademede açılıyorlar. Tamamlanan her takımyıldız kullanıcıya kısa bilgiler, hangi mevsimde Türkiye'den nereye bakılınca görüleceği ve ekstra ödüller kazandırıyor.

**Rastgele ama imkansız değil, sadece zor:**
- Aynı anda 3 takımyıldız açık oluyor. Her oturumda bunlardan birinin **henüz yanmamış** yıldızlarından biri rastgele düşüyor. Aynı yıldız iki kez gelmiyor, yani her oturum seni bir tamamlamaya yaklaştırıyor. Tamamlamak garanti, değişen sadece sıra.
- Tamamlanmaya yakın takımyıldızın şansı biraz daha yüksek.
- Zorluğu **parlak yıldızlar** getiriyor (Betelgeuse, Vega, Deneb gibi). Bunlar yalnızca 60 dakikadan uzun oturumlarda ya da katı modda düşüyor.
- Şanssızlık koruması: 4 oturum üst üste işe yarar bir yıldız gelmezse sonraki oturum eksik yıldızı garanti ediyor.
- **Teleskop** güçlendiricisiyle sonraki yıldızı kendin seçebiliyorsun.
- Bir takımyıldız tamamlanınca yerine sıradaki açılır.

**Değişen ve eklenen ekranlar:**
- **Odak ekranı:** altta çalan müzik/ses kartı. Sayaçta "Hangi yıldız? Bitince göreceksin" yazıyor, merak duygusunu besliyor.
- **Ses ve müzik (yeni):** 8 ortam sesi (Yağmur, Orman, Dalga, Şömine, Kahverengi gürültü, Kış gecesi, Kütüphane, Kahvehane), en fazla ikisi karıştırılabiliyor. Bazı sesler mağazadan ya da takımyıldız ödülüyle açılıyor. Bağlı Spotify hesabından çalma listesi seçiliyor.
- **Takımyıldız tamamlandı (yeni):** takımyıldızın çizimi ve bilgileri. Ödül: +200 Işık, bir ses paketi ve bir rozet. "Gerçek gökyüzünde bul" butonu.
- **Mağaza** kategorilere ayrıldı:
  - Güçlendiriciler: Teleskop (400), Kayan yıldız ×2 Işık (150), Seri koruyucu bulut (250), Parlak yıldız bileti (500)
  - Ses paketleri: Kütüphane, Kahvehane (300'er), Kış gecesi (Avcı ile açılır)
  - Görünüm: Kutup ışığı göğü (600), Alacakaranlık göğü (400), Analog sayaç (200), Uygulama ikonu (150)
  - İyilik: Bir fidan dikilsin (2.000) — [PARTNER KURUM]

**Teknik notlar:**
- **Spotify bağlantısı:** iOS'ta Spotify iOS SDK (App Remote) ile çalma başlatılıp kontrol edilir. Kullanıcının kendi listelerini çekmek için Web API'ye OAuth (PKCE) ile bağlanılır. Spotify uygulamasının telefonda yüklü olması gerekir. Ücretsiz hesaplarda listeler sadece karışık sırada çalar.
- **Spotify'ı engelden muaf tut:** kullanıcı Spotify'ı engellenecekler arasında seçmiş olsa bile oturum boyunca otomatik muaf tutulmalı.
- **Uygulama içi sesler:** ekran kilitliyken de çalabilmesi için `AVAudioSession` playback ve Background Audio izni gerekir.
- **"Gerçek gökyüzünde bul":** ARKit, CoreLocation ve CoreMotion ile yapılabilir; yıldız konumları için açık katalog verisi yeterli. İlk sürüm sonrasına bırakılabilir.

Takımyıldız bilgi metinleri yayından önce bir astronomi kaynağından doğrulanmalı.

---

## 3. Soru: Takımyıldızlar bitince ne olacak?

### Yanıt

**Ne zaman biter?** 16 takımyıldızda ortalama 7 yıldız varsa toplam yaklaşık 110 yıldız, yani yaklaşık 110 oturum eder. Günde 2 oturum yapan biri bunları **2 ayda** bitirir. Bu yüzden baştan planlanmalı.

**Önerilen katmanlar:**

1. **Tüm gökyüzü:** 16'lık katalog bitince resmi 88 takımyıldızın geri kalanı bölge bölge açılır ("Kuzey göğü", "Güney seferi").
2. **Derin gök nesneleri:** nebulalar, galaksiler, yıldız kümeleri (110 nesnelik Messier kataloğu). Oturum başına düşmez, kilometre taşlarıyla açılır. Örnek: "100 saat odak → Andromeda Galaksisi".
3. **Gezegenler:** büyük, nadir kilometre taşları (örneğin 50 saatte Mars, 500 saatte Uranüs).
4. **Altın gökyüzü (prestij):** her şey bitince isteğe bağlı "yeni bir gece". Koleksiyon kaybolmaz, takımyıldızlar altın olarak yeniden toplanır, profilde prestij seviyesi görünür, Işık kazancı kalıcı olarak biraz artar.
5. **Gerçek gökyüzü etkinlikleri:** her zaman açık. Gerçek meteor yağmurları sırasında sınırlı süreli etkinlikler (Ağustos'ta Perseidler, Aralık'ta İkizler). O hafta "kayan yıldız" daha sık düşer, etkinliğe özel rozet verilir.

**Hiç bitmeyen kısımlar:** Işık, kendine sözler, seriler ve istatistikler bağımsız çalışmaya devam eder.

Önerilen sıralama: ilk sürümde 16 takımyıldız → ilk güncellemede 88 takımyıldız ve meteor etkinlikleri → sonra derin gök ve prestij.

---

## 4. İstek: Bu katmanların hepsini uygula

### Yanıt

Beş katmanın hepsi canvas'a eklendi. "Uzun vade: koleksiyon katmanları" başlığı altında dört yeni ekran var; Gökyüzüm ekranındaki "Takımyıldız koleksiyonu" satırından haritaya, oradan diğer ekranlara gidiliyor.

- **6 · Koleksiyon haritası:** kullanıcının hangi katmanda olduğunu ve sırada ne olduğunu gösterir. Katmanlar 1 → 2 → 5 sırayla açılır. Derin gök ve gezegenler en baştan paralel ilerler, böylece yeni bir kullanıcı da bu iki katmanda ilerleme görür. En üstte o sırada süren meteor yağmuru etkinliği durur.
- **6a · Derin gök ve gezegenler:** ilk nesne Avcı Bulutsusu (M42). Açılma koşulu: Avcı tamamlandıktan sonra 90 dakikalık bir oturum. Ödülü +300 Işık ve "Bulutsu" gök teması. Ay ve gezegen yolu toplam odak saatiyle açılır: Ay 5s, Merkür 10s, Venüs 25s, Mars 50s, Jüpiter 100s, Satürn 250s, Uranüs 500s, Neptün 1000s.
- **6b · Meteor yağmuru etkinliği:** örnek olarak Orionidler (zirve 21–22 Ekim civarı; ilk sürüm yetişirse iyi bir lansman etkinliği). Etkinlik boyunca her oturumda %25 şansla kayan yıldız (o oturumun Işığı ×2). 10 oturum → rozet ve "Meteor izi" sayaç stili. "Zirve gecesi için hatırlat" butonu ve sıradaki etkinlikler (Leonidler, Geminidler, Perseidler).
- **6c · Altın gökyüzü:** isteğe bağlı prestij. Hiçbir şey silinmez; takımyıldızlar altın olarak yeniden toplanır. Her yeni gece kalıcı +%10 Işık, en fazla +%50. "Şimdilik kalsın" seçeneği baskı yapmamak için bilerek var.

**Öneri:** meteor yağmurlarının tarihleri her yıl birkaç gün kayar. Etkinlik takvimini uygulamaya sabit yazmak yerine sunucudan gelen bir konfigürasyondan okumak daha iyi olur; böylece yeni sürüm yayınlamadan güncellenebilir. Bilgi metinleri yayından önce bir astronomi kaynağıyla doğrulanmalı.

---

## Ek: Canvas'taki ekranlar

| # | Ekran | İçerik |
|---|---|---|
| 1 | Odak kurulumu | Görev adı, süre (25/45/60/90/Özel), engelleme modu (Seçtiklerim/Tümü/Yok), arama-mesaj susturma, favoriler, katı mod |
| 2 | Odak sürüyor | Geri sayım halkası, kilitli uygulama/bildirim durumu, biriken Işık, çalan ses kartı, mola ve vazgeç |
| 2b | Ses ve müzik | Ortam sesleri, ses seviyesi, Spotify çalma listeleri |
| 3 | Ödül anı | Yeni yıldız (Saiph, Avcı 6/7), Işık dökümü, kendine söz ilerlemesi |
| 3b | Takımyıldız tamamlandı | Avcı çizimi, bilgiler, tamamlama ödülleri, gerçek gökyüzünde bul |
| 4 | Gökyüzüm | Takımyıldız haritası, haftalık istatistik, seri koruyucu bulut, rozetler |
| 5 | Ödüller ve mağaza | Kendine sözler, güçlendiriciler, ses paketleri, görünüm, Zenit aboneliği |
| 6 | Koleksiyon haritası | 5 katman ve aktif etkinlik |
| 6a | Derin gök + gezegenler | Avcı Bulutsusu, gezegen kilometre taşları |
| 6b | Meteor yağmuru etkinliği | Orionidler, etkinlik kuralları, takvim |
| 6c | Işık yolculuğu | Gerçek yıldız sistemlerine rota, sıradaki durak |

---

## 5. İstek: Altın yıldızlar ve fidan dikme yerine yeni konseptler (11 Ekim 2026)

> Bütün gökyüzü tamamlandığında altın yıldızları toplamak yerine başka bir konsept düşün. Ayrıca para kazanmak için fidan dikme yerine de başka bir özellik kurgula.

Sunulan seçeneklerden Beyza şunları seçti:

**Işık yolculuğu (Altın gökyüzü prestijinin yerine)**
- 88 takımyıldız bitince kullanıcı gerçek yıldız sistemlerine yolculuğa çıkar. Her odak saati 1 ışık yılı.
- Rota: Alfa Centauri (4,4 ı.y.) → Sirius (8,6) → Vega (25) → TRAPPIST-1 (41) → Ülker (444) → ve ötesi. Her durakta sistemin hikâyesi ve bir ödül (rozet, Işık, ses paketi, gök teması) var.
- Mesafeler gerçek olduğu için hiç bitmez; hiçbir şey baştan toplanmaz, koleksiyon ve Işık bakiyesi korunur.
- 6c ekranı bu yolculuğa dönüştü (açık ve koyu mod); koleksiyon haritasındaki 5. katman güncellendi, "Gece 1" etiketleri toplam odak saatine çevrildi.
- Mesafeler yayından önce bir astronomi kaynağıyla doğrulanmalı.

**Zenit aboneliği (fidan dikmenin yerine, gelir modeli)**
- Odak, engelleme, yıldızlar ve Işık her zaman ücretsiz.
- Zenit: tüm ses paketleri ve gök temaları, ayrıntılı istatistikler, sınırsız kendine söz.
- Ad olarak "Derin+" beğenilmedi; Zenit (gökyüzünün en tepe noktası) seçildi. Fiyat henüz belirlenmedi: [FİYAT] / ay.
- Mağazadaki "Bir fidan dikilsin" kartı ve "İyilik" sekmesi kaldırıldı, yerine Zenit kartı ve sekmesi geldi.
