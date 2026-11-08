package de.muktadir.ruhrtransit

import android.app.LocaleManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.os.Build
import android.os.LocaleList
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    EventChannel(flutterEngine.dartExecutor.binaryMessenger, CONNECTIVITY_CHANNEL)
        .setStreamHandler(ConnectivityStreamHandler(applicationContext))
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_SETTINGS_CHANNEL)
        .setMethodCallHandler { call, result ->
          when (call.method) {
            "accessibility" -> {
              openSystemSettings(Settings.ACTION_ACCESSIBILITY_SETTINGS)
              result.success(null)
            }
            else -> result.notImplemented()
          }
        }
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

  /// Opens a page of Android's Settings app. An app may open these but not
  /// change what they control, e.g. turn on TalkBack.
  private fun openSystemSettings(action: String) {
    try {
      startActivity(Intent(action))
    } catch (e: ActivityNotFoundException) {
      // Some phones lack the page; the main Settings page has a search.
      startActivity(Intent(Settings.ACTION_SETTINGS))
    }
  }

  private companion object {
    const val APP_LOCALE_CHANNEL = "de.muktadir.ruhrtransit/app_locale"
    const val CONNECTIVITY_CHANNEL = "de.muktadir.ruhrtransit/connectivity"
    const val SYSTEM_SETTINGS_CHANNEL = "de.muktadir.ruhrtransit/system_settings"
  }
}
