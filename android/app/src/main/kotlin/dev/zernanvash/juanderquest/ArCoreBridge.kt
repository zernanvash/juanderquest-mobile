package dev.zernanvash.juanderquest

import android.app.Activity
import android.app.Application
import android.content.Context
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Surface
import android.view.View
import android.view.WindowManager
import com.google.ar.core.Anchor
import com.google.ar.core.ArCoreApk
import com.google.ar.core.Config
import com.google.ar.core.Coordinates2d
import com.google.ar.core.Frame
import com.google.ar.core.Plane
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import com.google.ar.core.exceptions.CameraNotAvailableException
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

/**
 * World AR (Plan 47, Tier W).
 *
 * ARCore tracks the phone; this view only draws the camera image. Every frame
 * the camera's view/projection matrices, plane count and the placed anchor are
 * streamed to Dart, which draws the AR object with the same Flutter overlay as
 * Compass AR. Keeping the renderer in Dart means one object look and one
 * gameplay for both tiers.
 */
class ArCoreBridge(private val activity: Activity, messenger: BinaryMessenger) {
    init {
        MethodChannel(messenger, "com.juanderquest.app/arcore").setMethodCallHandler { call, result ->
            when (call.method) {
                "availability" -> result.success(availability())
                "requestInstall" -> try {
                    val status = ArCoreApk.getInstance().requestInstall(activity, true)
                    result.success(if (status == ArCoreApk.InstallStatus.INSTALLED) "installed" else "requested")
                } catch (e: Exception) {
                    result.success("failed")
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun availability(): String = try {
        when (val a = ArCoreApk.getInstance().checkAvailability(activity)) {
            ArCoreApk.Availability.SUPPORTED_INSTALLED -> "installed"
            ArCoreApk.Availability.SUPPORTED_APK_TOO_OLD,
            ArCoreApk.Availability.SUPPORTED_NOT_INSTALLED -> "installable"
            else -> if (a.isTransient) "checking" else "unsupported"
        }
    } catch (e: Exception) {
        "unsupported"
    }
}

class ArCoreViewFactory(
    private val activity: Activity,
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        ArCoreView(activity, messenger, viewId)
}

private class ArCoreView(
    private val activity: Activity,
    messenger: BinaryMessenger,
    viewId: Int,
) : PlatformView, GLSurfaceView.Renderer, EventChannel.StreamHandler,
    Application.ActivityLifecycleCallbacks {

    private val main = Handler(Looper.getMainLooper())
    private val surface = GLSurfaceView(activity)
    private val methods = MethodChannel(messenger, "com.juanderquest.app/arcore_view_$viewId")
    private val events = EventChannel(messenger, "com.juanderquest.app/arcore_frames_$viewId")
    private var sink: EventChannel.EventSink? = null

    private var session: Session? = null
    private var anchor: Anchor? = null
    @Volatile private var placeRequest: MethodChannel.Result? = null
    @Volatile private var clearRequested = false
    private var viewportWidth = 1
    private var viewportHeight = 1
    private var viewportChanged = true
    private val background = CameraBackground()
    private val view = FloatArray(16)
    private val proj = FloatArray(16)
    private val anchorMatrix = FloatArray(16)

    init {
        surface.preserveEGLContextOnPause = true
        surface.setEGLContextClientVersion(2)
        surface.setEGLConfigChooser(8, 8, 8, 8, 16, 0)
        surface.setRenderer(this)
        surface.renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
        events.setStreamHandler(this)
        methods.setMethodCallHandler { call, result ->
            when (call.method) {
                // Hit-test just below the centre of the screen (the ground a few
                // steps ahead) on the next frame; replies true when anchored.
                "placeAnchor" -> {
                    placeRequest?.success(false)
                    placeRequest = result
                }
                "clearAnchor" -> {
                    clearRequested = true
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        activity.application.registerActivityLifecycleCallbacks(this)
        openSession()
    }

    private fun openSession() {
        try {
            val s = Session(activity)
            val config = Config(s).apply {
                planeFindingMode = Config.PlaneFindingMode.HORIZONTAL
                updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
                focusMode = Config.FocusMode.AUTO
                lightEstimationMode = Config.LightEstimationMode.DISABLED
            }
            s.configure(config)
            s.resume()
            session = s
            surface.onResume()
        } catch (e: Exception) {
            emitError(e.javaClass.simpleName)
        }
    }

    override fun getView(): View = surface

    override fun dispose() {
        activity.application.unregisterActivityLifecycleCallbacks(this)
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        placeRequest?.success(false)
        placeRequest = null
        surface.onPause()
        anchor?.detach()
        anchor = null
        session?.close()
        session = null
    }

    // Activity lifecycle: ARCore must pause with the activity.
    override fun onActivityPaused(a: Activity) {
        if (a !== activity) return
        surface.onPause()
        session?.pause()
    }

    override fun onActivityResumed(a: Activity) {
        if (a !== activity) return
        try {
            session?.resume()
            surface.onResume()
        } catch (e: CameraNotAvailableException) {
            emitError("CameraNotAvailable")
        }
    }

    override fun onActivityCreated(a: Activity, b: Bundle?) {}
    override fun onActivityStarted(a: Activity) {}
    override fun onActivityStopped(a: Activity) {}
    override fun onActivitySaveInstanceState(a: Activity, b: Bundle) {}
    override fun onActivityDestroyed(a: Activity) {}

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    // --- GL thread -----------------------------------------------------------

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        background.create()
        session?.setCameraTextureName(background.textureId)
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        GLES20.glViewport(0, 0, width, height)
        viewportWidth = width
        viewportHeight = height
        viewportChanged = true
    }

    override fun onDrawFrame(gl: GL10?) {
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
        val s = session ?: return
        if (viewportChanged) {
            s.setDisplayGeometry(displayRotation(), viewportWidth, viewportHeight)
            viewportChanged = false
        }
        s.setCameraTextureName(background.textureId)
        val frame: Frame = try {
            s.update()
        } catch (e: Exception) {
            return
        }
        background.draw(frame)

        if (clearRequested) {
            anchor?.detach()
            anchor = null
            clearRequested = false
        }

        val camera = frame.camera
        val tracking = camera.trackingState == TrackingState.TRACKING
        placeRequest?.let { request ->
            placeRequest = null
            val placed = tracking && tryPlace(frame)
            main.post { request.success(placed) }
        }

        val planes = s.getAllTrackables(Plane::class.java).count {
            it.trackingState == TrackingState.TRACKING && it.subsumedBy == null
        }
        val payload = HashMap<String, Any?>()
        payload["state"] = camera.trackingState.name.lowercase()
        payload["reason"] = camera.trackingFailureReason.name.lowercase()
        payload["planes"] = planes
        payload["width"] = viewportWidth
        payload["height"] = viewportHeight
        if (tracking) {
            camera.getViewMatrix(view, 0)
            camera.getProjectionMatrix(proj, 0, 0.05f, 100f)
            payload["view"] = view.map { it.toDouble() }
            payload["proj"] = proj.map { it.toDouble() }
        }
        val a = anchor
        if (a != null && a.trackingState == TrackingState.TRACKING) {
            a.pose.toMatrix(anchorMatrix, 0)
            payload["anchor"] = anchorMatrix.map { it.toDouble() }
        }
        main.post { sink?.success(payload) }
    }

    private fun tryPlace(frame: Frame): Boolean {
        val x = viewportWidth / 2f
        val y = viewportHeight * 0.62f
        for (hit in frame.hitTest(x, y)) {
            val trackable = hit.trackable
            if (trackable is Plane &&
                trackable.type == Plane.Type.HORIZONTAL_UPWARD_FACING &&
                trackable.isPoseInPolygon(hit.hitPose) &&
                hit.distance in 0.8f..6.0f
            ) {
                anchor?.detach()
                anchor = hit.createAnchor()
                return true
            }
        }
        return false
    }

    @Suppress("DEPRECATION")
    private fun displayRotation(): Int {
        val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) activity.display
        else (activity.getSystemService(Context.WINDOW_SERVICE) as WindowManager).defaultDisplay
        return display?.rotation ?: Surface.ROTATION_0
    }

    private fun emitError(code: String) {
        main.post { sink?.success(mapOf("error" to code)) }
    }

    /** Draws ARCore's camera image (external OES texture) as a full-screen quad. */
    private class CameraBackground {
        var textureId = -1
            private set
        private var program = 0
        private var positionAttrib = 0
        private var texCoordAttrib = 0
        private val quad: FloatBuffer = floatBuffer(floatArrayOf(-1f, -1f, +1f, -1f, -1f, +1f, +1f, +1f))
        private val texCoords: FloatBuffer = floatBuffer(FloatArray(8))

        fun create() {
            val textures = IntArray(1)
            GLES20.glGenTextures(1, textures, 0)
            textureId = textures[0]
            val target = GLES11Ext.GL_TEXTURE_EXTERNAL_OES
            GLES20.glBindTexture(target, textureId)
            GLES20.glTexParameteri(target, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glTexParameteri(target, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glTexParameteri(target, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(target, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
            program = link(
                """
                attribute vec4 a_Position;
                attribute vec2 a_TexCoord;
                varying vec2 v_TexCoord;
                void main() { gl_Position = a_Position; v_TexCoord = a_TexCoord; }
                """.trimIndent(),
                """
                #extension GL_OES_EGL_image_external : require
                precision mediump float;
                varying vec2 v_TexCoord;
                uniform samplerExternalOES u_Texture;
                void main() { gl_FragColor = texture2D(u_Texture, v_TexCoord); }
                """.trimIndent(),
            )
            positionAttrib = GLES20.glGetAttribLocation(program, "a_Position")
            texCoordAttrib = GLES20.glGetAttribLocation(program, "a_TexCoord")
        }

        fun draw(frame: Frame) {
            if (frame.hasDisplayGeometryChanged()) {
                quad.position(0)
                texCoords.position(0)
                frame.transformCoordinates2d(
                    Coordinates2d.OPENGL_NORMALIZED_DEVICE_COORDINATES, quad,
                    Coordinates2d.TEXTURE_NORMALIZED, texCoords,
                )
            }
            if (frame.timestamp == 0L) return
            quad.position(0)
            texCoords.position(0)
            GLES20.glDisable(GLES20.GL_DEPTH_TEST)
            GLES20.glDepthMask(false)
            GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
            GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, textureId)
            GLES20.glUseProgram(program)
            GLES20.glVertexAttribPointer(positionAttrib, 2, GLES20.GL_FLOAT, false, 0, quad)
            GLES20.glVertexAttribPointer(texCoordAttrib, 2, GLES20.GL_FLOAT, false, 0, texCoords)
            GLES20.glEnableVertexAttribArray(positionAttrib)
            GLES20.glEnableVertexAttribArray(texCoordAttrib)
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
            GLES20.glDisableVertexAttribArray(positionAttrib)
            GLES20.glDisableVertexAttribArray(texCoordAttrib)
            GLES20.glDepthMask(true)
            GLES20.glEnable(GLES20.GL_DEPTH_TEST)
        }

        private fun link(vertex: String, fragment: String): Int {
            val p = GLES20.glCreateProgram()
            GLES20.glAttachShader(p, compile(GLES20.GL_VERTEX_SHADER, vertex))
            GLES20.glAttachShader(p, compile(GLES20.GL_FRAGMENT_SHADER, fragment))
            GLES20.glLinkProgram(p)
            return p
        }

        private fun compile(type: Int, source: String): Int {
            val shader = GLES20.glCreateShader(type)
            GLES20.glShaderSource(shader, source)
            GLES20.glCompileShader(shader)
            return shader
        }

        companion object {
            fun floatBuffer(values: FloatArray): FloatBuffer =
                ByteBuffer.allocateDirect(values.size * 4).order(ByteOrder.nativeOrder())
                    .asFloatBuffer().apply { put(values); position(0) }
        }
    }
}
