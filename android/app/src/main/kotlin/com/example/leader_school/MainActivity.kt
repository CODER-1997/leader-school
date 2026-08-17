package com.example.leader_school

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {

    private val CHANNEL = "sms_service"
    private val SMS_PERMISSION_CODE = 100

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                .setMethodCallHandler { call, result ->

                    if (call.method == "sendSMS") {
                        val recipient = call.argument<String>("recipient")
                        val message = call.argument<String>("message")

                        if (recipient.isNullOrEmpty() || message.isNullOrEmpty()) {
                            result.error("INVALID_ARGUMENTS", "Ma'lumotlar yetarli emas", null)
                            return@setMethodCallHandler
                        }

                        if (ActivityCompat.checkSelfPermission(
                                        this,
                                        Manifest.permission.SEND_SMS
                                ) != PackageManager.PERMISSION_GRANTED
                        ) {
                            ActivityCompat.requestPermissions(
                                    this,
                                    arrayOf(Manifest.permission.SEND_SMS),
                                    SMS_PERMISSION_CODE
                            )
                            result.error(
                                    "PERMISSION_DENIED",
                                    "SMS ruxsat berilmagan. Iltimos ruxsat bering.",
                                    null
                            )
                            return@setMethodCallHandler
                        }

                        val status = sendSMS(recipient, message)

                        if (status == "SUCCESS") {
                            result.success("SMS yuborildi")
                        } else {
                            result.error("SEND_FAILED", status, null)
                        }

                    } else {
                        result.notImplemented()
                    }
                }
    }

    private fun sendSMS(recipient: String, message: String): String {
        return try {

            val smsManager: SmsManager =
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        this.getSystemService(SmsManager::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        SmsManager.getDefault()
                    }

            // SMS ni avtomatik qismlarga bo'lish
            val parts: ArrayList<String> = smsManager.divideMessage(message)

            // Har qanday uzunlikdagi SMS ni yuboradi
            smsManager.sendMultipartTextMessage(
                    recipient,
                    null,
                    parts,
                    null,
                    null
            )

            "SUCCESS"

        } catch (e: Exception) {
            e.printStackTrace()
            e.message ?: "Noma'lum xatolik"
        }
    }
}
