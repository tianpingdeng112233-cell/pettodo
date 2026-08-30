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
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.widget.TextView
import kotlin.math.abs
import kotlin.math.roundToInt
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.Executors

internal data class OverlayBubbleInvitation(
    val scheduledAtEpochMillis: Long,
    val copy: String,
)

class OverlayPetService : Service() {
    private lateinit var windowManager: WindowManager
    private var petView: OverlayPetView? = null
    private var bubbleView: View? = null
    private var screenReceiverRegistered = false
    private val handler = Handler(Looper.getMainLooper())
    private var bubbleSchedule = emptyList<OverlayBubbleInvitation>()
    private var screenOn = true
    private var bubbleDismissAtUptimeMillis = 0L
    private var bubbleVisibleRemainingMillis = BUBBLE_DURATION_MILLIS
    private var currentIdleFramePaths: List<String>? = null
    private var currentJumpingFramePaths: List<String>? = null
    private val showNextBubble = Runnable { showDueBubble() }
    private val dismissBubble = Runnable { hideBubble() }

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    screenOn = false
                    petView?.setScreenOn(false)
                    pauseBubbleDismissal()
                    handler.removeCallbacks(showNextBubble)
                }
                Intent.ACTION_SCREEN_ON -> {
                    screenOn = true
                    petView?.setScreenOn(true)
                    if (bubbleView != null) {
                        resumeBubbleDismissal()
                    } else {
                        reconcileBubbleSchedule()
                    }
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        activeService = this
        windowManager = getSystemService(WindowManager::class.java)
        screenOn = getSystemService(PowerManager::class.java).isInteractive
        currentIdleFramePaths = loadFramePaths(KEY_IDLE_FRAME_PATHS)
        currentJumpingFramePaths = loadFramePaths(KEY_JUMPING_FRAME_PATHS)
        showOverlay()
        updateBubbleSchedule(loadBubbleSchedule())
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
        if (intent?.hasExtra(EXTRA_USE_FILE_FRAMES) == true) {
            val useFileFrames = intent.getBooleanExtra(EXTRA_USE_FILE_FRAMES, false)
            val idlePaths = if (useFileFrames) {
                intent.getStringArrayListExtra(EXTRA_IDLE_FRAME_PATHS)?.toList()
            } else {
                null
            }
            val jumpingPaths = if (useFileFrames) {
                intent.getStringArrayListExtra(EXTRA_JUMPING_FRAME_PATHS)?.toList()
            } else {
                null
            }
            if (idlePaths != currentIdleFramePaths || jumpingPaths != currentJumpingFramePaths) {
                currentIdleFramePaths = idlePaths
                currentJumpingFramePaths = jumpingPaths
                persistFramePaths(idlePaths, jumpingPaths)
                petView?.reloadFrames(idlePaths, jumpingPaths)
            }
        }
        if (intent?.hasExtra(EXTRA_BUBBLE_TIMES) == true) {
            val times = intent.getLongArrayExtra(EXTRA_BUBBLE_TIMES) ?: longArrayOf()
            val copies = intent.getStringArrayListExtra(EXTRA_BUBBLE_COPIES)
                ?: arrayListOf()
            val bubbles = times.indices.mapNotNull { index ->
                copies.getOrNull(index)?.let { copy ->
                    OverlayBubbleInvitation(times[index], copy)
                }
            }
            persistBubbleSchedule(bubbles)
            updateBubbleSchedule(bubbles)
        }
        startInForeground(petName)
        if (petView == null) showOverlay()
        if (intent?.action == ACTION_CELEBRATE) petView?.celebrate()
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun applyForegroundState() {
        if (appInForeground) {
            hideBubble()
            handler.removeCallbacks(showNextBubble)
            petView?.let {
                it.persistPosition()
                if (it.isAttachedToWindow) windowManager.removeView(it)
                it.release()
            }
            petView = null
        } else {
            showOverlay()
            reconcileBubbleSchedule()
        }
    }

    override fun onDestroy() {
        if (activeService === this) activeService = null
        handler.removeCallbacksAndMessages(null)
        hideBubble()
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

    private fun updateBubbleSchedule(bubbles: List<OverlayBubbleInvitation>) {
        bubbleSchedule = bubbles
            .filter { it.copy.isNotBlank() }
            .sortedBy(OverlayBubbleInvitation::scheduledAtEpochMillis)
        reconcileBubbleSchedule()
    }

    private fun scheduleNextBubble() {
        handler.removeCallbacks(showNextBubble)
        if (!screenOn) return
        val next = bubbleSchedule.firstOrNull() ?: return
        handler.postDelayed(
            showNextBubble,
            (next.scheduledAtEpochMillis - System.currentTimeMillis()).coerceAtLeast(0L),
        )
    }

    private fun showDueBubble() {
        if (!screenOn) return
        reconcileBubbleSchedule()
    }

    private fun reconcileBubbleSchedule() {
        if (!screenOn) {
            handler.removeCallbacks(showNextBubble)
            return
        }
        val now = System.currentTimeMillis()
        val due = bubbleSchedule.filter { it.scheduledAtEpochMillis <= now }
        bubbleSchedule = bubbleSchedule.filter { it.scheduledAtEpochMillis > now }
        val mostRecent = due.lastOrNull()
        if (
            screenOn &&
            bubbleView == null &&
            mostRecent != null &&
            now - mostRecent.scheduledAtEpochMillis <= MAX_OVERDUE_BUBBLE_AGE_MILLIS
        ) {
            showBubble(mostRecent.copy)
        }
        persistBubbleSchedule(bubbleSchedule)
        scheduleNextBubble()
    }

    private fun showBubble(copy: String) {
        hideBubble()
        val pet = petView ?: return
        val density = resources.displayMetrics.density
        val bubble = TextView(this).apply {
            text = copy
            textSize = 15f
            setTextColor(Color.rgb(72, 50, 38))
            setPadding(
                (14 * density).roundToInt(),
                (10 * density).roundToInt(),
                (14 * density).roundToInt(),
                (10 * density).roundToInt(),
            )
            maxWidth = (240 * density).roundToInt()
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 14 * density
                setColor(Color.rgb(255, 248, 232))
                setStroke((2 * density).roundToInt().coerceAtLeast(1), Color.rgb(95, 67, 49))
            }
            elevation = 6 * density
            contentDescription = "$copy Tap to open Pawside."
            setOnClickListener { openApp() }
        }
        val margin = (8 * density).roundToInt()
        val bounds = screenBounds()
        val preferredX = pet.layoutParams.x + pet.width + margin
        val estimatedWidth = (240 * density).roundToInt()
        val x = if (preferredX + estimatedWidth <= bounds.first) {
            preferredX
        } else {
            (pet.layoutParams.x - estimatedWidth - margin).coerceAtLeast(0)
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            this.x = x
            y = pet.layoutParams.y
        }
        bubbleView = bubble
        windowManager.addView(bubble, params)
        bubbleVisibleRemainingMillis = BUBBLE_DURATION_MILLIS
        resumeBubbleDismissal()
    }

    private fun pauseBubbleDismissal() {
        if (bubbleView == null || bubbleDismissAtUptimeMillis == 0L) return
        bubbleVisibleRemainingMillis =
            (bubbleDismissAtUptimeMillis - SystemClock.uptimeMillis()).coerceAtLeast(0L)
        bubbleDismissAtUptimeMillis = 0L
        handler.removeCallbacks(dismissBubble)
    }

    private fun resumeBubbleDismissal() {
        if (bubbleView == null) return
        handler.removeCallbacks(dismissBubble)
        bubbleDismissAtUptimeMillis =
            SystemClock.uptimeMillis() + bubbleVisibleRemainingMillis
        handler.postDelayed(dismissBubble, bubbleVisibleRemainingMillis)
    }

    private fun hideBubble() {
        handler.removeCallbacks(dismissBubble)
        bubbleView?.let { view ->
            if (view.isAttachedToWindow) windowManager.removeView(view)
        }
        bubbleView = null
        bubbleDismissAtUptimeMillis = 0L
        bubbleVisibleRemainingMillis = BUBBLE_DURATION_MILLIS
    }

    private fun openApp() {
        packageManager.getLaunchIntentForPackage(packageName)
            ?.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
            )
            ?.let(::startActivity)
    }

    private fun screenBounds(): Pair<Int, Int> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = windowManager.currentWindowMetrics.bounds
            return bounds.width() to bounds.height()
        }
        @Suppress("DEPRECATION")
        return windowManager.defaultDisplay.width to windowManager.defaultDisplay.height
    }

    private fun showOverlay() {
        // The floating pet only lives outside the app: while Pawside itself is
        // in the foreground the overlay stays hidden (David 2026-08-30).
        if (appInForeground) return
        if (petView != null || !android.provider.Settings.canDrawOverlays(this)) return
        val view = OverlayPetView(
            this,
            windowManager,
        )
        petView = view
        windowManager.addView(view, view.layoutParams)
        view.setScreenOn(screenOn)
        view.reloadFrames(currentIdleFramePaths, currentJumpingFramePaths)
    }

    private fun persistFramePaths(idlePaths: List<String>?, jumpingPaths: List<String>?) {
        preferences(this).edit().apply {
            if (idlePaths == null || jumpingPaths == null) {
                remove(KEY_IDLE_FRAME_PATHS)
                remove(KEY_JUMPING_FRAME_PATHS)
            } else {
                putString(KEY_IDLE_FRAME_PATHS, JSONArray(idlePaths).toString())
                putString(KEY_JUMPING_FRAME_PATHS, JSONArray(jumpingPaths).toString())
            }
        }.apply()
    }

    private fun loadFramePaths(key: String): List<String>? {
        val encoded = preferences(this).getString(key, null) ?: return null
        return runCatching {
            val values = JSONArray(encoded)
            List(values.length()) { index -> values.getString(index) }
        }.getOrNull()
    }

    private fun persistBubbleSchedule(bubbles: List<OverlayBubbleInvitation>) {
        val encoded = JSONArray().apply {
            bubbles.forEach { bubble ->
                put(
                    JSONObject()
                        .put("at", bubble.scheduledAtEpochMillis)
                        .put("copy", bubble.copy),
                )
            }
        }
        preferences(this).edit().putString(KEY_BUBBLE_SCHEDULE, encoded.toString()).apply()
    }

    private fun loadBubbleSchedule(): List<OverlayBubbleInvitation> {
        val encoded = preferences(this).getString(KEY_BUBBLE_SCHEDULE, null)
            ?: return emptyList()
        return runCatching {
            val values = JSONArray(encoded)
            List(values.length()) { index ->
                val value = values.getJSONObject(index)
                OverlayBubbleInvitation(value.getLong("at"), value.getString("copy"))
            }
        }.getOrDefault(emptyList())
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
        private const val EXTRA_USE_FILE_FRAMES = "useFileFrames"
        private const val EXTRA_IDLE_FRAME_PATHS = "idleFramePaths"
        private const val EXTRA_JUMPING_FRAME_PATHS = "jumpingFramePaths"
        private const val EXTRA_BUBBLE_TIMES = "bubbleTimes"
        private const val EXTRA_BUBBLE_COPIES = "bubbleCopies"
        private const val PREFERENCES = "floating_pet"
        private const val KEY_ENABLED = "enabled"
        private const val KEY_PET_NAME = "petName"
        private const val KEY_IDLE_FRAME_PATHS = "idleFramePaths"
        private const val KEY_JUMPING_FRAME_PATHS = "jumpingFramePaths"
        private const val KEY_BUBBLE_SCHEDULE = "bubbleSchedule"
        private const val NOTIFICATION_CHANNEL_ID = "floating_pet_companion"
        private const val NOTIFICATION_ID = 2002
        private const val BUBBLE_DURATION_MILLIS = 8_000L
        private const val MAX_OVERDUE_BUBBLE_AGE_MILLIS = 120_000L
        @Volatile
        private var activeService: OverlayPetService? = null
        private var appInForeground = false

        fun notifyAppInForeground(foreground: Boolean) {
            if (appInForeground == foreground) return
            appInForeground = foreground
            activeService?.applyForegroundState()
        }

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

        internal fun start(
            context: Context,
            petName: String,
            idleFramePaths: List<String>?,
            jumpingFramePaths: List<String>?,
            bubbles: List<OverlayBubbleInvitation>,
            updateFramePaths: Boolean,
        ) {
            val intent = Intent(context, OverlayPetService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_PET_NAME, petName)
                if (updateFramePaths) {
                    val useFileFrames = idleFramePaths != null && jumpingFramePaths != null
                    putExtra(EXTRA_USE_FILE_FRAMES, useFileFrames)
                    if (useFileFrames) {
                        putStringArrayListExtra(EXTRA_IDLE_FRAME_PATHS, ArrayList(idleFramePaths!!))
                        putStringArrayListExtra(
                            EXTRA_JUMPING_FRAME_PATHS,
                            ArrayList(jumpingFramePaths!!),
                        )
                    }
                }
                putExtra(
                    EXTRA_BUBBLE_TIMES,
                    bubbles.map(OverlayBubbleInvitation::scheduledAtEpochMillis).toLongArray(),
                )
                putStringArrayListExtra(
                    EXTRA_BUBBLE_COPIES,
                    ArrayList(bubbles.map(OverlayBubbleInvitation::copy)),
                )
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
    private val frameDecoder = Executors.newSingleThreadExecutor()
    private val paint = Paint().apply {
        isAntiAlias = false
        isFilterBitmap = false
        isDither = false
    }
    private val fallbackIdleFrames = intArrayOf(
        R.drawable.overlay_idle_0,
        R.drawable.overlay_idle_1,
        R.drawable.overlay_idle_2,
        R.drawable.overlay_idle_3,
        R.drawable.overlay_idle_4,
        R.drawable.overlay_idle_5,
    ).map(::decodeFrame)
    private val fallbackCelebrationFrames = intArrayOf(
        R.drawable.overlay_jumping_0,
        R.drawable.overlay_jumping_1,
        R.drawable.overlay_jumping_2,
        R.drawable.overlay_jumping_3,
        R.drawable.overlay_jumping_4,
    ).map(::decodeFrame)
    private var fileIdleFrames: List<Bitmap>? = null
    private var fileCelebrationFrames: List<Bitmap>? = null
    private var requestedIdleFramePaths: List<String>? = null
    private var requestedJumpingFramePaths: List<String>? = null
    private var frameLoadGeneration = 0
    private var idleFrames: List<Bitmap> = fallbackIdleFrames
    private var celebrationFrames: List<Bitmap> = fallbackCelebrationFrames
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
    private val frameWidth = fallbackIdleFrames.first().width
    private val frameHeight = fallbackIdleFrames.first().height
    private val pixelScale = 2

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

    fun reloadFrames(idlePaths: List<String>?, jumpingPaths: List<String>?) {
        if (
            idlePaths == requestedIdleFramePaths &&
            jumpingPaths == requestedJumpingFramePaths
        ) return
        requestedIdleFramePaths = idlePaths
        requestedJumpingFramePaths = jumpingPaths
        val generation = ++frameLoadGeneration
        if (idlePaths == null || jumpingPaths == null) {
            applyDecodedFrames(generation, null, null)
            return
        }
        frameDecoder.execute {
            val loadedIdle = decodeFileFrames(idlePaths)
            val loadedCelebration = decodeFileFrames(jumpingPaths)
            handler.post {
                if (generation != frameLoadGeneration) {
                    loadedIdle?.forEach(Bitmap::recycle)
                    loadedCelebration?.forEach(Bitmap::recycle)
                } else {
                    applyDecodedFrames(generation, loadedIdle, loadedCelebration)
                }
            }
        }
    }

    private fun applyDecodedFrames(
        generation: Int,
        loadedIdle: List<Bitmap>?,
        loadedCelebration: List<Bitmap>?,
    ) {
        if (generation != frameLoadGeneration) return
        val complete = loadedIdle != null && loadedCelebration != null
        if (!complete) {
            loadedIdle?.forEach(Bitmap::recycle)
            loadedCelebration?.forEach(Bitmap::recycle)
        }
        val wasCelebrating =
            frames === celebrationFrames &&
                android.os.SystemClock.uptimeMillis() < celebrationEndsAt
        val oldFileFrames = (fileIdleFrames.orEmpty() + fileCelebrationFrames.orEmpty()).toSet()
        fileIdleFrames = if (complete) loadedIdle else null
        fileCelebrationFrames = if (complete) loadedCelebration else null
        idleFrames = fileIdleFrames ?: fallbackIdleFrames
        celebrationFrames = fileCelebrationFrames ?: fallbackCelebrationFrames
        frames = if (wasCelebrating) celebrationFrames else idleFrames
        frameIndex = 0
        oldFileFrames.forEach(Bitmap::recycle)
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
        frameLoadGeneration++
        frameDecoder.shutdownNow()
        handler.removeCallbacksAndMessages(null)
        (
            fallbackIdleFrames +
                fallbackCelebrationFrames +
                fileIdleFrames.orEmpty() +
                fileCelebrationFrames.orEmpty()
        ).toSet().forEach(Bitmap::recycle)
    }

    private fun scheduleAnimation() {
        handler.removeCallbacks(advanceFrame)
        if (screenOn && isAttachedToWindow) {
            handler.postDelayed(advanceFrame, FRAME_DELAY_MILLIS)
        }
    }

    private fun decodeFrame(resourceId: Int): Bitmap = checkNotNull(
        BitmapFactory.decodeResource(
            resources,
            resourceId,
            BitmapFactory.Options().apply {
                inScaled = false
                inDither = false
            },
        ),
    )

    private fun decodeFileFrames(paths: List<String>?): List<Bitmap>? {
        if (paths.isNullOrEmpty()) return null
        val decoded = mutableListOf<Bitmap>()
        for (path in paths) {
            val bitmap = runCatching {
                BitmapFactory.decodeFile(
                    path,
                    BitmapFactory.Options().apply {
                        inScaled = false
                        inDither = false
                    },
                )
            }.getOrNull()
            if (bitmap == null || bitmap.width != FRAME_WIDTH || bitmap.height != FRAME_HEIGHT) {
                bitmap?.recycle()
                decoded.forEach(Bitmap::recycle)
                return null
            }
            decoded.add(bitmap)
        }
        return decoded
    }

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
        const val FRAME_WIDTH = 192
        const val FRAME_HEIGHT = 208
    }
}
