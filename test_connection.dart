import 'dart:convert';
import 'dart:io';

void main() async {
  //'🧪 Testing API Connection...');
  
  try {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse('http://localhost:8000/api/v1/articles'));
    final response = await request.close();
    
    if (response.statusCode == 200) {
      final responseBody = await response.transform(utf8.decoder).join();
      final data = json.decode(responseBody);
      
      //'✅ API Connection Successful!');
      //'📊 Status: ${data['status']}');
      //'📰 Articles: ${data['count']} found');
      //'🎯 First article: ${data['articles'][0]['rewritten_headline']}');
    } else {
      //'❌ API returned status: ${response.statusCode}');
    }
    
    client.close();
  } catch (e) {
    //'❌ Connection failed: $e');
  }
}