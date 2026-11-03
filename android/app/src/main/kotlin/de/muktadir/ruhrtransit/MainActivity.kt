package de.muktadir.ruhrtransit

import android.app.LocaleManager
import android.os.Build
import android.os.LocaleList
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    EventChannel(flutterEngine.dartExecutor.binaryMessenger, CONNECTIVITY_CHANNEL)
        .setStreamHandler(ConnectivityStreamHandler(applicationContext))
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_LOCALE_CHANNEL)
        .setMethodCallHandler { call, result ->
          // Per-app languages exist from Android 13; before, the app only
          // keeps its own preference (lib/features/language).
          if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(null)
            return@setMethodCallHandler
          }
          val manager = getSystemService(LocaleManager::class.java)
          when (call.method) {
            // e.g. "en", or null when the app follows the system language.
            "get" -> result.success(manager.applicationLocales.get(0)?.toLanguageTag())
            // The activity handles locale changes itself (configChanges in
            // the manifest), so this does not recreate it; Flutter gets the
            // new locale like any other configuration change.
            "set" -> {
              manager.applicationLocales = LocaleList.forLanguageTags(call.arguments as String)
              result.success(null)
            }
            else -> result.notImplemented()
          }
        }
  }

  private companion object {
    const val APP_LOCALE_CHANNEL = "de.muktadir.ruhrtransit/app_locale"
    const val CONNECTIVITY_CHANNEL = "de.muktadir.ruhrtransit/connectivity"
  }
}
