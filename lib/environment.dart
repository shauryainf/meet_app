class Environment {
  // Backend URL for API calls
  static String get backendUrl {
    // Get environment variable if available
    const serverUrlFromEnv = String.fromEnvironment('BACKEND_URL');

    if (serverUrlFromEnv.isNotEmpty) {
      return serverUrlFromEnv;
    }

    // In web release builds running on the same domain as the backend,
    // use a relative URL to make it work with the Nginx proxy
    if (identical(0, 0.0)) {
      // Simple check for JS platform (web)
      return '/'; // Relative URL, will be handled by Nginx
    }

    // Default for local development
    return 'http://localhost:3000';
  }

  // Check if we're running in production mode
  static bool get isProduction {
    const mode = String.fromEnvironment('FLUTTER_APP_ENV');
    return mode == 'production';
  }

  // STUN/TURN server configuration for WebRTC
  static List<Map<String, dynamic>> get iceServers {
    const customStunServer = String.fromEnvironment('STUN_SERVER');
    const customTurnServer = String.fromEnvironment('TURN_SERVER');
    const turnUsername = String.fromEnvironment('TURN_USERNAME');
    const turnCredential = String.fromEnvironment('TURN_CREDENTIAL');

    final servers = <Map<String, dynamic>>[];

    // Add custom STUN server if provided
    if (customStunServer.isNotEmpty) {
      servers.add({'urls': customStunServer});
    } else {
      // Default Google STUN servers
      servers.add({'urls': 'stun:stun.l.google.com:19302'});
      servers.add({'urls': 'stun:stun1.l.google.com:19302'});
    }

    // Add custom TURN server if provided
    if (customTurnServer.isNotEmpty) {
      final turnServer = {
        'urls': customTurnServer,
      };

      if (turnUsername.isNotEmpty && turnCredential.isNotEmpty) {
        turnServer['username'] = turnUsername;
        turnServer['credential'] = turnCredential;
      }

      servers.add(turnServer);
    }

    return servers;
  }
}
