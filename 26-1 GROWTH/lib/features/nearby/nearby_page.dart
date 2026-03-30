import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../common/api/map_service.dart';

class NearbyPage extends StatefulWidget {
  const NearbyPage({Key? key}) : super(key: key);

  @override
  State<NearbyPage> createState() => _NearbyPageState();
}

class _NearbyPageState extends State<NearbyPage> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final _mapService = const MapService();

  static const LatLng _defaultCenter = LatLng(37.5665, 126.9780);

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _moveToCurrentLocation() async {
    try {
      final position = await _mapService.getCurrentPosition();
      final current = LatLng(position.latitude, position.longitude);

      final markers = await _mapService.fetchNearbyMarkers(current: current);

      setState(() {
        _markers
          ..removeWhere((marker) => marker.markerId.value == 'me')
          ..add(
            Marker(
              markerId: const MarkerId('me'),
              position: current,
              infoWindow: const InfoWindow(title: '내 위치'),
            ),
          )
          ..removeWhere((marker) => marker.markerId.value.startsWith('item_'))
          ..addAll(markers);
      });

      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: current, zoom: 16),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: _defaultCenter,
          zoom: 14,
        ),
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        markers: _markers,
        onMapCreated: (controller) => _mapController = controller,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _moveToCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
