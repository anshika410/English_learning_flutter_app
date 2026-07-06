import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final deviceId = "test-device-" + DateTime.now().millisecondsSinceEpoch.toString();
  
  // 1. Get anonymous token
  print('1. Getting anonymous token for device: $deviceId');
  final authRes = await http.post(
    Uri.parse('https://ella.navgurukul.org/api/auth/anonymous'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'device_id': deviceId})
  );
  final token = jsonDecode(authRes.body)['access_token'];
  
  // 2. Request magic link to simulate user login (doesn't require real token)
  print('2. Simulating login (Magic link request)');
  final magicRes = await http.post(
    Uri.parse('https://ella.navgurukul.org/api/auth/magic-link/request'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': 'test-${DateTime.now().millisecondsSinceEpoch}@example.com',
      'redirect_url': 'ella://login',
      'device_id': deviceId
    })
  );
  print('Magic link response: ${magicRes.statusCode}');
  
  // 3. Try to reset memory
  print('3. Calling reset-user with token');
  final resetRes = await http.delete(
    Uri.parse('https://ella.navgurukul.org/api/admin/reset-user/$deviceId'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token'
    }
  );
  print('Reset response: ${resetRes.statusCode} ${resetRes.body}');
}
