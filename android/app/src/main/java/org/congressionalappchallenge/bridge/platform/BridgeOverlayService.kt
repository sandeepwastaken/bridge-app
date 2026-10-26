package org.congressionalappchallenge.bridge.platform

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.ViewConfiguration
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.ScrollView
import org.congressionalappchallenge.bridge.MainActivity

class BridgeOverlayService : Service() {
    private lateinit var windows: WindowManager
    private var root: LinearLayout? = null
    private var expanded = false
    private var position: WindowManager.LayoutParams? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == STOP || !Settings.canDrawOverlays(this)) {
            stopSelf()
            return START_NOT_STICKY
        }
        val notifications = getSystemService(NotificationManager::class.java)
        notifications.createNotificationChannel(NotificationChannel(CHANNEL, "Floating assistant", NotificationManager.IMPORTANCE_LOW))
        val stop = PendingIntent.getService(this, 1, Intent(this, javaClass).setAction(STOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val open = PendingIntent.getActivity(this, 2, Intent(this, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = Notification.Builder(this, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle("Bridge assistant is available")
            .setContentText("Tap the circle for tools. Stop it here at any time.")
            .setContentIntent(open).setOngoing(true)
            .addAction(Notification.Action.Builder(null, "Stop assistant", stop).build()).build()
        if (Build.VERSION.SDK_INT >= 34) startForeground(42, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        else startForeground(42, notification)
        if (root == null) show()
        return START_NOT_STICKY
    }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    private fun show() {
        windows = getSystemService(WindowManager::class.java)
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.END
            setPadding(dp(8), dp(8), dp(8), dp(8))
        }
        root = layout
        populate(layout)
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE, PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = resources.displayMetrics.widthPixels - dp(84)
            y = resources.displayMetrics.heightPixels / 2
        }
        position = params
        try { windows.addView(layout, params) } catch (_: SecurityException) { root = null; stopSelf() }
    }

    private fun populate(layout: LinearLayout) {
        layout.removeAllViews()
        if (expanded) {
            val menu = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(8), dp(10), dp(8), dp(10))
                background = GradientDrawable().apply { setColor(Color.rgb(249, 251, 254)); cornerRadius = dp(24).toFloat() }
                elevation = dp(8).toFloat()
            }
            fun item(title: String, action: () -> Unit) {
                menu.addView(Button(this).apply {
                    text = title; isAllCaps = false; minHeight = dp(48)
                    setTextColor(Color.rgb(16, 18, 21)); setBackgroundColor(Color.TRANSPARENT)
                    setOnClickListener { expanded = false; populate(layout); action() }
                }, LinearLayout.LayoutParams((resources.displayMetrics.widthPixels - dp(48)).coerceAtMost(dp(280)), LinearLayout.LayoutParams.WRAP_CONTENT))
            }
            item("Use my voice") { startActivity(Intent(this, PhoneVoiceActivity::class.java).putExtra("bridge.listen", true).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
            for ((title, route) in listOf("Speak for me" to "Speak", "Translate" to "Translate", "Talk together" to "Together", "Read with me" to "Read", "Quick phrases" to "Phrases")) {
                item(title) { startActivity(Intent(this, MainActivity::class.java).putExtra("bridge.route", route).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)) }
            }
            item("Phone controls") { startActivity(Intent(this, PhoneVoiceActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
            item("Stop assistant") { stopSelf() }
            layout.addView(object : ScrollView(this) {
                override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
                    super.onMeasure(widthMeasureSpec, MeasureSpec.makeMeasureSpec((resources.displayMetrics.heightPixels - dp(160)).coerceAtLeast(dp(96)), MeasureSpec.AT_MOST))
                }
            }.apply { addView(menu) })
        }
        layout.addView(ImageButton(this).apply {
            setImageResource(android.R.drawable.ic_btn_speak_now)
            imageTintList = android.content.res.ColorStateList.valueOf(Color.WHITE)
            contentDescription = if (expanded) "Close Bridge assistant" else "Open Bridge assistant"
            background = GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(Color.rgb(16, 18, 21)) }
            setOnClickListener { expanded = !expanded; populate(layout) }
            var startX = 0f
            var startY = 0f
            var windowX = 0
            var windowY = 0
            var dragging = false
            val slop = ViewConfiguration.get(this@BridgeOverlayService).scaledTouchSlop
            setOnTouchListener { view, event ->
                val params = position ?: return@setOnTouchListener false
                when (event.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        startX = event.rawX; startY = event.rawY
                        windowX = params.x; windowY = params.y; dragging = false
                        true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = event.rawX - startX
                        val dy = event.rawY - startY
                        if (kotlin.math.abs(dx) > slop || kotlin.math.abs(dy) > slop) dragging = true
                        if (dragging) { params.x = windowX + dx.toInt(); params.y = windowY + dy.toInt(); fitOnScreen() }
                        true
                    }
                    MotionEvent.ACTION_UP -> { if (!dragging) view.performClick(); true }
                    MotionEvent.ACTION_CANCEL -> { dragging = false; true }
                    else -> false
                }
            }
        }, LinearLayout.LayoutParams(dp(56), dp(56)).apply { topMargin = dp(10) })
        layout.post { fitOnScreen() }
    }

    private fun fitOnScreen() {
        val view = root ?: return
        val params = position ?: return
        if (!view.isAttachedToWindow) return
        if (!Settings.canDrawOverlays(this)) { stopSelf(); return }
        val display = resources.displayMetrics
        params.x = params.x.coerceIn(0, (display.widthPixels - view.width).coerceAtLeast(0))
        params.y = params.y.coerceIn(dp(32), (display.heightPixels - view.height - dp(32)).coerceAtLeast(dp(32)))
        try { windows.updateViewLayout(view, params) } catch (_: IllegalArgumentException) { } catch (_: SecurityException) { stopSelf() }
    }

    override fun onDestroy() {
        root?.let { try { windows.removeView(it) } catch (_: IllegalArgumentException) { } }
        root = null
        super.onDestroy()
    }

    companion object { const val STOP = "bridge.overlay.STOP"; private const val CHANNEL = "bridge_assistant" }
}
