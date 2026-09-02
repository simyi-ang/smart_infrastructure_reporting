import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client {
    return Supabase.instance.client;
  }

  static User? get currentUser {
    return client.auth.currentUser;
  }

  static Session? get currentSession {
    return client.auth.currentSession;
  }

  static bool get isLoggedIn {
    return currentUser != null;
  }
}