package dev.zernanvash.juanderquest

import android.opengl.GLES20
import android.opengl.Matrix
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Draws the quest gem natively, in the SAME OpenGL frame as the ARCore camera image
 * (owner 2026-11-02: "its laggy ... my camera has a better AR"). Drawing it in Flutter on
 * top of the camera view made it trail the picture by a frame or two; here it uses ARCore's
 * view/projection of that exact frame, so it cannot lag.
 *
 * The gem is a faceted octahedron with banded (pixel-style) shading, spinning slowly and
 * bobbing a little, with a soft contact shadow on the floor under it.
 */
class ArGemRenderer {
    private var gemProgram = 0
    private var gemPos = 0
    private var gemNorm = 0
    private var gemMvp = 0
    private var gemModel = 0
    private var gemColor = 0
    private var gemCount = 0
    private lateinit var gemVerts: FloatBuffer

    private var shadowProgram = 0
    private var shadowPos = 0
    private var shadowMvp = 0
    private val shadowQuad = floatBuffer(
        floatArrayOf(-1f, 0f, -1f, 1f, 0f, -1f, -1f, 0f, 1f, 1f, 0f, 1f),
    )

    private val model = FloatArray(16)
    private val mv = FloatArray(16)
    private val mvp = FloatArray(16)

    /** Gem colour (sun gold by default), linear RGB 0..1. */
    var color = floatArrayOf(1f, 0.718f, 0.012f)

    fun create() {
        gemVerts = floatBuffer(octahedron(halfWidth = 0.17f, halfHeight = 0.26f))
        gemCount = gemVerts.capacity() / 6
        gemProgram = link(
            """
            uniform mat4 u_Mvp;
            uniform mat4 u_Model;
            attribute vec3 a_Pos;
            attribute vec3 a_Norm;
            varying vec3 v_N;
            void main() {
              v_N = (u_Model * vec4(a_Norm, 0.0)).xyz;
              gl_Position = u_Mvp * vec4(a_Pos, 1.0);
            }
            """.trimIndent(),
            """
            precision mediump float;
            varying vec3 v_N;
            uniform vec3 u_Color;
            void main() {
              vec3 l = normalize(vec3(0.35, 1.0, 0.45));
              float d = max(dot(normalize(v_N), l), 0.0);
              d = floor(d * 3.0 + 0.5) / 3.0;           // 3 flat bands: pixel-art shading
              vec3 c = u_Color * (0.42 + 0.68 * d);
              gl_FragColor = vec4(c, 1.0);
            }
            """.trimIndent(),
        )
        gemPos = GLES20.glGetAttribLocation(gemProgram, "a_Pos")
        gemNorm = GLES20.glGetAttribLocation(gemProgram, "a_Norm")
        gemMvp = GLES20.glGetUniformLocation(gemProgram, "u_Mvp")
        gemModel = GLES20.glGetUniformLocation(gemProgram, "u_Model")
        gemColor = GLES20.glGetUniformLocation(gemProgram, "u_Color")

        shadowProgram = link(
            """
            uniform mat4 u_Mvp;
            attribute vec3 a_Pos;
            varying vec2 v_Uv;
            void main() { v_Uv = a_Pos.xz; gl_Position = u_Mvp * vec4(a_Pos, 1.0); }
            """.trimIndent(),
            """
            precision mediump float;
            varying vec2 v_Uv;
            void main() {
              float r = length(v_Uv);
              gl_FragColor = vec4(0.05, 0.1, 0.16, 0.38 * (1.0 - smoothstep(0.45, 1.0, r)));
            }
            """.trimIndent(),
        )
        shadowPos = GLES20.glGetAttribLocation(shadowProgram, "a_Pos")
        shadowMvp = GLES20.glGetUniformLocation(shadowProgram, "u_Mvp")
    }

    /**
     * [anchor] is the anchor's column-major pose (on the floor); [liftM] how high the gem
     * floats above it. [timeS] drives the spin and bob.
     */
    fun draw(anchor: FloatArray, view: FloatArray, proj: FloatArray, liftM: Float, timeS: Float) {
        GLES20.glEnable(GLES20.GL_DEPTH_TEST)
        GLES20.glDepthMask(true)

        // Contact shadow: a soft dark disc just above the floor, 0.22 m radius.
        Matrix.translateM(model, 0, anchor, 0, 0f, 0.005f, 0f)
        Matrix.scaleM(model, 0, 0.22f, 1f, 0.22f)
        Matrix.multiplyMM(mv, 0, view, 0, model, 0)
        Matrix.multiplyMM(mvp, 0, proj, 0, mv, 0)
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        GLES20.glDepthMask(false)
        GLES20.glUseProgram(shadowProgram)
        GLES20.glUniformMatrix4fv(shadowMvp, 1, false, mvp, 0)
        shadowQuad.position(0)
        GLES20.glVertexAttribPointer(shadowPos, 3, GLES20.GL_FLOAT, false, 0, shadowQuad)
        GLES20.glEnableVertexAttribArray(shadowPos)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(shadowPos)
        GLES20.glDepthMask(true)
        GLES20.glDisable(GLES20.GL_BLEND)

        // Gem: floats [liftM] above the floor, bobs 3 cm, turns 60°/s.
        val bob = 0.03f * sin(timeS * 2.2f)
        Matrix.translateM(model, 0, anchor, 0, 0f, liftM + bob, 0f)
        Matrix.rotateM(model, 0, (timeS * 60f) % 360f, 0f, 1f, 0f)
        Matrix.multiplyMM(mv, 0, view, 0, model, 0)
        Matrix.multiplyMM(mvp, 0, proj, 0, mv, 0)
        GLES20.glUseProgram(gemProgram)
        GLES20.glUniformMatrix4fv(gemMvp, 1, false, mvp, 0)
        GLES20.glUniformMatrix4fv(gemModel, 1, false, model, 0)
        GLES20.glUniform3fv(gemColor, 1, color, 0)
        gemVerts.position(0)
        GLES20.glVertexAttribPointer(gemPos, 3, GLES20.GL_FLOAT, false, 24, gemVerts)
        gemVerts.position(3)
        GLES20.glVertexAttribPointer(gemNorm, 3, GLES20.GL_FLOAT, false, 24, gemVerts)
        GLES20.glEnableVertexAttribArray(gemPos)
        GLES20.glEnableVertexAttribArray(gemNorm)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLES, 0, gemCount)
        GLES20.glDisableVertexAttribArray(gemPos)
        GLES20.glDisableVertexAttribArray(gemNorm)
    }

    /** Flat-shaded octahedron: 8 faces × 3 vertices, each (x, y, z, nx, ny, nz). */
    private fun octahedron(halfWidth: Float, halfHeight: Float): FloatArray {
        val top = floatArrayOf(0f, halfHeight, 0f)
        val bottom = floatArrayOf(0f, -halfHeight, 0f)
        val ring = listOf(
            floatArrayOf(halfWidth, 0f, 0f), floatArrayOf(0f, 0f, halfWidth),
            floatArrayOf(-halfWidth, 0f, 0f), floatArrayOf(0f, 0f, -halfWidth),
        )
        val out = ArrayList<Float>()
        fun face(a: FloatArray, b: FloatArray, c: FloatArray) {
            val u = floatArrayOf(b[0] - a[0], b[1] - a[1], b[2] - a[2])
            val v = floatArrayOf(c[0] - a[0], c[1] - a[1], c[2] - a[2])
            var n = floatArrayOf(u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
            val centre = floatArrayOf((a[0] + b[0] + c[0]) / 3, (a[1] + b[1] + c[1]) / 3, (a[2] + b[2] + c[2]) / 3)
            if (n[0] * centre[0] + n[1] * centre[1] + n[2] * centre[2] < 0) n = floatArrayOf(-n[0], -n[1], -n[2])
            val len = sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2])
            for (p in listOf(a, b, c)) {
                out.addAll(listOf(p[0], p[1], p[2], n[0] / len, n[1] / len, n[2] / len))
            }
        }
        for (i in 0 until 4) {
            val r0 = ring[i]
            val r1 = ring[(i + 1) % 4]
            face(top, r0, r1)
            face(bottom, r1, r0)
        }
        return out.toFloatArray()
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

    private fun floatBuffer(values: FloatArray): FloatBuffer =
        ByteBuffer.allocateDirect(values.size * 4).order(ByteOrder.nativeOrder())
            .asFloatBuffer().apply { put(values); position(0) }
}
