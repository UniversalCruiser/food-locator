import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:collection/collection.dart';
import 'package:maplibre_gl/mapbox_gl.dart';

void main() => runApp(const FoodLocatorApp());

class FoodLocatorApp extends StatelessWidget {
  const FoodLocatorApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Locator',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: const StoreSearchPage(),
    );
  }
}

class Store {
  final String id;
  final String name;
  final String postcode;
  final String town;
  final double lat;
  final double lng;
  final String cuisine;
  final String address;
  Store({
    required this.id,
    required this.name,
    required this.postcode,
    required this.town,
    required this.lat,
    required this.lng,
    required this.cuisine,
    required this.address,
  });
}

final List<Store> kStores = [
  Store(
    id: '1',
    name: 'Pasta Palace',
    postcode: 'SW1A 1AA',
    town: 'London',
    lat: 51.501364, lng: -0.14189,
    cuisine: 'Italian',
    address: '1 Palace Rd, London',
  ),
  Store(
    id: '2',
    name: 'Curry Corner',
    postcode: 'E1 6AN',
    town: 'London',
    lat: 51.5205, lng: -0.0713,
    cuisine: 'Indian',
    address: '22 Spicy St, London',
  ),
  Store(
    id: '3',
    name: 'Sushi Spot',
    postcode: 'W1D 3QF',
    town: 'London',
    lat: 51.5129, lng: -0.1301,
    cuisine: 'Japanese',
    address: '7 Ocean Ave, London',
  ),
];

double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  double dLat = (lat2 - lat1) * pi / 180;
  double dLon = (lon2 - lon1) * pi / 180;
  double a = sin(dLat/2) * sin(dLat/2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
      sin(dLon/2) * sin(dLon/2);
  double c = 2 * atan2(sqrt(a), sqrt(1-a));
  return r * c;
}

Future<LatLng?> geocodeQuery(String query) async {
  final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
    'format': 'json',
    'q': query,
    'limit': '1',
  });
  final resp = await http.get(
    uri,
    headers: {'User-Agent': 'food-locator-app/1.0 (replace-with-your-email@example.com)'},
  );
  if (resp.statusCode != 200) return null;
  final data = jsonDecode(resp.body);
  if (data is List && data.isNotEmpty) {
    final lat = double.tryParse(data[0]['lat']);
    final lon = double.tryParse(data[0]['lon']);
    if (lat != null && lon != null) return LatLng(lat, lon);
  }
  return null;
}

class StoreSearchPage extends StatefulWidget {
  const StoreSearchPage({super.key});
  @override
  State<StoreSearchPage> createState() => _StoreSearchPageState();
}

class _StoreSearchPageState extends State<StoreSearchPage> {
  final _controller = TextEditingController();
  bool _loading = false;
  List<Store> _closest = [];
  LatLng? _queryPoint;

  Future<void> _runSearch() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() => _loading = true);
    try {
      final pt = await geocodeQuery(q);
      if (pt == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find that postcode/town')),
        );
        setState(() => _loading = false);
        return;
      }
      final sorted = kStores.sorted((a, b) {
        final da = _distanceKm(pt.latitude, pt.longitude, a.lat, a.lng);
        final db = _distanceKm(pt.latitude, pt.longitude, b.lat, b.lng);
        return da.compareTo(db);
      });
      setState(() {
        _queryPoint = pt;
        _closest = sorted.take(3).toList();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food Locator')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Enter postcode or town',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _runSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _runSearch,
                  child: _loading ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2),
                  ) : const Text('Search'),
                ),
              ],
            ),
          ),
          if (_closest.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _closest.length,
                itemBuilder: (_, i) {
                  final s = _closest[i];
                  final dist = _queryPoint == null ? null
                    : _distanceKm(_queryPoint!.latitude, _queryPoint!.longitude, s.lat, s.lng);
                  return ListTile(
                    title: Text(s.name),
                    subtitle: Text('${s.cuisine} • ${s.postcode} • ${s.town}'
                        '${dist != null ? ' • ${dist.toStringAsFixed(2)} km' : ''}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => StoreDetailPage(store: s)),
                    ),
                  );
                },
              ),
            ),
          if (_closest.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  icon: const Icon(Icons.map),
                  label: const Text('Open Map View'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => MapPage(
                        stores: _closest,
                        queryPoint: _queryPoint!,
                      )),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MapPage extends StatefulWidget {
  final List<Store> stores;
  final LatLng queryPoint;
  const MapPage({super.key, required this.stores, required this.queryPoint});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  MaplibreMapController? controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map View')),
      body: MaplibreMap(
        styleString: "assets/style.json",
        initialCameraPosition: CameraPosition(target: widget.queryPoint, zoom: 12),
        onMapCreated: (c) async {
          controller = c;
          await _addMarkers();
        },
      ),
    );
  }

  Future<void> _addMarkers() async {
    await controller?.addSymbol(SymbolOptions(
      geometry: widget.queryPoint,
      iconImage: "marker-15",
      iconSize: 1.8,
      textField: "Search",
      textOffset: const Offset(0, 1.2),
    ));
    for (final s in widget.stores) {
      await controller?.addSymbol(SymbolOptions(
        geometry: LatLng(s.lat, s.lng),
        iconImage: "marker-15",
        iconSize: 1.5,
        textField: s.name,
        textOffset: const Offset(0, 1.2),
      ));
    }
    controller?.onSymbolTapped.add((symbol) {
      final name = symbol.options.textField;
      final match = widget.stores.firstWhereOrNull((s) => s.name == name);
      if (match != null && mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => StoreDetailPage(store: match)));
      }
    });
  }
}

class StoreDetailPage extends StatelessWidget {
  final Store store;
  const StoreDetailPage({super.key, required this.store});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(store.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(store.cuisine, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(store.address),
            const SizedBox(height: 8),
            Text('Postcode: ${store.postcode}'),
            Text('Town: ${store.town}'),
            const Spacer(),
            FilledButton.icon(
              icon: const Icon(Icons.map),
              label: const Text('Show on Map'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MapPage(
                    stores: [store],
                    queryPoint: LatLng(store.lat, store.lng),
                  )),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}