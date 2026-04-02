import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather Predictor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const WeatherScreen(),
    );
  }
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final cityController = TextEditingController();

  String result = '';
  bool isLoading = false;
  String fetchedInfo = ''; // shows the real data we fetched

  Map<String, Map<String, dynamic>> weatherInfo = {
    'rain':    {'icon': Icons.umbrella,   'color': Colors.blue,    'label': 'Rainy'},
    'sun':     {'icon': Icons.wb_sunny,   'color': Colors.orange,  'label': 'Sunny'},
    'drizzle': {'icon': Icons.grain,      'color': Colors.blueGrey,'label': 'Drizzle'},
    'fog':     {'icon': Icons.cloud,      'color': Colors.grey,    'label': 'Foggy'},
    'snow':    {'icon': Icons.ac_unit,    'color': Colors.cyan,    'label': 'Snowy'},
  };

  // Step 1: Get latitude & longitude from city name
  Future<Map<String, double>?> getCoordinates(String city) async {
    final url = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(city)}&count=1'
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['results'] != null && data['results'].isNotEmpty) {
        final loc = data['results'][0];
        return {
          'lat': loc['latitude'].toDouble(),
          'lon': loc['longitude'].toDouble(),
        };
      }
    }
    return null;
  }

  // Step 2: Get real weather data using lat & lon
  Future<Map<String, double>?> getWeatherData(double lat, double lon) async {
    final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
            '&daily=precipitation_sum,temperature_2m_max,temperature_2m_min,windspeed_10m_max'
            '&forecast_days=1&timezone=auto'
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final daily = data['daily'];
      return {
        'precipitation': (daily['precipitation_sum'][0] ?? 0.0).toDouble(),
        'temp_max':      (daily['temperature_2m_max'][0] ?? 0.0).toDouble(),
        'temp_min':      (daily['temperature_2m_min'][0] ?? 0.0).toDouble(),
        'wind':          (daily['windspeed_10m_max'][0] ?? 0.0).toDouble(),
      };
    }
    return null;
  }

  // Step 3: Send data to YOUR Flask ML model
  Future<String?> predictFromFlask(Map<String, double> weatherData) async {
    final url = Uri.parse('http://127.0.0.1:5000/predict');
    // final url = Uri.parse('http://192.168.43.174:5000/predict');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(weatherData),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['weather'];
    }
    return null;
  }

  // Main function that chains all 3 steps
  Future<void> predictWeather() async {
    final city = cityController.text.trim();
    if (city.isEmpty) {
      setState(() => result = 'Please enter a city name');
      return;
    }

    setState(() {
      isLoading = true;
      result = '';
      fetchedInfo = '';
    });

    try {
      // Step 1: City → coordinates
      final coords = await getCoordinates(city);
      if (coords == null) {
        setState(() {
          result = 'City not found. Try another name.';
          isLoading = false;
        });
        return;
      }

      // Step 2: Coordinates → real weather numbers
      final weatherData = await getWeatherData(coords['lat']!, coords['lon']!);
      if (weatherData == null) {
        setState(() {
          result = 'Could not fetch weather data.';
          isLoading = false;
        });
        return;
      }

      // Show the fetched real data to user
      setState(() {
        fetchedInfo =
        'Real data fetched:\n'
            'Precipitation: ${weatherData['precipitation']} mm\n'
            'Max Temp: ${weatherData['temp_max']}°C\n'
            'Min Temp: ${weatherData['temp_min']}°C\n'
            'Wind: ${weatherData['wind']} km/h';
      });

      // Step 3: Send to YOUR ML model
      final prediction = await predictFromFlask(weatherData);
      if (prediction == null) {
        setState(() {
          result = 'Could not connect to server.\nMake sure Flask is running.';
          isLoading = false;
        });
        return;
      }

      setState(() => result = prediction);

    } catch (e) {
      setState(() => result = 'Something went wrong. Check your connection.');
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final weather = weatherInfo[result];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text('Weather Predictor',
            style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [

            // Result card
            if (result.isNotEmpty)
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: weather != null
                      ? (weather['color'] as Color).withOpacity(0.15)
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: weather != null
                        ? weather['color'] as Color
                        : Colors.red,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    if (weather != null) ...[
                      Icon(weather['icon'] as IconData,
                          size: 72, color: weather['color'] as Color),
                      const SizedBox(height: 12),
                      Text(
                        weather['label'] as String,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: weather['color'] as Color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Predicted by your ML model',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ] else
                      Text(result,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),

            // Fetched data info box
            if (fetchedInfo.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  fetchedInfo,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.green.shade800,
                      height: 1.6),
                ),
              ),

            // Input card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Enter City Name',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text(
                    'We will fetch today\'s real weather data\nand predict using your ML model.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: cityController,
                    decoration: InputDecoration(
                      labelText: 'City name',
                      hintText: 'e.g. Karachi, London, Seattle',
                      prefixIcon: const Icon(Icons.location_city,
                          color: Colors.blue),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Colors.blue, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : predictWeather,
                      icon: isLoading
                          ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.search, color: Colors.white),
                      label: Text(
                        isLoading ? 'Fetching & Predicting...' : 'Predict Weather',
                        style: const TextStyle(
                            fontSize: 16, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
//
// void main() {
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Weather Predictor',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
//         useMaterial3: true,
//       ),
//       home: const WeatherScreen(),
//     );
//   }
// }
//
// class WeatherScreen extends StatefulWidget {
//   const WeatherScreen({super.key});
//
//   @override
//   State<WeatherScreen> createState() => _WeatherScreenState();
// }
//
// class _WeatherScreenState extends State<WeatherScreen> {
//   // Controllers to read text field values
//   final precipController = TextEditingController();
//   final tempMaxController = TextEditingController();
//   final tempMinController = TextEditingController();
//   final windController = TextEditingController();
//
//   String result = '';
//   bool isLoading = false;
//
//   // Weather icons and colors mapping
//   Map<String, Map<String, dynamic>> weatherInfo = {
//     'rain':    {'icon': Icons.umbrella,      'color': Colors.blue,   'label': 'Rainy'},
//     'sun':     {'icon': Icons.wb_sunny,      'color': Colors.orange, 'label': 'Sunny'},
//     'drizzle': {'icon': Icons.grain,         'color': Colors.blueGrey,'label': 'Drizzle'},
//     'fog':     {'icon': Icons.cloud,         'color': Colors.grey,   'label': 'Foggy'},
//     'snow':    {'icon': Icons.ac_unit,       'color': Colors.cyan,   'label': 'Snowy'},
//   };
//
//   Future<void> predictWeather() async {
//     // Validate inputs
//     if (precipController.text.isEmpty ||
//         tempMaxController.text.isEmpty ||
//         tempMinController.text.isEmpty ||
//         windController.text.isEmpty) {
//       setState(() => result = 'Please fill in all fields');
//       return;
//     }
//
//     setState(() {
//       isLoading = true;
//       result = '';
//     });
//
//     try {
//       // IMPORTANT: Use your actual IP from Flask output
//       // Replace 192.168.43.174 with YOUR IP shown in Flask terminal
//       // final url = Uri.parse('http://192.168.43.174:5000/predict');
//
//       final url = Uri.parse('http://127.0.0.1:5000/predict');
//       final response = await http.post(
//         url,
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({
//           'precipitation': double.parse(precipController.text),
//           'temp_max':      double.parse(tempMaxController.text),
//           'temp_min':      double.parse(tempMinController.text),
//           'wind':          double.parse(windController.text),
//         }),
//       );
//
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         setState(() => result = data['weather']);
//       } else {
//         setState(() => result = 'Server error. Try again.');
//       }
//     } catch (e) {
//       setState(() => result = 'Could not connect to server.\nMake sure Flask is running.');
//     }
//
//     setState(() => isLoading = false);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final weather = weatherInfo[result];
//
//     return Scaffold(
//       backgroundColor: const Color(0xFFF0F4FF),
//       appBar: AppBar(
//         backgroundColor: Colors.blue,
//         title: const Text('Weather Predictor', style: TextStyle(color: Colors.white)),
//         centerTitle: true,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           children: [
//             // Result card
//             if (result.isNotEmpty)
//               AnimatedContainer(
//                 duration: const Duration(milliseconds: 400),
//                 width: double.infinity,
//                 padding: const EdgeInsets.all(24),
//                 margin: const EdgeInsets.only(bottom: 24),
//                 decoration: BoxDecoration(
//                   color: weather != null
//                       ? (weather['color'] as Color).withOpacity(0.15)
//                       : Colors.red.shade50,
//                   borderRadius: BorderRadius.circular(20),
//                   border: Border.all(
//                     color: weather != null
//                         ? weather['color'] as Color
//                         : Colors.red,
//                     width: 1.5,
//                   ),
//                 ),
//                 child: Column(
//                   children: [
//                     if (weather != null) ...[
//                       Icon(weather['icon'] as IconData,
//                           size: 64, color: weather['color'] as Color),
//                       const SizedBox(height: 12),
//                       Text(
//                         weather['label'] as String,
//                         style: TextStyle(
//                           fontSize: 28,
//                           fontWeight: FontWeight.bold,
//                           color: weather['color'] as Color,
//                         ),
//                       ),
//                     ] else
//                       Text(result,
//                           textAlign: TextAlign.center,
//                           style: const TextStyle(color: Colors.red)),
//                   ],
//                 ),
//               ),
//
//             // Input card
//             Container(
//               padding: const EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(20),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.06),
//                     blurRadius: 12,
//                     offset: const Offset(0, 4),
//                   )
//                 ],
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text('Enter Weather Data',
//                       style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                   const SizedBox(height: 20),
//                   _buildField(precipController, 'Precipitation (mm)', '0.0', Icons.water_drop),
//                   const SizedBox(height: 14),
//                   _buildField(tempMaxController, 'Max Temperature (°C)', '20.0', Icons.thermostat),
//                   const SizedBox(height: 14),
//                   _buildField(tempMinController, 'Min Temperature (°C)', '10.0', Icons.thermostat_outlined),
//                   const SizedBox(height: 14),
//                   _buildField(windController, 'Wind Speed', '3.0', Icons.air),
//                   const SizedBox(height: 24),
//
//                   // Predict button
//                   SizedBox(
//                     width: double.infinity,
//                     height: 52,
//                     child: ElevatedButton(
//                       onPressed: isLoading ? null : predictWeather,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.blue,
//                         shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(14)),
//                       ),
//                       child: isLoading
//                           ? const CircularProgressIndicator(color: Colors.white)
//                           : const Text('Predict Weather',
//                           style: TextStyle(fontSize: 16, color: Colors.white)),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildField(TextEditingController controller, String label,
//       String hint, IconData icon) {
//     return TextField(
//       controller: controller,
//       keyboardType: const TextInputType.numberWithOptions(decimal: true),
//       decoration: InputDecoration(
//         labelText: label,
//         hintText: hint,
//         prefixIcon: Icon(icon, color: Colors.blue),
//         border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: const BorderSide(color: Colors.blue, width: 2),
//         ),
//       ),
//     );
//   }
// }
