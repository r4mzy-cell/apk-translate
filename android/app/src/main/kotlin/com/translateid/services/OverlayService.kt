package com.translateid.services

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.graphics.Rect
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import androidx.core.content.ContextCompat
import com.translateid.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.concurrent.ConcurrentHashMap

class OverlayService(
    private val context: Context,
    private val config: Map<String, Any>
) {
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val layoutInflater = LayoutInflater.from(context)

    private var bubbleView: View? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private val translationOverlays = ConcurrentHashMap<String, View>()
    private var audioSubtitleView: View? = null

    private var initialX = 0f
    private var initialY = 0f
    private var initialTouchX = 0f
    private var initialTouchY = 0f

    fun showBubble() {
        if (bubbleView != null) return

        bubbleView = layoutInflater.inflate(R.layout.overlay_bubble, null)
        val bubbleIcon = bubbleView?.findViewById<ImageView>(R.id.bubble_icon)
        val bubbleMenu = bubbleView?.findViewById<ViewGroup>(R.id.bubble_menu)

        bubbleIcon?.setOnClickListener { toggleMenu() }
        bubbleIcon?.setOnTouchListener { _, event -> onBubbleTouch(event) }

        bubbleParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            getOverlayWindowType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
                or WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.START or Gravity.TOP
            x = config.getOrDefault("x", 50) as Int
            y = config.getOrDefault("y", 500) as Int
        }

        windowManager.addView(bubbleView!!, bubbleParams!!)
    }

    fun hideBubble() {
        bubbleView?.let { windowManager.removeView(it) }
        bubbleView = null
        bubbleParams = null
        hideMenu()
    }

    fun updateBubblePosition(x: Float, y: Float) {
        bubbleParams?.apply {
            this.x = x.toInt()
            this.y = y.toInt()
            bubbleView?.let { windowManager.updateViewLayout(it, this) }
        }
    }

    private fun onBubbleTouch(event: MotionEvent): Boolean {
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                initialX = bubbleParams?.x?.toFloat() ?: 0f
                initialY = bubbleParams?.y?.toFloat() ?: 0f
                initialTouchX = event.rawX
                initialTouchY = event.rawY
                hideMenu()
                true
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = event.rawX - initialTouchX
                val dy = event.rawY - initialTouchY
                val newX = (initialX + dx).toInt()
                val newY = (initialY + dy).toInt()
                bubbleParams?.apply {
                    this.x = newX
                    this.y = newY
                    bubbleView?.let { windowManager.updateViewLayout(it, this) }
                }
                true
            }
            MotionEvent.ACTION_UP -> {
                // Notify Flutter of new position
                CoroutineScope(Dispatchers.IO).launch {
                    // TODO: Send to Flutter via MethodChannel
                }
                true
            }
            else -> false
        }
    }

    private fun toggleMenu() {
        val menu = bubbleView?.findViewById<ViewGroup>(R.id.bubble_menu)
        menu?.visibility = if (menu?.visibility == View.VISIBLE) View.GONE else View.VISIBLE
        setupMenuButtons()
    }

    private fun hideMenu() {
        val menu = bubbleView?.findViewById<ViewGroup>(R.id.bubble_menu)
        menu?.visibility = View.GONE
    }

    private fun setupMenuButtons() {
        val menu = bubbleView?.findViewById<ViewGroup>(R.id.bubble_menu)
        val liveBtn = menu?.findViewById<ImageView>(R.id.menu_live_translate)
        val screenshotBtn = menu?.findViewById<ImageView>(R.id.menu_screenshot)
        val audioBtn = menu?.findViewById<ImageView>(R.id.menu_audio_translate)
        val settingsBtn = menu?.findViewById<ImageView>(R.id.menu_settings)
        val closeBtn = menu?.findViewById<ImageView>(R.id.menu_close)

        liveBtn?.setOnClickListener { sendAction("live_translate_toggle"); hideMenu() }
        screenshotBtn?.setOnClickListener { sendAction("screenshot_translate"); hideMenu() }
        audioBtn?.setOnClickListener { sendAction("audio_translate_toggle"); hideMenu() }
        settingsBtn?.setOnClickListener { sendAction("open_settings"); hideMenu() }
        closeBtn?.setOnClickListener { sendAction("close_bubble"); hideBubble() }
    }

    private fun sendAction(action: String) {
        CoroutineScope(Dispatchers.IO).launch {
            // TODO: Send to Flutter via MethodChannel
        }
    }

    fun showTranslationOverlays(overlays: List<Map<String, Any>>) {
        for (overlay in overlays) {
            val id = overlay["id"] as String
            val text = overlay["translatedText"] as String
            val bounds = overlay["bounds"] as Map<String, Double> // left, top, right, bottom (0-1)
            val type = overlay["type"] as String // "screenshot" or "live"

            val overlayView = createTranslationOverlay(id, text, bounds, type)
            translationOverlays[id] = overlayView

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                getOverlayWindowType(),
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                    or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
                    or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.START or Gravity.TOP
                val screenWidth = windowManager.defaultDisplay.width
                val screenHeight = windowManager.defaultDisplay.height
                x = (bounds["left"]!! * screenWidth).toInt()
                y = (bounds["top"]!! * screenHeight).toInt()
            }

            windowManager.addView(overlayView, params)
        }
    }

    private fun createTranslationOverlay(id: String, text: String, bounds: Map<String, Double>, type: String): View {
        val view = layoutInflater.inflate(R.layout.overlay_translation, null)
        val textView = view.findViewById<TextView>(R.id.overlay_text)
        textView.text = text

        val bgColor = when (type) {
            "live" -> ContextCompat.getColor(context, R.color.overlay_live_bg)
            else -> ContextCompat.getColor(context, R.color.overlay_screenshot_bg)
        }
        view.setBackgroundColor(bgColor)

        return view
    }

    fun hideTranslationOverlays(ids: List<String>) {
        for (id in ids) {
            translationOverlays.remove(id)?.let { view ->
                try { windowManager.removeView(view) } catch (e: Exception) {}
            }
        }
    }

    fun showAudioSubtitle(text: String, config: Map<String, Any>) {
        if (audioSubtitleView != null) {
            updateAudioSubtitle(text, config)
            return
        }

        audioSubtitleView = layoutInflater.inflate(R.layout.overlay_audio_subtitle, null)
        val textView = audioSubtitleView?.findViewById<TextView>(R.id.subtitle_text)
        textView?.text = text

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            getOverlayWindowType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
                or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            y = (config.getOrDefault("yOffset", -100) as Int)
        }

        windowManager.addView(audioSubtitleView!!, params)
    }

    fun updateAudioSubtitle(text: String, config: Map<String, Any>) {
        val textView = audioSubtitleView?.findViewById<TextView>(R.id.subtitle_text)
        textView?.text = text
    }

    fun hideAudioSubtitle() {
        audioSubtitleView?.let { windowManager.removeView(it) }
        audioSubtitleView = null
    }

    private fun getOverlayWindowType(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        }
    }
}