package com.davidshi.pettodo

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var permissionSettingsOpened = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            OVERLAY_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // TYPE_APPLICATION_OVERLAY exists from API 26; older devices
                // have no supported overlay window type for this feature.
                "isSupported" -> result.success(
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.O,
                )
                "hasPermission" -> result.success(Settings.canDrawOverlays(this))
                "isEnabled" -> {
                    val enabled = OverlayPetService.isEnabled(this)
                    result.success(enabled)
                }
                "requestPermission" -> requestOverlayPermission(result)
                "enable" -> {
                    if (!Settings.canDrawOverlays(this)) {
                        result.error("permission_denied", "Overlay permission is not granted.", null)
                        return@setMethodCallHandler
                    }
                    val petName = call.argument<String>("petName")?.trim()
                        ?.takeIf(String::isNotEmpty) ?: "Choco"
                    val frameFiles = call.argument<Map<*, *>>("frameFiles")
                    val frameFilesChanged =
                        call.argument<Boolean>("frameFilesChanged") ?: true
                    val idlePaths = stringList(frameFiles?.get("idle"))
                    val jumpingPaths = stringList(frameFiles?.get("jumping"))
                    val completeFramePaths = idlePaths?.takeIf { it.isNotEmpty() }
                        ?.let { idle ->
                            jumpingPaths?.takeIf { it.isNotEmpty() }
                                ?.let { jumping -> idle to jumping }
                        }
                    val bubbles = (call.argument<List<*>>("bubbles") ?: emptyList<Any>())
                        .mapNotNull(::bubbleInvitation)
                    OverlayPetService.start(
                        this,
                        petName,
                        completeFramePaths?.first,
                        completeFramePaths?.second,
                        bubbles,
                        frameFilesChanged,
                    )
                    result.success(null)
                }
                "disable" -> {
                    OverlayPetService.stop(this)
                    result.success(null)
                }
                "celebrate" -> {
                    OverlayPetService.celebrate(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestOverlayPermission(result: MethodChannel.Result) {
        if (Settings.canDrawOverlays(this)) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.error("permission_in_progress", "Overlay permission is already open.", null)
            return
        }
        pendingPermissionResult = result
        permissionSettingsOpened = true
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:$packageName"),
        )
        try {
            startActivity(intent)
        } catch (_: Exception) {
            permissionSettingsOpened = false
            pendingPermissionResult = null
            result.success(false)
        }
    }

    override fun onPostResume() {
        super.onPostResume()
        if (!permissionSettingsOpened) return
        permissionSettingsOpened = false
        pendingPermissionResult?.success(Settings.canDrawOverlays(this))
        pendingPermissionResult = null
    }

    override fun onDestroy() {
        pendingPermissionResult?.success(false)
        pendingPermissionResult = null
        super.onDestroy()
    }

    private fun stringList(value: Any?): List<String>? = (value as? List<*>)
        ?.mapNotNull { (it as? String)?.trim()?.takeIf(String::isNotEmpty) }

    private fun bubbleInvitation(value: Any?): OverlayBubbleInvitation? {
        val map = value as? Map<*, *> ?: return null
        val scheduledAt = (map["scheduledAtEpochMillis"] as? Number)?.toLong()
            ?: return null
        val copy = (map["copy"] as? String)?.trim()?.takeIf(String::isNotEmpty)
            ?: return null
        return OverlayBubbleInvitation(scheduledAt, copy)
    }

    private companion object {
        const val OVERLAY_CHANNEL = "com.davidshi.pettodo/overlay"
    }
}
