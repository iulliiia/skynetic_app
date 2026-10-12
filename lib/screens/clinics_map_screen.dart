import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class DermatologistMapScreen extends StatefulWidget {
  const DermatologistMapScreen({super.key});

  @override
  State<DermatologistMapScreen> createState() => _DermatologistMapScreenState();
}

class _DermatologistMapScreenState extends State<DermatologistMapScreen> {
  LocationData? _currentLocation;
  final Location _locationService = Location();
  GoogleMapController? _mapController;

  // Example clinics
  final List<Map<String, dynamic>> clinics = [
    {
      'name': 'Reteaua de Sanatate REGINA MARIA - Policlinica Enescu',
      'position': const LatLng(44.442881, 26.096826),
    },
    {
      'name': 'TOP-DERM CLINCS',
      'position': const LatLng(44.439988, 26.089879),
    },
    {
      'name': 'Centrul de Imagistica MEMORMED',
      'position': const LatLng(44.425266, 26.094770),
    },
    {
      'name': 'Clinica Dermatologica DermaBeauty Clinique Unirii',
      'position': const LatLng(44.429998, 26.110013),
    },
    {
      'name': 'Skina Dermatologie Bucuresti',
      'position': const LatLng(44.4337778, 26.1181404),
    },
    {
      'name': 'Doctor SKiN Popa Nan',
      'position': const LatLng(44.4337724, 26.1240632),
    },
    {
      'name': 'SKINOVATE - Clinica de dermatologie',
      'position': const LatLng(44.4669797, 26.1055279),
    },
    {
      'name': 'Derm-One Clinic',
      'position': const LatLng(44.4205553, 26.0938643),
    },
  ];

  Set<Marker> get _markers {
    final markers = clinics.map((clinic) {
      return Marker(
        markerId: MarkerId(clinic['name']),
        position: clinic['position'],
        infoWindow: InfoWindow(title: clinic['name']),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      );
    }).toSet();

    if (_currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position:
              LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
          infoWindow: const InfoWindow(title: 'Locația ta'),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }
    return markers;
  }

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled;
      PermissionStatus permissionGranted;

      serviceEnabled = await _locationService.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _locationService.requestService();
        if (!serviceEnabled) return;
      }

      permissionGranted = await _locationService.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _locationService.requestPermission();
      }
      if (permissionGranted != PermissionStatus.granted &&
          permissionGranted != PermissionStatus.grantedLimited) {
        return;
      }

      final location = await _locationService.getLocation();
      if (!mounted) return;
      setState(() {
        _currentLocation = location;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(
        LatLng(location.latitude, location.longitude),
      ));
    } catch (_) {
      // Location is optional: the map still shows the clinics.
    }
  }

  @override
  Widget build(BuildContext context) {
    const initialCameraPosition = CameraPosition(
      target: LatLng(44.439663, 26.096306), // Default to Bucharest center
      zoom: 13,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinici dermatologice'),
      ),
      body: GoogleMap(
        initialCameraPosition: initialCameraPosition,
        onMapCreated: (controller) => _mapController = controller,
        markers: _markers,
        myLocationEnabled: _currentLocation != null,
        myLocationButtonEnabled: true,
      ),
    );
  }
}
