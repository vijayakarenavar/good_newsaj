import 'dart:convert';
import 'dart:io';

// Simple API test script to verify Laravel backend connection
void main() async {
  const baseUrl = 'http://localhost:8000/api/v1';
  
  //'Testing API connection to: $baseUrl');
  
  try {
    // Test articles endpoint
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse('$baseUrl/articles'));
    final response = await request.close();
    
    if (response.statusCode == 200) {
      final responseBody = await response.transform(utf8.decoder).join();
      final data = json.decode(responseBody);
      
      //'✅ Articles API working!');
      //'Status: ${data['status']}');
      //'Articles count: ${data['articles']?.length ?? 0}');
    } else {
      //'❌ Articles API failed with status: ${response.statusCode}');
    }
    
    client.close();
  } catch (e) {
    //'❌ API connection failed: $e');
    //'Make sure Laravel server is running on http://localhost:8000');
  }
}