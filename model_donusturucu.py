import tensorflow as tf
import os

# Model dosyasının adını kontrol et
model_adi = 'ev_bitkisi_modeli.h5'

if os.path.exists(model_adi):
    print("Model yükleniyor, lütfen bekleyin...")
    model = tf.keras.models.load_model(model_adi)
    
    # TFLite çeviriciyi başlat
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_model = converter.convert()

    # assets klasörü yoksa oluştur
    if not os.path.exists('assets'):
        os.makedirs('assets')

    # Kaydet
    with open('assets/bitki_modeli.tflite', 'wb') as f:
        f.write(tflite_model)
    
    print("Müjde! 'bitki_modeli.tflite' artık assets klasöründe hazır.")
else:
    print(f"Hata: {model_adi} dosyası bulunamadı! Lütfen dosyanın ismini ve yerini kontrol et.")