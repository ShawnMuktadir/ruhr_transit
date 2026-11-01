package de.muktadir.ruhrtransit

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.text.format.DateFormat
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Date
import org.json.JSONException
import org.json.JSONObject

/**
 * Home-screen widget with the next departures of one stop.
 *
 * Only renders: the Flutter app writes the data (`widget_board_v1`, see
 * `lib/features/widget_sync/data/widget_board_json.dart`) and asks for a redraw.
 * Android also redraws every 30 minutes, which drops departures that have left.
 */
class DepartureWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val board = readBoard(widgetData.getString(BOARD_KEY, null))
    val views =
        try {
          render(context, board)
        } catch (e: JSONException) {
          // Unexpected data must not crash the launcher's widget host.
          render(context, null)
        }
    for (appWidgetId in appWidgetIds) {
      appWidgetManager.updateAppWidget(appWidgetId, views)
    }
  }

  private fun render(context: Context, board: JSONObject?): RemoteViews {
    val views = RemoteViews(context.packageName, R.layout.departure_widget)
    val stop = board?.optJSONObject("stop")
    if (board == null || stop == null) {
      // The layout's defaults: app name and "choose a stop".
      views.setOnClickPendingIntent(android.R.id.background, launch(context, null))
      return views
    }

    val stopId = stop.getString("id")
    views.setTextViewText(R.id.stop_name, stop.getString("fullName"))
    views.setOnClickPendingIntent(android.R.id.background, launch(context, stopId))

    val fetchedAt = board.optLong("fetchedAt", 0)
    views.setTextViewText(
        R.id.updated_at,
        if (fetchedAt > 0) {
          context.getString(R.string.widget_updated_at, formatTime(context, fetchedAt))
        } else {
          ""
        },
    )

    // Sorted by leaving time in Dart; skip those that have left.
    val now = System.currentTimeMillis()
    val departures = board.getJSONArray("departures")
    val upcoming =
        (0 until departures.length())
            .map { departures.getJSONObject(it) }
            .filter { leavesAt(it) >= now }
            .take(ROWS.size)

    if (upcoming.isEmpty()) {
      views.setTextViewText(R.id.message, context.getString(R.string.widget_open_app))
      views.setViewVisibility(R.id.message, View.VISIBLE)
      views.setViewVisibility(R.id.rows, View.GONE)
      return views
    }
    views.setViewVisibility(R.id.message, View.GONE)
    views.setViewVisibility(R.id.rows, View.VISIBLE)
    ROWS.forEachIndexed { index, row ->
      val departure = upcoming.getOrNull(index)
      if (departure == null) {
        views.setViewVisibility(row.row, View.INVISIBLE)
      } else {
        views.setViewVisibility(row.row, View.VISIBLE)
        fillRow(context, views, row, departure)
      }
    }
    return views
  }

  private fun fillRow(context: Context, views: RemoteViews, row: Row, departure: JSONObject) {
    val planned = departure.getLong("plannedTime")
    views.setTextViewText(row.line, departure.getString("line"))
    views.setTextViewText(row.destination, departure.getString("destination"))
    views.setTextViewText(row.time, formatTime(context, planned))
    views.setTextViewText(
        row.delay,
        when {
          departure.optBoolean("isCancelled") -> context.getString(R.string.widget_cancelled)
          departure.isNull("estimatedTime") -> ""
          else -> {
            val minutes = (departure.getLong("estimatedTime") - planned) / 60_000
            when {
              minutes > 0 -> "+$minutes"
              minutes < 0 -> "$minutes"
              else -> ""
            }
          }
        },
    )
  }

  private fun leavesAt(departure: JSONObject): Long =
      if (departure.isNull("estimatedTime")) {
        departure.getLong("plannedTime")
      } else {
        departure.getLong("estimatedTime")
      }

  /** In the device's time zone and 12/24-hour setting, like the app. */
  private fun formatTime(context: Context, epochMillis: Long): String =
      DateFormat.getTimeFormat(context).format(Date(epochMillis))

  /** Opens the app, on the stop's board if [stopId] is set. */
  private fun launch(context: Context, stopId: String?) =
      HomeWidgetLaunchIntent.getActivity(
          context,
          MainActivity::class.java,
          stopId?.let { Uri.parse("ruhrtransit://departures?stopId=${Uri.encode(it)}") },
      )

  private fun readBoard(raw: String?): JSONObject? =
      try {
        raw?.let(::JSONObject)
      } catch (e: JSONException) {
        null
      }

  private class Row(val row: Int, val line: Int, val destination: Int, val time: Int, val delay: Int)

  private companion object {
    const val BOARD_KEY = "widget_board_v1"

    val ROWS =
        listOf(
            Row(R.id.row_0, R.id.line_0, R.id.destination_0, R.id.time_0, R.id.delay_0),
            Row(R.id.row_1, R.id.line_1, R.id.destination_1, R.id.time_1, R.id.delay_1),
            Row(R.id.row_2, R.id.line_2, R.id.destination_2, R.id.time_2, R.id.delay_2),
        )
  }
}
