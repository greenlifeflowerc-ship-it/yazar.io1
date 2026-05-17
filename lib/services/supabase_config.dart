/// Compile-time Supabase project settings.
///
/// NEVER place the service_role key here. The anon key is safe to ship to the
/// client; row-level security and the `submit_match_result` RPC keep stat
/// tampering on the server side.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://giwdsjzzelmuzeocktbu.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdpd2Rzanp6ZWxtdXplb2NrdGJ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg5OTA0MjUsImV4cCI6MjA5NDU2NjQyNX0._k9V1U124obh71KubAqk7lLvsuSsUh8PMG6emHGx230';
}
