// Verbindung zur Datenbank (Supabase).
// Beide Werte findest du im Supabase-Dashboard unter Project Settings → API.
// Der "anon public" Schlüssel darf öffentlich sein: Die Datenbank-Regeln (Row Level Security)
// sorgen dafür, dass jede Person nur ihre eigenen Daten lesen und ändern kann.
// Bleiben die Felder leer, läuft die App ohne Anmeldung und speichert nur auf dem Gerät.
window.LERNPLANER_CONFIG = {
  supabaseUrl: "",
  supabaseAnonKey: ""
};
