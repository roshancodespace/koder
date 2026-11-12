package com.companion.companion_app

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothHidDevice
import android.bluetooth.BluetoothHidDeviceAppQosSettings
import android.bluetooth.BluetoothHidDeviceAppSdpSettings
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class BluetoothKeyboardManager(private val context: Context) : MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    private val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
    private var hidDevice: BluetoothHidDevice? = null
    private var connectedDevice: BluetoothDevice? = null
    private var isRegistered: Boolean = false
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()

    // Spoofed Keyboard Identity (Defaults to standard Logitech MX Keys)
    private var spoofDeviceName: String = "Logitech MX Keys"
    private var spoofProvider: String = "Logitech"
    private var spoofDescription: String = "Logitech MX Keys Advanced Wireless Keyboard"

    // 8-byte Standard USB Boot Keyboard Report Descriptor with Output (LEDs) Report
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
        0x95.toByte(), 0x05.toByte(), // Report Count (5 - LEDs)
        0x75.toByte(), 0x01.toByte(), // Report Size (1)
        0x05.toByte(), 0x08.toByte(), // Usage Page (LEDs)
        0x19.toByte(), 0x01.toByte(), // Usage Minimum (1 - Num Lock)
        0x29.toByte(), 0x05.toByte(), // Usage Maximum (5 - Kana)
        0x91.toByte(), 0x02.toByte(), // Output (Data, Variable, Absolute)
        0x95.toByte(), 0x01.toByte(), // Report Count (1 - LED padding)
        0x75.toByte(), 0x03.toByte(), // Report Size (3)
        0x91.toByte(), 0x01.toByte(), // Output (Constant)
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
                    postEvent("CONNECTED", device?.address)
                }

                BluetoothProfile.STATE_CONNECTING -> {
                    postEvent("CONNECTING", device?.address)
                }

                BluetoothProfile.STATE_DISCONNECTING -> {
                    postEvent("DISCONNECTING", device?.address)
                }

                BluetoothProfile.STATE_DISCONNECTED -> {
                    val prevAddress = connectedDevice?.address ?: device?.address
                    if (connectedDevice == device) {
                        connectedDevice = null
                    }
                    postEvent("DISCONNECTED", prevAddress)
                }
            }
        }

        override fun onGetReport(device: BluetoothDevice?, type: Byte, id: Byte, bufferSize: Int) {
            if (device == null) return
            when (type) {
                BluetoothHidDevice.REPORT_TYPE_INPUT -> {
                    // Send 8-byte empty input report (no keys pressed)
                    val emptyReport = byteArrayOf(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
                    hidDevice?.replyReport(device, type, id, emptyReport)
                }

                BluetoothHidDevice.REPORT_TYPE_OUTPUT -> {
                    // Send 1-byte LED status
                    val ledReport = byteArrayOf(0x00)
                    hidDevice?.replyReport(device, type, id, ledReport)
                }

                else -> {
                    hidDevice?.reportError(device, BluetoothHidDevice.ERROR_RSP_UNSUPPORTED_REQ)
                }
            }
        }

        override fun onSetReport(device: BluetoothDevice?, type: Byte, id: Byte, data: ByteArray?) {
            if (device == null) return
            // Host sends output report (e.g. keyboard LEDs) or feature report.
            // Acknowledge with SUCCESS so the host completes handshake and does not time out!
            hidDevice?.reportError(device, BluetoothHidDevice.ERROR_RSP_SUCCESS)
        }

        override fun onSetProtocol(device: BluetoothDevice?, protocol: Byte) {
            if (device == null) return
            // Host sets boot mode or report mode. Acknowledge with SUCCESS!
            hidDevice?.reportError(device, BluetoothHidDevice.ERROR_RSP_SUCCESS)
        }

        override fun onInterruptData(device: BluetoothDevice?, reportId: Byte, data: ByteArray?) {
            // Optional data received on interrupt channel
        }

        override fun onVirtualCableUnplug(device: BluetoothDevice?) {
            val prevAddress = connectedDevice?.address ?: device?.address
            if (connectedDevice == device) {
                connectedDevice = null
            }
            postEvent("DISCONNECTED", prevAddress)
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
            errorMessage = "Bluetooth is currently turned OFF. Please turn on Bluetooth."
        } else {
            try {
                proxySupported =
                    bluetoothAdapter?.getProfileProxy(context, profileListener, BluetoothProfile.HID_DEVICE) ?: false
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
        try {
            bluetoothAdapter?.name = spoofDeviceName
        } catch (_: SecurityException) {
        }

        val sdp = BluetoothHidDeviceAppSdpSettings(
            spoofDeviceName,
            spoofDescription,
            spoofProvider,
            BluetoothHidDevice.SUBCLASS1_KEYBOARD,
            descriptor
        )
        // Pass null for inQos and outQos to use system-optimized default QoS
        return device.registerApp(sdp, null, null, executor, hidCallback)
    }

    fun unregisterSdp(): Boolean {
        val device = hidDevice ?: return false
        return device.unregisterApp()
    }

    fun setDeviceSpoof(deviceName: String, provider: String, description: String): Boolean {
        spoofDeviceName = deviceName
        spoofProvider = provider
        spoofDescription = description

        try {
            bluetoothAdapter?.name = deviceName
        } catch (_: SecurityException) {
        }

        if (hidDevice != null && isRegistered) {
            unregisterSdp()
            return registerSdp()
        }
        return true
    }

    fun makeDiscoverable(durationSeconds: Int = 300): Boolean {
        return try {
            try {
                bluetoothAdapter?.name = spoofDeviceName
            } catch (_: SecurityException) {
            }

            val intent = Intent(BluetoothAdapter.ACTION_REQUEST_DISCOVERABLE).apply {
                putExtra(BluetoothAdapter.EXTRA_DISCOVERABLE_DURATION, durationSeconds)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    fun connect(macAddress: String): Map<String, Any> {
        val adapter = bluetoothAdapter
        if (adapter == null || !adapter.isEnabled) {
            return mapOf("success" to false, "error" to "Bluetooth adapter is turned OFF on this device.")
        }
        val device = hidDevice
        if (device == null) {
            initProxy()
            return mapOf(
                "success" to false,
                "error" to "Bluetooth HID profile proxy is still initializing. Please retry in 2 seconds."
            )
        }
        if (!isRegistered) {
            registerSdp()
        }
        val target = try {
            adapter.getRemoteDevice(macAddress)
        } catch (e: Exception) {
            return mapOf(
                "success" to false,
                "error" to "Invalid Bluetooth MAC address: $macAddress (${e.message})"
            )
        }

        return try {
            val initiated = device.connect(target)
            if (initiated) {
                mapOf("success" to true, "error" to "")
            } else {
                mapOf(
                    "success" to false,
                    "error" to "Workstation rejected connection. Standard Bluetooth keyboards are connected from the PC: tap 'Expose Device' below and select '$spoofDeviceName' in your computer's Bluetooth settings."
                )
            }
        } catch (e: Exception) {
            mapOf("success" to false, "error" to (e.message ?: "Failed to connect to device"))
        }
    }

    fun disconnect(): Boolean {
        val device = hidDevice ?: return false
        val target = connectedDevice ?: return false
        return device.disconnect(target)
    }

    fun getBondedDevices(): List<Map<String, String>> {
        val adapter = bluetoothAdapter ?: return emptyList()
        if (!adapter.isEnabled) {
            return emptyList()
        }
        return try {
            adapter.bondedDevices?.map { device ->
                mapOf(
                    "name" to (device.name ?: "Unknown Device"),
                    "address" to device.address
                )
            } ?: emptyList()
        } catch (e: SecurityException) {
            emptyList()
        }
    }

    fun openBluetoothSettings(): Boolean {
        return try {
            val intent = Intent(android.provider.Settings.ACTION_BLUETOOTH_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    fun sendKeyPress(modifier: Byte, keyCode: Byte): Boolean {
        val device = hidDevice ?: return false
        val target = connectedDevice ?: return false

        // 8-byte report: [modifier, 0x00, keyCode, 0x00, 0x00, 0x00, 0x00, 0x00]
        val keyReport = byteArrayOf(modifier, 0x00, keyCode, 0x00, 0x00, 0x00, 0x00, 0x00)
        val sent = device.sendReport(target, 0, keyReport)

        // Give the OS 25ms to register the keydown event before sending keyup
        executor.execute {
            try {
                Thread.sleep(25)
            } catch (_: InterruptedException) {
            }
            val releaseReport = byteArrayOf(0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
            device.sendReport(target, 0, releaseReport)
        }

        return sent
    }

    private fun postEvent(status: String, address: String? = null) {
        mainHandler.post {
            val payload = mutableMapOf<String, Any>("status" to status)
            if (address != null) {
                payload["address"] = address
            }
            eventSink?.success(payload)
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
                    val connResult = connect(mac)
                    if (connResult["success"] == true) {
                        result.success(true)
                    } else {
                        result.error("CONNECT_FAILED", connResult["error"] as String, null)
                    }
                }
            }

            "setDeviceSpoof" -> {
                val name = call.argument<String>("deviceName") ?: "Logitech MX Keys"
                val provider = call.argument<String>("provider") ?: "Logitech"
                val desc = call.argument<String>("description") ?: "Wireless Keyboard"
                result.success(setDeviceSpoof(name, provider, desc))
            }

            "makeDiscoverable" -> {
                val duration = call.argument<Int>("duration") ?: 300
                result.success(makeDiscoverable(duration))
            }

            "getSpoofProfile" -> {
                result.success(
                    mapOf(
                        "deviceName" to spoofDeviceName,
                        "provider" to spoofProvider,
                        "description" to spoofDescription
                    )
                )
            }

            "disconnect" -> {
                result.success(disconnect())
            }

            "getBondedDevices" -> {
                result.success(getBondedDevices())
            }

            "openBluetoothSettings" -> {
                result.success(openBluetoothSettings())
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
            postEvent("CONNECTED", connectedDevice?.address)
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
