# Sönmüş yıldız: vazgeçmenin hafif bedeli

Tarih: 2026-10-29 · Durum: onay bekliyor

## Amaç

Kullanıcı bir odak oturumunu yarıda bıraktığında gökyüzünde küçük ve kalıcı bir iz kalsın. Forest'taki solmuş ağaç gibi, bu iz cezalandırmak için değil, bir dahaki sefere vazgeçmeden önce iki kere düşündürmek için var. Işık, seri ya da başka bir kayıp eklenmez.

## Beyza'nın kararları

- Ceza biçimi sönmüş yıldızdır: gri, kül rengi küçük bir yıldız. Ek Işık ya da seri cezası yoktur.
- Sönmüş yıldız yalnızca "Vazgeçmek için basılı tut" ile bırakılan oturumlarda oluşur. Uygulamadan çıkmak ya da uygulamayı kapatmak bugünkü gibi kalır.
- İlk 10 saniye hakkı vardır. Oturumun ilk 10 saniyesinde vazgeçilirse hiç kayıt tutulmaz ve iz kalmaz.
- Sönmüş yıldıza dokununca yalnızca kişinin o oturum için yazdığı odak cümlesi görünür. "Vazgeçtin" gibi bir ifade, tarih ya da dakika gösterilmez.

## Bugünkü durum

`SkyProgress.abandon` vazgeçilen oturumu `completed: false` olan bir `FocusRecord` olarak saklar. Yıldız yanmaz ve Işık verilmez, ama dakikalar saatlere, gezegenlere ve ışık yolculuğuna sayılır. Gökyüzünde bu kayıttan geriye bir şey görünmez. Katı modda vazgeçme düğmesi zaten yoktur.

## Tasarım

### 1. Kurallar (OdakCore)

- `SkyProgress.abandonGrace: TimeInterval = 10` sabiti eklenir.
- `abandon(_:)` artık `@discardableResult` ile `Bool` döner. `input.end - input.start < abandonGrace` ise hiçbir şey kaydetmez ve `false` döner. Aksi halde bugünkü gibi kaydeder ve `true` döner.
- `burntOutStars: [FocusRecord]` hesaplanmış özelliği, `completed == false` olan kayıtları döner. Yeni bir alan saklanmaz. Bu yüzden veri biçimi değişmez ve Firestore eşitlemesi (`Merge`, kayıtları `id` ile birleştirir) ek iş istemez. Bu özellikten önce vazgeçilmiş oturumlar da sönmüş yıldız olarak görünür, bu bilinçli bir tercihtir.
- `BurntOutStarLayout.point(for: UUID, avoiding: [DiscRect]) -> DiscPoint` sönmüş yıldızın diskteki yerini kaydın `id`'sinden türetir. Sonuç her açılışta ve her cihazda aynıdır. Nokta birim diskin içinde kalır, merkezdeki Kutup Yıldızı'nın çevresine ve verilen takımyıldız alanlarına düşmez. Uygun yer bulunamazsa (çok sayıda denemeden sonra) son aday kullanılır. `DiscRect` ve `DiscPoint` OdakCore içinde `Double` alanlı küçük yapılardır, böylece kural uygulama olmadan test edilir.

### 2. Gökyüzü (uygulama)

- Sönmüş yıldızlar Ana Sayfa'daki "Senin gökyüzün" diskine (`Planisphere`) çizilir, çünkü bu her gün görülen ve kullanıcının kendi gökyüzü olan yerdir. Gökyüzüm sekmesindeki sayfalı takımyıldız haritasına eklenmez.
- Görünüş: yaklaşık 2,5 pt yarıçaplı, kül grisi (`Theme.paper3` tonunda, düşük opaklık) bir nokta ve onun çevresinde soluk, kesik çizgili ince bir halka. Işıma (flare) yoktur. Arka plandaki rastgele yıldızlardan ayırt edilebilir ama göze batmaz.
- Takımyıldız alanları olarak `Planisphere`'ın mevcut `slots` dizisi ve etiket payı verilir.
- Dokunma: disk üzerinde tek bir dokunma algılayıcısı, dokunulan noktaya 22 pt'den yakın olan en yakın sönmüş yıldızı seçer. Seçilen yıldızın yanında küçük bir popover açılır ve içinde yalnızca kaydın `task` metni yazar. Odak cümlesi boş bırakılmış oturumlarda kayıt zaten "Odak" olarak saklanır, o metin gösterilir.
- Erişilebilirlik: diskin özet etiketine sönmüş yıldız sayısı eklenir ("ve 3 sönmüş yıldız"). VoiceOver ile tek tek sönmüş yıldızlara erişim bu sürümde yoktur.

### 3. Oturum ekranı ve metinler

- `AppModel.abandon()`, OdakCore'un dönüşüne göre davranır ve her iki durumda da oturumu kapatır.
- `ActiveSessionView` altındaki uyarı şöyle olur: "Vazgeçersen gökyüzüne sönmüş bir yıldız düşer, ama odaklandığın dakikalar yine de sayılır."
- Oturumun ilk 10 saniyesinde bu metnin yerine şu yazar: "Şimdi vazgeçersen gökyüzünde iz kalmaz." 10 saniye dolunca metin kendiliğinden değişir (ekran zaten her saniye yenileniyor).
- Ana Sayfa'daki ilk açılış metni (`HomeView.detail`) şöyle olur: "Tamamladığın her oturum gökyüzüne bir yıldız ekler. Vazgeçersen gökyüzüne sönmüş bir yıldız düşer ama odaklandığın dakikalar yine de sayılır."

### 4. Test

- OdakCore birim testleri: 10 saniyeden kısa vazgeçme kayıt eklemez; 10 saniye ve üstü kayıt ekler ve `burntOutStars` içinde görünür; tamamlanan oturum `burntOutStars` içinde görünmez; `BurntOutStarLayout` aynı `id` için aynı noktayı verir, nokta diskin içindedir ve verilen alanlara düşmez.
- Demo verisine iki vazgeçilmiş oturum eklenir ve CI'da Ana Sayfa'nın tek bir ekran görüntüsüne bakılır.

## Kapsam dışı

- Uygulamadan uzun süre çıkınca oturumun kendiliğinden bitmesi.
- Işık, seri ya da bulut kaybı.
- Sönmüş yıldızları silme veya yeniden yakma.
- Gökyüzüm sekmesindeki haritada gösterim.
