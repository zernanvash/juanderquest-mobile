package dev.zernanvash.juanderquest

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.math.sqrt

/**
 * Streams the phone's orientation for Compass AR (Plan 47, Tier C).
 *
 * Uses the OS-fused rotation sensors instead of raw accelerometer/magnetometer:
 *  - TYPE_GAME_ROTATION_VECTOR: gyro + accelerometer, smooth, no magnetic jumps,
 *    but its yaw is arbitrary.
 *  - TYPE_ROTATION_VECTOR: adds the magnetometer, so yaw is relative to north.
 * Dart combines them (game rotation for smoothness, a slowly corrected yaw offset
 * from the rotation vector). Phones without a gyroscope fall back to
 * accelerometer + magnetometer ("accelMag").
 *
 * Every event is a map: {src, q:[x,y,z,w], acc (heading accuracy in degrees, or -1), t (ms)}.
 * Accuracy changes of the magnetic sensor arrive as {src:"status", mag:<0..3>}.
 */
class ArSensorBridge(private val context: Context, messenger: BinaryMessenger) :
    EventChannel.StreamHandler, SensorEventListener {

    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null

    private val gameSensor: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_GAME_ROTATION_VECTOR)
    private val rotationSensor: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
    private val accelSensor: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private val magSensor: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)

    private val gravity = FloatArray(3)
    private val geomagnetic = FloatArray(3)
    private var hasGravity = false
    private var hasGeomagnetic = false
    private val matrix = FloatArray(9)

    init {
        EventChannel(messenger, "com.juanderquest.app/ar_pose").setStreamHandler(this)
        MethodChannel(messenger, "com.juanderquest.app/ar_device").setMethodCallHandler { call, result ->
            when (call.method) {
                "capabilities" -> result.success(
                    mapOf(
                        "gameRotation" to (gameSensor != null),
                        "rotation" to (rotationSensor != null),
                        "accelMag" to (accelSensor != null && magSensor != null),
                    )
                )
                "cameraIntrinsics" -> result.success(backCameraIntrinsics())
                else -> result.notImplemented()
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        val delay = SensorManager.SENSOR_DELAY_GAME
        if (gameSensor != null || rotationSensor != null) {
            gameSensor?.let { sensorManager.registerListener(this, it, delay) }
            rotationSensor?.let { sensorManager.registerListener(this, it, delay) }
        } else {
            accelSensor?.let { sensorManager.registerListener(this, it, delay) }
            magSensor?.let { sensorManager.registerListener(this, it, delay) }
        }
    }

    override fun onCancel(arguments: Any?) {
        sensorManager.unregisterListener(this)
        sink = null
        hasGravity = false
        hasGeomagnetic = false
    }

    override fun onSensorChanged(event: SensorEvent) {
        val t = event.timestamp / 1_000_000.0
        when (event.sensor.type) {
            Sensor.TYPE_GAME_ROTATION_VECTOR -> emit("game", quaternionFromVector(event.values), -1.0, t)
            Sensor.TYPE_ROTATION_VECTOR -> {
                // values[4] is the estimated heading accuracy in radians (-1 when unknown).
                val acc = if (event.values.size > 4 && event.values[4] >= 0f) {
                    Math.toDegrees(event.values[4].toDouble())
                } else -1.0
                emit("rot", quaternionFromVector(event.values), acc, t)
            }
            Sensor.TYPE_ACCELEROMETER -> {
                System.arraycopy(event.values, 0, gravity, 0, 3)
                hasGravity = true
                emitAccelMag(t)
            }
            Sensor.TYPE_MAGNETIC_FIELD -> {
                System.arraycopy(event.values, 0, geomagnetic, 0, 3)
                hasGeomagnetic = true
                emitAccelMag(t)
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {
        if (sensor.type == Sensor.TYPE_ROTATION_VECTOR || sensor.type == Sensor.TYPE_MAGNETIC_FIELD) {
            post(mapOf("src" to "status", "mag" to accuracy))
        }
    }

    private fun emitAccelMag(t: Double) {
        if (!hasGravity || !hasGeomagnetic) return
        if (!SensorManager.getRotationMatrix(matrix, null, gravity, geomagnetic)) return
        emit("accelMag", quaternionFromMatrix(matrix), -1.0, t)
    }

    private fun emit(src: String, q: DoubleArray, acc: Double, t: Double) {
        post(mapOf("src" to src, "q" to q.toList(), "acc" to acc, "t" to t))
    }

    private fun post(payload: Map<String, Any>) {
        val target = sink ?: return
        if (Looper.myLooper() == Looper.getMainLooper()) target.success(payload)
        else mainHandler.post { sink?.success(payload) }
    }

    /** Rotation-vector sensor values -> unit quaternion [x, y, z, w] (device -> world). */
    private fun quaternionFromVector(values: FloatArray): DoubleArray {
        val x = values[0].toDouble()
        val y = values[1].toDouble()
        val z = values[2].toDouble()
        val w = if (values.size > 3) values[3].toDouble()
        else sqrt((1.0 - x * x - y * y - z * z).coerceAtLeast(0.0))
        return normalize(doubleArrayOf(x, y, z, w))
    }

    /** Row-major 3x3 rotation matrix (device -> world) -> quaternion [x, y, z, w]. */
    private fun quaternionFromMatrix(m: FloatArray): DoubleArray {
        val m00 = m[0].toDouble(); val m01 = m[1].toDouble(); val m02 = m[2].toDouble()
        val m10 = m[3].toDouble(); val m11 = m[4].toDouble(); val m12 = m[5].toDouble()
        val m20 = m[6].toDouble(); val m21 = m[7].toDouble(); val m22 = m[8].toDouble()
        val trace = m00 + m11 + m22
        val q = if (trace > 0) {
            val s = sqrt(trace + 1.0) * 2
            doubleArrayOf((m21 - m12) / s, (m02 - m20) / s, (m10 - m01) / s, 0.25 * s)
        } else if (m00 > m11 && m00 > m22) {
            val s = sqrt(1.0 + m00 - m11 - m22) * 2
            doubleArrayOf(0.25 * s, (m01 + m10) / s, (m02 + m20) / s, (m21 - m12) / s)
        } else if (m11 > m22) {
            val s = sqrt(1.0 + m11 - m00 - m22) * 2
            doubleArrayOf((m01 + m10) / s, 0.25 * s, (m12 + m21) / s, (m02 - m20) / s)
        } else {
            val s = sqrt(1.0 + m22 - m00 - m11) * 2
            doubleArrayOf((m02 + m20) / s, (m12 + m21) / s, 0.25 * s, (m10 - m01) / s)
        }
        return normalize(q)
    }

    private fun normalize(q: DoubleArray): DoubleArray {
        val n = sqrt(q[0] * q[0] + q[1] * q[1] + q[2] * q[2] + q[3] * q[3])
        return if (n < 1e-9) doubleArrayOf(0.0, 0.0, 0.0, 1.0) else doubleArrayOf(q[0] / n, q[1] / n, q[2] / n, q[3] / n)
    }

    /** Physical optics of the main back camera, so Dart can compute the real field of view. */
    private fun backCameraIntrinsics(): Map<String, Any>? {
        return try {
            val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val id = manager.cameraIdList.firstOrNull { cameraId ->
                manager.getCameraCharacteristics(cameraId)
                    .get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK
            } ?: return null
            val c = manager.getCameraCharacteristics(id)
            val focal = c.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)?.firstOrNull() ?: return null
            val physical = c.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE) ?: return null
            val pixels = c.get(CameraCharacteristics.SENSOR_INFO_PIXEL_ARRAY_SIZE)
            val active = c.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE)
            // The active array can be smaller than the full pixel array; scale the physical size to it.
            val activeWidthMm = if (pixels != null && active != null && pixels.width > 0) {
                physical.width * active.width() / pixels.width
            } else physical.width
            val activeHeightMm = if (pixels != null && active != null && pixels.height > 0) {
                physical.height * active.height() / pixels.height
            } else physical.height
            mapOf(
                "focalLengthMm" to focal.toDouble(),
                "sensorWidthMm" to activeWidthMm.toDouble(),
                "sensorHeightMm" to activeHeightMm.toDouble(),
                "sensorOrientation" to (c.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90),
            )
        } catch (e: Exception) {
            null
        }
    }
}
