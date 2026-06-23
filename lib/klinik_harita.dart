import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class KlinikHarita extends StatefulWidget {
  const KlinikHarita({super.key});

  @override
  State<KlinikHarita> createState() => _KlinikHaritaState();
}

class _KlinikHaritaState extends State<KlinikHarita> {
  GoogleMapController? _controller;
  Set<Marker> _markers = {};
  bool _yukleniyor = true;

  // BURAYA KENDİ GOOGLE API KEY'İNİ YAZMALISIN
  final String _googleApiKey = "BURAYA_ALDIĞIN_KEYI_YAZ";

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
    _konumuVeKlinikleriGetir();
  }

  Future<void> _konumuVeKlinikleriGetir() async {
    try {
      // 1. İzin Kontrolü
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      // 2. Konum Al
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      LatLng userLatLng = LatLng(position.latitude, position.longitude);

      // 3. Kamerayı Hareket Ettir
      _controller?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: userLatLng, zoom: 14.0),
        ),
      );

      // 4. API İsteği
      final String url =
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${position.latitude},${position.longitude}&radius=5000&type=florist&key=$_googleApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] as List;

        final Set<Marker> tempMarkers = {};

        for (var yer in results) {
          final double lat = yer['geometry']['location']['lat'];
          final double lng = yer['geometry']['location']['lng'];

          tempMarkers.add(
            Marker(
              markerId: MarkerId(yer['place_id'] as String),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(
                title: yer['name'] as String?,
                snippet: yer['vicinity'] as String?,
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            ),
          );
        }

        if (mounted) {
          setState(() {
            _markers = tempMarkers;
            _yukleniyor = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Harita Hatası: $e");
      if (mounted) {
        setState(() => _yukleniyor = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Yakın Bitki Klinikleri"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: LatLng(41.0082, 28.9784), // Varsayılan İstanbul koordinatı
              zoom: 10,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          if (_yukleniyor)
            Center(
              child: Card(
                elevation: 5,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      CircularProgressIndicator(color: Colors.green),
                      SizedBox(height: 10),
                      Text("Klinikler Aranıyor..."),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}