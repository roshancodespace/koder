package com.companion.companion_app

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothHidDevice
import android.bluetooth.BluetoothHidDeviceAppQosSettings
import android.bluetooth.BluetoothHidDeviceAppSdpSettings
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class BluetoothKeyboardManager(private val context: Context) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
    private var hidDevice: BluetoothHidDevice? = null
    private var connectedDevice: BluetoothDevice? = null
    private var isRegistered: Boolean = false
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()

    // 8-byte Standard USB Boot Keyboard Report Descriptor
    private val descriptor = byteArrayOf(
        0x05.toByte(), 0x01.toByte(), // Usage Page (Generic Desktop)
        0x09.toByte(), 0x06.toByte(), // Usage (Keyboard)
        0xA1.toByte(), 0x01.toByte(), // Collection (Application)
        0x05.toByte(), 0x07.toByte(), // Usage Page (Key Codes)
        0x19.toByte(), 0xE0.toByte(), // Usage Minimum (224 - Left Control)
        0x29.toByte(), 0xE7.toByte(), // Usage Maximum (231 - Right GUI)
        0x15.toByte(), 0x00.toByte(), // Logical Minimum (0)
        0x25.toByte(), 0x01.toByte(), // Logical Maximum (1)
        0x75.toByte(), 0x01.toByte(), // Report Size (1)
        0x95.toByte(), 0x08.toByte(), // Report Count (8 - modifier bits)
        0x81.toByte(), 0x02.toByte(), // Input (Data, Variable, Absolute)
        0x95.toByte(), 0x01.toByte(), // Report Count (1 - reserved byte)
        0x75.toByte(), 0x08.toByte(), // Report Size (8)
        0x81.toByte(), 0x01.toByte(), // Input (Constant)
        0x95.toByte(), 0x06.toByte(), // Report Count (6 keycodes)
        0x75.toByte(), 0x08.toByte(), // Report Size (8)
        0x15.toByte(), 0x00.toByte(), // Logical Minimum (0)
        0x25.toByte(), 0x65.toByte(), // Logical Maximum (101)
        0x05.toByte(), 0x07.toByte(), // Usage Page (Key Codes)
        0x19.toByte(), 0x00.toByte(), // Usage Minimum (0)
        0x29.toByte(), 0x65.toByte(), // Usage Maximum (101)
        0x81.toByte(), 0x00.toByte(), // Input (Data, Array)
        0xC0.toByte()                 // End Collection
    )

    private val profileListener = object : BluetoothProfile.ServiceListener {
        override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
            if (profile == BluetoothProfile.HID_DEVICE) {
                hidDevice = proxy as BluetoothHidDevice
                registerSdp()
            }
        }

        override fun onServiceDisconnected(profile: Int) {
            if (profile == BluetoothProfile.HID_DEVICE) {
                hidDevice = null
                isRegistered = false
                postEvent("DISCONNECTED")
            }
        }
    }

    private val hidCallback = object : BluetoothHidDevice.Callback() {
        override fun onAppStatusChanged(pluggedDevice: BluetoothDevice?, registered: Boolean) {
            isRegistered = registered
            if (registered) {
                postEvent("REGISTERED")
            } else {
                postEvent("UNREGISTERED")
            }
        }

        override fun onConnectionStateChanged(device: BluetoothDevice?, state: Int) {
            when (state) {
                BluetoothProfile.STATE_CONNECTED -> {
                    connectedDevice = device
                    postEvent("CONNECTED")
                }
                BluetoothProfile.STATE_CONNECTING -> {
                    postEvent("CONNECTING")
                }
                BluetoothProfile.STATE_DISCONNECTING -> {
                    postEvent("DISCONNECTING")
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    if (connectedDevice == device) {
                        connectedDevice = null
                    }
                    postEvent("DISCONNECTED")
                }
            }
        }
    }

    init {
        initProxy()
    }

    private fun initProxy(): Boolean {
        if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled) {
            return false
        }
        return try {
            bluetoothAdapter.getProfileProxy(context, profileListener, BluetoothProfile.HID_DEVICE)
        } catch (e: Exception) {
            false
        }
    }

    fun checkCapability(): Map<String, Any> {
        val adapterPresent = bluetoothAdapter != null
        val adapterEnabled = bluetoothAdapter?.isEnabled == true
        var proxySupported = false
        var errorMessage: String? = null

        if (!adapterPresent) {
            errorMessage = "No Bluetooth adapter available on this device"
        } else if (!adapterEnabled) {
            errorMessage = "Bluetooth adapter is disabled"
        } else {
            try {
                proxySupported = bluetoothAdapter?.getProfileProxy(context, profileListener, BluetoothProfile.HID_DEVICE) ?: false
                if (!proxySupported) {
                    errorMessage = "OEM HAL has disabled Bluetooth HID Device profile"
                }
            } catch (e: Exception) {
                proxySupported = false
                errorMessage = e.message ?: "Failed to acquire HID Device profile proxy"
            }
        }

        return mapOf(
            "isSupported" to (adapterPresent && proxySupported),
            "isEnabled" to adapterEnabled,
            "hasProfileProxy" to (hidDevice != null),
            "errorMessage" to (errorMessage ?: "")
        )
    }

    fun registerSdp(): Boolean {
        val device = hidDevice ?: return false
        val sdp = BluetoothHidDeviceAppSdpSettings(
            "VS Code Companion",
            "Android Companion HID Keyboard",
            "Companion",
            0x40.toByte(), // Subclass: Keyboard
            descriptor
        )
        val qos = BluetoothHidDeviceAppQosSettings(
            BluetoothHidDeviceAppQosSettings.SERVICE_BEST_EFFORT,
            800,
            9,
            0,
            11250,
            BluetoothHidDeviceAppQosSettings.MAX
        )
        return device.registerApp(sdp, qos, null, executor, hidCallback)
    }

    fun unregisterSdp(): Boolean {
        val device = hidDevice ?: return false
        return device.unregisterApp()
    }

    fun connect(macAddress: String): Boolean {
        val device = hidDevice ?: return false
        val target = bluetoothAdapter?.getRemoteDevice(macAddress) ?: return false
        return device.connect(target)
    }

    fun disconnect(): Boolean {
        val device = hidDevice ?: return false
        val target = connectedDevice ?: return false
        return device.disconnect(target)
    }

    fun sendKeyPress(modifier: Byte, keyCode: Byte): Boolean {
        val device = hidDevice ?: return false
        val target = connectedDevice ?: return false

        // 8-byte report: [modifier, 0x00, keyCode, 0x00, 0x00, 0x00, 0x00, 0x00]
        val keyReport = byteArrayOf(modifier, 0x00, keyCode, 0x00, 0x00, 0x00, 0x00, 0x00)
        val sent = device.sendReport(target, 0, keyReport)

        // Immediate all-zero release report to eliminate stuck keys
        val releaseReport = byteArrayOf(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
        device.sendReport(target, 0, releaseReport)

        return sent
    }

    private fun postEvent(status: String) {
        mainHandler.post {
            eventSink?.success(mapOf("status" to status))
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkCapability" -> {
                result.success(checkCapability())
            }
            "registerApp" -> {
                result.success(registerSdp())
            }
            "unregisterApp" -> {
                result.success(unregisterSdp())
            }
            "connect" -> {
                val mac = call.argument<String>("macAddress")
                if (mac.isNullOrEmpty()) {
                    result.error("INVALID_ARGUMENT", "macAddress is required", null)
                } else {
                    result.success(connect(mac))
                }
            }
            "disconnect" -> {
                result.success(disconnect())
            }
            "sendKeyPress" -> {
                val modifier = (call.argument<Int>("modifier") ?: 0).toByte()
                val keyCode = (call.argument<Int>("keyCode") ?: 0).toByte()
                result.success(sendKeyPress(modifier, keyCode))
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
        if (connectedDevice != null) {
            postEvent("CONNECTED")
        } else if (isRegistered) {
            postEvent("REGISTERED")
        } else {
            postEvent("DISCONNECTED")
        }
    }

    override fun onCancel(arguments: Any?) {
        this.eventSink = null
    }

    fun cleanup() {
        if (hidDevice != null && bluetoothAdapter != null) {
            bluetoothAdapter.closeProfileProxy(BluetoothProfile.HID_DEVICE, hidDevice)
            hidDevice = null
        }
    }
}
