// Verbindung zur Datenbank (Supabase).
// Beide Werte findest du im Supabase-Dashboard unter Project Settings → API.
// Der "anon public" Schlüssel darf öffentlich sein: Die Datenbank-Regeln (Row Level Security)
// sorgen dafür, dass jede Person nur ihre eigenen Daten lesen und ändern kann.
// Bleiben die Felder leer, läuft die App ohne Anmeldung und speichert nur auf dem Gerät.
window.LERNPLANER_CONFIG = {
  supabaseUrl: "https://nvobliagvkfissdtfmts.supabase.co",
  supabaseAnonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im52b2JsaWFndmtmaXNzZHRmbXRzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI4OTM5NjMsImV4cCI6MjEwODQ2OTk2M30.uaHZlXoiycEOXYaCy9YmxBdcvwC-rZ1GDBjFuKTIsTU"
};
