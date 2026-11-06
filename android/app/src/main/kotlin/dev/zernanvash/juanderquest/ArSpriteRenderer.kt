package dev.zernanvash.juanderquest

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.opengl.GLES20
import android.opengl.GLUtils
import android.opengl.Matrix
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Pixel-art sprites (2.5D: flat pictures) drawn natively in ARCore's own frame, so they
 * never lag behind the camera (owner 2026-11-06: "2.5D sprites ... 2d planes following camera").
 *
 * Dart loads sprite strips once ([loadSheet]) and sends a scene ([setScene]) only when
 * something happens. Each sprite carries its own motion (start, velocity, gravity) and
 * frame animation, timed from when the scene arrives, so a thrown slipper flies smoothly
 * without per-frame channel traffic. Positions are metres relative to the anchor (world
 * axes, y up from the anchor's floor point).
 *
 * Art scale: 320 sprite pixels per metre, times the sprite's own scale.
 *
 * Swing and sway (Plan 77 mini-games): s = sin(2π·age/oscPeriod + oscPhase) moves the
 * sprite by (ox, oy, oz)·s and turns it by roll + rollAmp·s radians about its pivot, in
 * its own plane (positive = anticlockwise as you look at it). Dart sends oscPhase from
 * its game clock, so a new scene continues a swing instead of restarting it. With
 * align, the sprite's +x points along its on-screen motion (a flying arrow).
 */
class ArSpriteRenderer {
    class Sheet(
        val bitmap: Bitmap,
        val frames: Int,
        val frameW: Int,
        val frameH: Int,
        val pivotX: Float,
        val pivotY: Float,
    ) {
        var texture = 0
    }

    class Sprite(
        val sheet: String,
        val floor: Boolean,
        val x: Float, val y: Float, val z: Float,
        val vx: Float, val vy: Float, val vz: Float,
        val gravity: Float,
        val scale: Float,
        val frame: Int,
        val fps: Float,
        val loop: Boolean,
        val delay: Float,
        val life: Float,
        val roll: Float = 0f,
        val rollAmp: Float = 0f,
        val oscPeriod: Float = 0f,
        val oscPhase: Float = 0f,
        val ox: Float = 0f, val oy: Float = 0f, val oz: Float = 0f,
        val align: Boolean = false,
    )

    private val sheets = ConcurrentHashMap<String, Sheet>()
    @Volatile private var scene: List<Sprite> = emptyList()
    @Volatile private var sceneStartNs = 0L

    private var program = 0
    private var aPos = 0
    private var aUv = 0
    private var uVp = 0
    private var uTex = 0
    private var uCutout = 0
    private val vp = FloatArray(16)
    private var aspect = 1f
    private var lastAlign = 0f
    private val clipA = FloatArray(4)
    private val clipB = FloatArray(4)
    private val worldA = FloatArray(4)
    private val worldB = FloatArray(4)
    private val quad: FloatBuffer =
        ByteBuffer.allocateDirect(4 * 5 * 4).order(ByteOrder.nativeOrder()).asFloatBuffer()

    val hasScene: Boolean get() = scene.isNotEmpty()

    /** Any thread: decode a PNG strip of [frames] equal frames. */
    fun loadSheet(name: String, png: ByteArray, frames: Int, frameW: Int, frameH: Int, pivotX: Float, pivotY: Float): Boolean {
        val opts = BitmapFactory.Options().apply { inScaled = false }
        val bmp = BitmapFactory.decodeByteArray(png, 0, png.size, opts) ?: return false
        sheets[name] = Sheet(bmp, frames, frameW, frameH, pivotX, pivotY)
        return true
    }

    /** Any thread: replace what is drawn; motion and animation restart from now. */
    fun setScene(sprites: List<Sprite>) {
        sceneStartNs = System.nanoTime()
        scene = sprites
    }

    /** GL thread, on (re)created surface: textures from an old context are gone. */
    fun create() {
        for (s in sheets.values) s.texture = 0
        program = link(
            """
            uniform mat4 u_Vp;
            attribute vec3 a_Pos;
            attribute vec2 a_Uv;
            varying vec2 v_Uv;
            void main() { v_Uv = a_Uv; gl_Position = u_Vp * vec4(a_Pos, 1.0); }
            """.trimIndent(),
            """
            precision mediump float;
            varying vec2 v_Uv;
            uniform sampler2D u_Tex;
            uniform float u_Cutout;
            void main() {
              vec4 c = texture2D(u_Tex, v_Uv);
              if (u_Cutout > 0.5 && c.a < 0.5) discard;
              gl_FragColor = c;
            }
            """.trimIndent(),
        )
        aPos = GLES20.glGetAttribLocation(program, "a_Pos")
        aUv = GLES20.glGetAttribLocation(program, "a_Uv")
        uVp = GLES20.glGetUniformLocation(program, "u_Vp")
        uTex = GLES20.glGetUniformLocation(program, "u_Tex")
        uCutout = GLES20.glGetUniformLocation(program, "u_Cutout")
    }

    private fun upload(s: Sheet) {
        val ids = IntArray(1)
        GLES20.glGenTextures(1, ids, 0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, ids[0])
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_NEAREST)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_NEAREST)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, s.bitmap, 0)
        s.texture = ids[0]
    }

    /** GL thread. [anchor] is the anchor's column-major pose; only its position is used. */
    fun draw(anchor: FloatArray, view: FloatArray, proj: FloatArray) {
        val sprites = scene
        if (sprites.isEmpty()) return
        val t = (System.nanoTime() - sceneStartNs) / 1e9f
        val ax = anchor[12]
        val ay = anchor[13]
        val az = anchor[14]
        Matrix.multiplyMM(vp, 0, proj, 0, view, 0)
        aspect = if (abs(proj[0]) > 1e-6f) proj[5] / proj[0] else 1f

        // Camera right / forward, flattened to the ground plane (upright sprites turn only about y).
        var rx = view[0]
        var rz = view[8]
        val rl = sqrt(rx * rx + rz * rz).takeIf { it > 1e-4f } ?: 1f
        rx /= rl; rz /= rl
        // Forward on the ground = up x right (y up): (rz, 0, -rx) points away from the camera.
        val fx = rz
        val fz = -rx

        GLES20.glUseProgram(program)
        GLES20.glUniformMatrix4fv(uVp, 1, false, vp, 0)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glUniform1i(uTex, 0)
        GLES20.glEnableVertexAttribArray(aPos)
        GLES20.glEnableVertexAttribArray(aUv)
        GLES20.glEnable(GLES20.GL_DEPTH_TEST)

        // Pass 1: floor decals (soft alpha, premultiplied), no depth writes.
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_ONE, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        GLES20.glDepthMask(false)
        GLES20.glUniform1f(uCutout, 0f)
        for (s in sprites) if (s.floor) drawOne(s, t, ax, ay, az, rx, rz, fx, fz)
        GLES20.glDisable(GLES20.GL_BLEND)
        GLES20.glDepthMask(true)

        // Pass 2: upright sprites, binary alpha (cut-out), so no sorting is needed.
        GLES20.glUniform1f(uCutout, 1f)
        for (s in sprites) if (!s.floor) drawOne(s, t, ax, ay, az, rx, rz, fx, fz)

        GLES20.glDisableVertexAttribArray(aPos)
        GLES20.glDisableVertexAttribArray(aUv)
    }

    private fun drawOne(s: Sprite, t: Float, ax: Float, ay: Float, az: Float, rx: Float, rz: Float, fx: Float, fz: Float) {
        val sheet = sheets[s.sheet] ?: return
        val age = t - s.delay
        if (age < 0f || (s.life > 0f && age > s.life)) return
        if (sheet.texture == 0) upload(sheet)

        var px = ax + s.x + s.vx * age
        var py = ay + s.y + s.vy * age - 0.5f * s.gravity * age * age
        var pz = az + s.z + s.vz * age
        var roll = s.roll
        if (s.oscPeriod > 0f) {
            val o = sin(2f * PI.toFloat() * age / s.oscPeriod + s.oscPhase)
            px += s.ox * o; py += s.oy * o; pz += s.oz * o
            roll += s.rollAmp * o
        }
        if (s.align) roll = screenAngle(px, py, pz, s.vx, s.vy - s.gravity * age, s.vz)
        val c = cos(roll)
        val sn = sin(roll)

        var f = s.frame
        if (s.fps > 0f) {
            val n = floor(age * s.fps).toInt()
            f = if (s.loop) n % sheet.frames else minOf(n, sheet.frames - 1)
        }
        f = f.coerceIn(0, sheet.frames - 1)

        val m = s.scale / 320f
        val left = -sheet.pivotX * m
        val right = (sheet.frameW - sheet.pivotX) * m
        val top = sheet.pivotY * m
        val bottom = -(sheet.frameH - sheet.pivotY) * m
        val texW = sheet.bitmap.width.toFloat()
        val texH = sheet.bitmap.height.toFloat()
        val u0 = (f * sheet.frameW + 0.5f) / texW
        val u1 = ((f + 1) * sheet.frameW - 0.5f) / texW
        val v0 = 0.5f / texH
        val v1 = (texH - 0.5f) / texH

        quad.position(0)
        // Corner (a along image right, b along image up), turned by roll about the pivot.
        fun put(a: Float, b: Float, u: Float, v: Float) {
            val a2 = a * c - b * sn
            val b2 = a * sn + b * c
            if (s.floor) {
                // Flat on the floor (2 mm up): image right = camera right, image up = away from the camera.
                corner(px + rx * a2 + fx * b2, py + 0.002f, pz + rz * a2 + fz * b2, u, v)
            } else {
                corner(px + rx * a2, py + b2, pz + rz * a2, u, v)
            }
        }
        put(left, bottom, u0, v1)
        put(right, bottom, u1, v1)
        put(left, top, u0, v0)
        put(right, top, u1, v0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, sheet.texture)
        quad.position(0)
        GLES20.glVertexAttribPointer(aPos, 3, GLES20.GL_FLOAT, false, 20, quad)
        quad.position(3)
        GLES20.glVertexAttribPointer(aUv, 2, GLES20.GL_FLOAT, false, 20, quad)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
    }

    /** On-screen direction (radians, anticlockwise from screen right) of velocity v at p. */
    private fun screenAngle(px: Float, py: Float, pz: Float, vx: Float, vy: Float, vz: Float): Float {
        val dt = 0.05f
        worldA[0] = px; worldA[1] = py; worldA[2] = pz; worldA[3] = 1f
        worldB[0] = px + vx * dt; worldB[1] = py + vy * dt; worldB[2] = pz + vz * dt; worldB[3] = 1f
        Matrix.multiplyMV(clipA, 0, vp, 0, worldA, 0)
        Matrix.multiplyMV(clipB, 0, vp, 0, worldB, 0)
        if (clipA[3] <= 1e-3f || clipB[3] <= 1e-3f) return lastAlign
        val dx = (clipB[0] / clipB[3] - clipA[0] / clipA[3]) * aspect
        val dy = clipB[1] / clipB[3] - clipA[1] / clipA[3]
        // Flying straight away barely moves on screen: keep the last angle instead of jittering.
        if (dx * dx + dy * dy < 1e-6f) return lastAlign
        lastAlign = atan2(dy, dx)
        return lastAlign
    }

    private fun corner(x: Float, y: Float, z: Float, u: Float, v: Float) {
        quad.put(x); quad.put(y); quad.put(z); quad.put(u); quad.put(v)
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
        /** Parses one sprite map sent from Dart. */
        fun parse(m: Map<*, *>): Sprite {
            fun f(k: String, d: Float = 0f) = (m[k] as? Number)?.toFloat() ?: d
            return Sprite(
                sheet = m["sheet"] as? String ?: "",
                floor = m["floor"] == true,
                x = f("x"), y = f("y"), z = f("z"),
                vx = f("vx"), vy = f("vy"), vz = f("vz"),
                gravity = f("gravity"),
                scale = f("scale", 1f),
                frame = (m["frame"] as? Number)?.toInt() ?: 0,
                fps = f("fps"),
                loop = m["loop"] == true,
                delay = f("delay"),
                life = f("life"),
                roll = f("roll"),
                rollAmp = f("rollAmp"),
                oscPeriod = f("oscPeriod"),
                oscPhase = f("oscPhase"),
                ox = f("ox"), oy = f("oy"), oz = f("oz"),
                align = m["align"] == true,
            )
        }
    }
}
