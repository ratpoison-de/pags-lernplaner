package de.vonplotho.vokabeltrainer;

// PAGS Vokabeltrainer – Android-Hülle
// Entwickelt von Thorsten von Plotho-Kettner, Pater-Alois-Grimm-Schule Külsheim

import android.Manifest;
import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.res.AssetManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.provider.MediaStore;
import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;
import android.speech.tts.Voice;
import android.util.Base64;
import android.view.View;
import android.view.WindowManager;
import android.webkit.JavascriptInterface;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

public class MainActivity extends Activity {
    static final String HOST = "appassets.androidplatform.net";
    static final String START = "https://" + HOST + "/index.html";
    static final int REQ_FILE = 11;

    WebView web;
    TextToSpeech tts;
    boolean ttsReady = false;
    ValueCallback<Uri[]> fileCb;
    Uri cameraUri;

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        web = new WebView(this);
        setContentView(web);

        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setDatabaseEnabled(true);
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setAllowFileAccess(false);
        s.setAllowContentAccess(true);
        s.setTextZoom(100);
        s.setUserAgentString(s.getUserAgentString() + " PAGSVokabeltrainerAndroid/1.0");

        web.addJavascriptInterface(new Bridge(), "AndroidApp");
        web.setWebViewClient(new Client());
        web.setWebChromeClient(new Chrome());

        tts = new TextToSpeech(this, status -> {
            ttsReady = status == TextToSpeech.SUCCESS;
            if (ttsReady) {
                tts.setOnUtteranceProgressListener(new UtteranceProgressListener() {
                    @Override public void onStart(String id) {}
                    @Override public void onDone(String id) { done(id); }
                    @Override public void onError(String id) { done(id); }
                    @Override public void onStop(String id, boolean interrupted) { done(id); }
                });
            }
        });

        if (Build.VERSION.SDK_INT < 29 && checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.WRITE_EXTERNAL_STORAGE}, 2);
        }

        if (b != null) web.restoreState(b); else web.loadUrl(START);
    }

    void done(String id) {
        runOnUiThread(() -> web.evaluateJavascript("window.__ttsDone&&window.__ttsDone(" + JSONObject.quote(id) + ")", null));
    }

    @Override protected void onSaveInstanceState(Bundle o) { super.onSaveInstanceState(o); web.saveState(o); }

    @Override
    public void onBackPressed() {
        web.evaluateJavascript("window.__androidBack?window.__androidBack():false", v -> {
            if (!"true".equals(v)) finish();
        });
    }

    @Override
    protected void onDestroy() {
        if (tts != null) { tts.stop(); tts.shutdown(); }
        super.onDestroy();
    }

    /* ---------- App-Dateien aus assets/www ausliefern ---------- */
    class Client extends WebViewClient {
        @Override
        public WebResourceResponse shouldInterceptRequest(WebView v, WebResourceRequest r) {
            Uri u = r.getUrl();
            if (!HOST.equals(u.getHost())) return null;
            String p = u.getPath();
            if (p == null || p.equals("/") || p.isEmpty()) p = "/index.html";
            try {
                InputStream in = getAssets().open("www" + p, AssetManager.ACCESS_STREAMING);
                WebResourceResponse res = new WebResourceResponse(mime(p), mime(p).startsWith("text") || p.endsWith(".js") || p.endsWith(".json") ? "utf-8" : null, in);
                Map<String, String> h = new HashMap<>();
                h.put("Cache-Control", "no-cache");
                h.put("Access-Control-Allow-Origin", "*");
                res.setResponseHeaders(h);
                return res;
            } catch (IOException e) {
                return new WebResourceResponse("text/plain", "utf-8", 404, "Not Found", null, null);
            }
        }

        @Override
        public boolean shouldOverrideUrlLoading(WebView v, WebResourceRequest r) {
            Uri u = r.getUrl();
            if (HOST.equals(u.getHost())) return false;
            try { startActivity(new Intent(Intent.ACTION_VIEW, u)); } catch (ActivityNotFoundException e) { /* ignorieren */ }
            return true;
        }
    }

    static String mime(String p) {
        p = p.toLowerCase(Locale.ROOT);
        if (p.endsWith(".html")) return "text/html";
        if (p.endsWith(".js")) return "application/javascript";
        if (p.endsWith(".css")) return "text/css";
        if (p.endsWith(".png")) return "image/png";
        if (p.endsWith(".jpg") || p.endsWith(".jpeg")) return "image/jpeg";
        if (p.endsWith(".json") || p.endsWith(".webmanifest")) return "application/json";
        if (p.endsWith(".svg")) return "image/svg+xml";
        return "application/octet-stream";
    }

    /* ---------- Kamera / Galerie / Datei-Import ---------- */
    class Chrome extends WebChromeClient {
        @Override
        public boolean onShowFileChooser(WebView v, ValueCallback<Uri[]> cb, FileChooserParams p) {
            if (fileCb != null) fileCb.onReceiveValue(null);
            fileCb = cb;
            String[] acc = p.getAcceptTypes();
            boolean images = acc != null && acc.length > 0 && acc[0] != null && acc[0].startsWith("image");
            try {
                if (p.isCaptureEnabled() && images) {
                    ContentValues cv = new ContentValues();
                    cv.put(MediaStore.Images.Media.DISPLAY_NAME, "vokabeln_" + System.currentTimeMillis() + ".jpg");
                    cv.put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg");
                    if (Build.VERSION.SDK_INT >= 29) cv.put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/Vokabeltrainer");
                    cameraUri = getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, cv);
                    Intent cam = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
                    cam.putExtra(MediaStore.EXTRA_OUTPUT, cameraUri);
                    cam.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
                    startActivityForResult(cam, REQ_FILE);
                } else {
                    cameraUri = null;
                    Intent i = new Intent(Intent.ACTION_GET_CONTENT);
                    i.addCategory(Intent.CATEGORY_OPENABLE);
                    i.setType(images ? "image/*" : "*/*");
                    if (p.getMode() == FileChooserParams.MODE_OPEN_MULTIPLE) i.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
                    startActivityForResult(Intent.createChooser(i, images ? "Fotos auswählen" : "Datei auswählen"), REQ_FILE);
                }
            } catch (Exception e) {
                fileCb = null;
                Toast.makeText(MainActivity.this, "Kamera oder Dateiauswahl nicht verfügbar.", Toast.LENGTH_LONG).show();
                return false;
            }
            return true;
        }
    }

    @Override
    protected void onActivityResult(int req, int res, Intent data) {
        super.onActivityResult(req, res, data);
        if (req != REQ_FILE || fileCb == null) return;
        Uri[] out = null;
        if (res == RESULT_OK) {
            if (cameraUri != null) {
                out = new Uri[]{cameraUri};
            } else if (data != null) {
                if (data.getClipData() != null) {
                    int n = data.getClipData().getItemCount();
                    out = new Uri[n];
                    for (int k = 0; k < n; k++) out[k] = data.getClipData().getItemAt(k).getUri();
                } else if (data.getData() != null) {
                    out = new Uri[]{data.getData()};
                }
            }
        } else if (cameraUri != null) {
            try { getContentResolver().delete(cameraUri, null, null); } catch (Exception e) { /* egal */ }
        }
        fileCb.onReceiveValue(out);
        fileCb = null;
        cameraUri = null;
    }

    /* ---------- Brücke für die Web-App ---------- */
    class Bridge {
        @JavascriptInterface
        public boolean ttsAvailable() { return ttsReady; }

        @JavascriptInterface
        public String ttsVoices() {
            JSONArray a = new JSONArray();
            if (!ttsReady) return a.toString();
            try {
                Set<Voice> vs = tts.getVoices();
                if (vs != null) for (Voice v : vs) {
                    if (v.getFeatures() != null && v.getFeatures().contains(TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED)) continue;
                    JSONObject o = new JSONObject();
                    o.put("name", v.getName());
                    o.put("lang", v.getLocale().toLanguageTag());
                    o.put("local", !v.isNetworkConnectionRequired());
                    a.put(o);
                }
            } catch (Exception e) { /* leer */ }
            return a.toString();
        }

        @JavascriptInterface
        public boolean ttsSpeak(String id, String text, String lang, float rate, String voiceName) {
            if (!ttsReady) return false;
            Locale loc = Locale.forLanguageTag(lang == null || lang.isEmpty() ? "de-DE" : lang);
            boolean voiceSet = false;
            if (voiceName != null && !voiceName.isEmpty()) {
                try {
                    for (Voice v : tts.getVoices()) if (v.getName().equals(voiceName)) { tts.setVoice(v); voiceSet = true; break; }
                } catch (Exception e) { /* weiter */ }
            }
            if (!voiceSet) {
                int r = tts.setLanguage(loc);
                if (r == TextToSpeech.LANG_MISSING_DATA || r == TextToSpeech.LANG_NOT_SUPPORTED) return false;
            }
            tts.setSpeechRate(rate <= 0 ? 0.9f : rate);
            Bundle p = new Bundle();
            p.putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, id);
            return tts.speak(text, TextToSpeech.QUEUE_FLUSH, p, id) == TextToSpeech.SUCCESS;
        }

        @JavascriptInterface
        public void ttsStop() { if (ttsReady) tts.stop(); }

        @JavascriptInterface
        public void ttsSettings() {
            runOnUiThread(() -> {
                try { startActivity(new Intent("com.android.settings.TTS_SETTINGS")); }
                catch (Exception e) {
                    try { startActivity(new Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA)); } catch (Exception e2) { /* nichts */ }
                }
            });
        }

        @JavascriptInterface
        public void keepAwake(boolean on) {
            runOnUiThread(() -> {
                if (on) getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
                else getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
            });
        }

        /** Speichert Text (Sicherung/CSV) im Ordner „Download“. */
        @JavascriptInterface
        public String saveFile(String name, String content, String mime) {
            try {
                byte[] bytes = content.getBytes(StandardCharsets.UTF_8);
                if (Build.VERSION.SDK_INT >= 29) {
                    ContentValues cv = new ContentValues();
                    cv.put(MediaStore.Downloads.DISPLAY_NAME, name);
                    cv.put(MediaStore.Downloads.MIME_TYPE, mime);
                    cv.put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/Vokabeltrainer");
                    ContentResolver cr = getContentResolver();
                    Uri u = cr.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, cv);
                    if (u == null) throw new IOException("kein Speicherort");
                    OutputStream os = cr.openOutputStream(u); os.write(bytes); os.close();
                } else {
                    File dir = new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "Vokabeltrainer");
                    if (!dir.exists()) dir.mkdirs();
                    FileOutputStream fo = new FileOutputStream(new File(dir, name)); fo.write(bytes); fo.close();
                }
                return "Gespeichert in „Download/Vokabeltrainer“.";
            } catch (Exception e) {
                return "";
            }
        }

        @JavascriptInterface
        public String version() { return "1.0"; }
    }
}
