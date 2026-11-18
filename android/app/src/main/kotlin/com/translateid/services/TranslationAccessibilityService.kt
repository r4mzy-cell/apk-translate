package com.translateid.services

import android.accessibilityservice.AccessibilityService
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.concurrent.ConcurrentHashMap

class TranslationAccessibilityService : AccessibilityService() {

    private val scope = CoroutineScope(Dispatchers.IO)
    private val textChangeCallbacks = ConcurrentHashMap<String, (String) -> Unit>()

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        when (event?.eventType) {
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                handleWindowContentChanged(event)
            }
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                handleWindowStateChanged(event)
            }
            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> {
                handleViewTextChanged(event)
            }
            AccessibilityEvent.TYPE_VIEW_CLICKED -> {
                handleViewClicked(event)
            }
        }
    }

    private fun handleWindowContentChanged(event: AccessibilityEvent) {
        val source = event.source ?: return
        scope.launch {
            extractTextFromNode(source) { text ->
                if (text.isNotBlank()) {
                    // Send to Flutter for translation
                    sendToFlutter("liveTranslate", mapOf("text" to text))
                }
            }
        }
    }

    private fun handleWindowStateChanged(event: AccessibilityEvent) {
        val source = event.source ?: return
        scope.launch {
            extractTextFromNode(source) { text ->
                if (text.isNotBlank()) {
                    sendToFlutter("windowChanged", mapOf("text" to text, "package" to event.packageName.toString()))
                }
            }
        }
    }

    private fun handleViewTextChanged(event: AccessibilityEvent) {
        val source = event.source ?: return
        val text = source.text?.toString() ?: ""
        if (text.isNotBlank()) {
            sendToFlutter("textChanged", mapOf("text" to text))
        }
    }

    private fun handleViewClicked(event: AccessibilityEvent) {
        val source = event.source ?: return
        val text = extractTextFromNodeSync(source)
        if (text.isNotBlank()) {
            sendToFlutter("viewClicked", mapOf("text" to text))
        }
    }

    private fun extractTextFromNode(node: AccessibilityNodeInfo, callback: (String) -> Unit) {
        scope.launch {
            val text = extractTextFromNodeSync(node)
            callback(text)
        }
    }

    private fun extractTextFromNodeSync(node: AccessibilityNodeInfo): String {
        val builder = StringBuilder()
        extractTextRecursive(node, builder)
        return builder.toString()
    }

    private fun extractTextRecursive(node: AccessibilityNodeInfo, builder: StringBuilder) {
        node.text?.let { builder.append(it).append(" ") }
        for (i in 0 until node.childCount) {
            node.getChild(i)?.let { extractTextRecursive(it, builder) }
        }
    }

    private fun sendToFlutter(action: String, data: Map<String, Any>) {
        // TODO: Send to Flutter via MethodChannel or EventChannel
        // MainActivity.overlayEventChannel?.invokeMethod(action, data)
        Log.d("TranslationAccessibility", "$action: $data")
    }

    override fun onInterrupt() {
        Log.d("TranslationAccessibility", "Service interrupted")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d("TranslationAccessibility", "Service connected")
    }
}