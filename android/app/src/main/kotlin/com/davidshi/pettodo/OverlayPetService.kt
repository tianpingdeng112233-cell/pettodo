package com.davidshi.pettodo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import kotlin.math.abs
import kotlin.math.roundToInt

class OverlayPetService : Service() {
    private lateinit var windowManager: WindowManager
    private var petView: OverlayPetView? = null
    private var screenReceiverRegistered = false

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> petView?.setScreenOn(false)
                Intent.ACTION_SCREEN_ON -> petView?.setScreenOn(true)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        activeService = this
        windowManager = getSystemService(WindowManager::class.java)
        showOverlay()
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screenReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(screenReceiver, filter)
        }
        screenReceiverRegistered = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!android.provider.Settings.canDrawOverlays(this)) {
            preferences(this).edit().putBoolean(KEY_ENABLED, false).apply()
            stopSelf()
            return START_NOT_STICKY
        }
        val petName = intent?.getStringExtra(EXTRA_PET_NAME)?.trim()
            ?.takeIf(String::isNotEmpty)
            ?: preferences(this).getString(KEY_PET_NAME, "Choco")
            ?: "Choco"
        preferences(this).edit()
            .putBoolean(KEY_ENABLED, true)
            .putString(KEY_PET_NAME, petName)
            .apply()
        startInForeground(petName)
        if (petView == null) showOverlay()
        if (intent?.action == ACTION_CELEBRATE) petView?.celebrate()
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        if (activeService === this) activeService = null
        petView?.let {
            it.persistPosition()
            windowManager.removeView(it)
            it.release()
        }
        petView = null
        if (screenReceiverRegistered) unregisterReceiver(screenReceiver)
        screenReceiverRegistered = false
        super.onDestroy()
    }

    private fun showOverlay() {
        if (petView != null || !android.provider.Settings.canDrawOverlays(this)) return
        val view = OverlayPetView(this, windowManager)
        petView = view
        windowManager.addView(view, view.layoutParams)
        val powerManager = getSystemService(PowerManager::class.java)
        view.setScreenOn(powerManager.isInteractive)
    }

    private fun startInForeground(petName: String) {
        val notificationManager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notificationManager.createNotificationChannel(
                NotificationChannel(
                    NOTIFICATION_CHANNEL_ID,
                    "Pawside companion",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = "A quiet home for your floating pet."
                    setShowBadge(false)
                },
            )
        }
        val openIntent = (packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)).addFlags(
            Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP,
        )
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("$petName is keeping you company")
            .setContentText("Tap to visit Pawside")
            .setContentIntent(pendingIntent)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    companion object {
        private const val ACTION_START = "com.davidshi.pettodo.overlay.START"
        private const val ACTION_CELEBRATE = "com.davidshi.pettodo.overlay.CELEBRATE"
        private const val EXTRA_PET_NAME = "petName"
        private const val PREFERENCES = "floating_pet"
        private const val KEY_ENABLED = "enabled"
        private const val KEY_PET_NAME = "petName"
        private const val NOTIFICATION_CHANNEL_ID = "floating_pet_companion"
        private const val NOTIFICATION_ID = 2002
        @Volatile
        private var activeService: OverlayPetService? = null

        internal fun preferences(context: Context) =
            context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

        fun isEnabled(context: Context): Boolean {
            val preferences = preferences(context)
            val enabled = preferences.getBoolean(KEY_ENABLED, false)
            if (enabled && !android.provider.Settings.canDrawOverlays(context)) {
                preferences.edit().putBoolean(KEY_ENABLED, false).apply()
                context.stopService(Intent(context, OverlayPetService::class.java))
                return false
            }
            return enabled
        }

        fun start(context: Context, petName: String) {
            val intent = Intent(context, OverlayPetService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_PET_NAME, petName)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun celebrate(context: Context) {
            if (!isEnabled(context)) return
            activeService?.petView?.let { view ->
                view.celebrate()
                return
            }
            val petName = preferences(context).getString(KEY_PET_NAME, "Choco")
            val intent = Intent(context, OverlayPetService::class.java).apply {
                action = ACTION_CELEBRATE
                putExtra(EXTRA_PET_NAME, petName)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            preferences(context).edit().putBoolean(KEY_ENABLED, false).apply()
            context.stopService(Intent(context, OverlayPetService::class.java))
        }
    }
}

private class OverlayPetView(
    private val appContext: Context,
    private val windowManager: WindowManager,
) : View(appContext) {
    private val preferences = OverlayPetService.preferences(appContext)
    private val handler = Handler(Looper.getMainLooper())
    private val paint = Paint().apply {
        isAntiAlias = false
        isFilterBitmap = false
        isDither = false
    }
    private val idleFrames = intArrayOf(
        R.drawable.overlay_idle_0,
        R.drawable.overlay_idle_1,
        R.drawable.overlay_idle_2,
        R.drawable.overlay_idle_3,
        R.drawable.overlay_idle_4,
        R.drawable.overlay_idle_5,
    ).map(::decodeFrame)
    private val celebrationFrames = intArrayOf(
        R.drawable.overlay_jumping_0,
        R.drawable.overlay_jumping_1,
        R.drawable.overlay_jumping_2,
        R.drawable.overlay_jumping_3,
        R.drawable.overlay_jumping_4,
    ).map(::decodeFrame)
    private var frames: List<Bitmap> = idleFrames
    private var frameIndex = 0
    private var screenOn = true
    private var celebrationEndsAt = 0L
    private var downRawX = 0f
    private var downRawY = 0f
    private var startX = 0
    private var startY = 0
    private var dragged = false
    private val touchSlop = ViewConfiguration.get(appContext).scaledTouchSlop
    private val frameWidth = idleFrames.first().width
    private val frameHeight = idleFrames.first().height
    private val pixelScale = 1

    val layoutParams: WindowManager.LayoutParams = WindowManager.LayoutParams(
        frameWidth * pixelScale,
        frameHeight * pixelScale,
        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
        PixelFormat.TRANSLUCENT,
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        x = preferences.getInt(KEY_X, defaultX())
        y = preferences.getInt(KEY_Y, defaultY())
    }

    private val advanceFrame = object : Runnable {
        override fun run() {
            if (!screenOn || !isAttachedToWindow) return
            if (frames === celebrationFrames &&
                android.os.SystemClock.uptimeMillis() >= celebrationEndsAt
            ) {
                frames = idleFrames
                frameIndex = 0
            } else {
                frameIndex = (frameIndex + 1) % frames.size
            }
            invalidate()
            handler.postDelayed(this, FRAME_DELAY_MILLIS)
        }
    }

    init {
        contentDescription = "Floating Pawside pet. Tap to open Pawside."
        isClickable = true
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        scheduleAnimation()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val bitmap = frames[frameIndex.coerceIn(frames.indices)]
        canvas.scale(pixelScale.toFloat(), pixelScale.toFloat())
        canvas.drawBitmap(bitmap, 0f, 0f, paint)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                downRawX = event.rawX
                downRawY = event.rawY
                startX = layoutParams.x
                startY = layoutParams.y
                dragged = false
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = event.rawX - downRawX
                val dy = event.rawY - downRawY
                if (!dragged && (abs(dx) > touchSlop || abs(dy) > touchSlop)) {
                    dragged = true
                }
                if (dragged) {
                    val bounds = screenBounds()
                    layoutParams.x = (startX + dx.roundToInt()).coerceIn(
                        0,
                        (bounds.first - width).coerceAtLeast(0),
                    )
                    layoutParams.y = (startY + dy.roundToInt()).coerceIn(
                        0,
                        (bounds.second - height).coerceAtLeast(0),
                    )
                    windowManager.updateViewLayout(this, layoutParams)
                }
                return true
            }
            MotionEvent.ACTION_UP -> {
                persistPosition()
                if (!dragged) performClick()
                return true
            }
            MotionEvent.ACTION_CANCEL -> {
                persistPosition()
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    override fun performClick(): Boolean {
        super.performClick()
        appContext.packageManager.getLaunchIntentForPackage(appContext.packageName)
            ?.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
            )
            ?.let(appContext::startActivity)
        return true
    }

    fun celebrate() {
        frames = celebrationFrames
        frameIndex = 0
        celebrationEndsAt = android.os.SystemClock.uptimeMillis() + CELEBRATION_MILLIS
        invalidate()
        scheduleAnimation()
    }

    fun setScreenOn(value: Boolean) {
        screenOn = value
        if (value) scheduleAnimation() else handler.removeCallbacks(advanceFrame)
    }

    fun persistPosition() {
        preferences.edit()
            .putInt(KEY_X, layoutParams.x)
            .putInt(KEY_Y, layoutParams.y)
            .apply()
    }

    fun release() {
        handler.removeCallbacksAndMessages(null)
        (idleFrames + celebrationFrames).toSet().forEach(Bitmap::recycle)
    }

    private fun scheduleAnimation() {
        handler.removeCallbacks(advanceFrame)
        if (screenOn && isAttachedToWindow) {
            handler.postDelayed(advanceFrame, FRAME_DELAY_MILLIS)
        }
    }

    private fun decodeFrame(resourceId: Int): Bitmap =
        checkNotNull(BitmapFactory.decodeResource(resources, resourceId))

    private fun defaultX(): Int = (screenBounds().first - 192 * 2 - 32).coerceAtLeast(0)

    private fun defaultY(): Int = (screenBounds().second / 3).coerceAtLeast(0)

    private fun screenBounds(): Pair<Int, Int> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = windowManager.currentWindowMetrics.bounds
            return bounds.width() to bounds.height()
        }
        @Suppress("DEPRECATION")
        return windowManager.defaultDisplay.width to windowManager.defaultDisplay.height
    }

    private companion object {
        const val KEY_X = "x"
        const val KEY_Y = "y"
        const val FRAME_DELAY_MILLIS = 125L
        const val CELEBRATION_MILLIS = 1_750L
    }
}
