import tensorflow as tf
import numpy as np
from tensorflow.keras.preprocessing import image
import os

# 1. Modeli Yükle (Eğittiğimiz dosya ile aynı klasörde olmalı)
model_yolu = "ev_bitkisi_modeli.h5"
if not os.path.exists(model_yolu):
    print("Hata: Model dosyası bulunamadı! Lütfen model_egitimi.py'nin bittiğinden emin ol.")
else:
    model = tf.keras.models.load_model(model_yolu)

    # 2. Test Fotoğrafının Yolu
    img_path = "C:/bitki_data/test_et.jpg" 

    # 3. Resmi Hazırla (Eğitimdeki gibi 224x224 yapıyoruz)
    img = image.load_img(img_path, target_size=(224, 224))
    img_array = image.img_to_array(img) / 255.0  # Normalize et
    img_array = np.expand_dims(img_array, axis=0) # Tek resim olduğu için boyut ekle

    # 4. Tahmin Yap
    prediction = model.predict(img_array)

    print("\n--- TEST SONUCU ---")
    # 0.5'ten büyükse Stresli, küçükse Sağlıklı (Alfabetik sıraya göre genelde böyledir)
    if prediction[0] > 0.5:
        yuzde = prediction[0][0] * 100
        print(f"Durum: STRESLİ / HASTA 🤒")
        print(f"Güven Oranı: %{yuzde:.2f}")
    else:
        yuzde = (1 - prediction[0][0]) * 100
        print(f"Durum: SAĞLIKLI 🌱")
        print(f"Güven Oranı: %{yuzde:.2f}")
    print("-------------------\n")