package com.relaygazette.relay_gazette

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Bridges to a NIP-55 Android signer app (e.g. Amber) via Intents, per
 * https://github.com/nostr-protocol/nips/blob/master/55.md. This app never
 * sees a private key: the signer app owns it, and only ever hands back a
 * public key or a signature over something we already showed the user.
 *
 * Not exercised against a real signer app in the environment this was
 * written in (no Android SDK / device available there) — see TASKS.md.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.relaygazette.relay_gazette/amber"
    private var nextRequestCode = 9100
    private val pendingResults = mutableMapOf<Int, Result>()

    // NIP-55: once get_public_key returns a signer package name, later
    // requests should target that package directly rather than showing an
    // app chooser again.
    private var signerPackage: String? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAppInstalled" -> result.success(isSignerInstalled())
                "getPublicKey" -> {
                    val permissions = call.argument<String>("permissions") ?: ""
                    launchSigner(
                        payload = "",
                        extras = mapOf("type" to "get_public_key", "permissions" to permissions),
                        targetSavedPackage = false,
                        result = result
                    )
                }
                "signEvent" -> {
                    val eventJson = call.argument<String>("eventJson") ?: ""
                    val currentUser = call.argument<String>("currentUser") ?: ""
                    val requestId = call.argument<String>("id") ?: ""
                    launchSigner(
                        payload = eventJson,
                        extras = mapOf(
                            "type" to "sign_event",
                            "current_user" to currentUser,
                            "id" to requestId
                        ),
                        targetSavedPackage = true,
                        result = result
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isSignerInstalled(): Boolean {
        val probe = Intent(Intent.ACTION_VIEW, Uri.parse("nostrsigner:"))
        return probe.resolveActivity(packageManager) != null
    }

    private fun launchSigner(
        payload: String,
        extras: Map<String, String>,
        targetSavedPackage: Boolean,
        result: Result
    ) {
        if (!isSignerInstalled()) {
            result.error("NOT_INSTALLED", "No NIP-55 signer app is installed", null)
            return
        }

        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("nostrsigner:$payload"))
        for ((key, value) in extras) {
            intent.putExtra(key, value)
        }
        if (targetSavedPackage && signerPackage != null) {
            intent.setPackage(signerPackage)
        }

        val requestCode = nextRequestCode++
        pendingResults[requestCode] = result
        try {
            startActivityForResult(intent, requestCode)
        } catch (e: Exception) {
            pendingResults.remove(requestCode)
            result.error("LAUNCH_FAILED", e.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val pending = pendingResults.remove(requestCode) ?: return

        if (resultCode != Activity.RESULT_OK || data == null) {
            pending.success(null) // user backed out / no signer responded
            return
        }
        if (data.getBooleanExtra("rejected", false)) {
            pending.success(null) // user explicitly declined in the signer app
            return
        }

        val packageName = data.getStringExtra("package")
        if (packageName != null) {
            signerPackage = packageName
        }

        pending.success(
            mapOf(
                "result" to data.getStringExtra("result"),
                "event" to data.getStringExtra("event"),
                "package" to packageName
            )
        )
    }
}
