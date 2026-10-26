package org.congressionalappchallenge.bridge.platform

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.view.accessibility.AccessibilityEvent
import java.lang.ref.WeakReference

class BridgePhoneAccessService : AccessibilityService() {
    override fun onServiceConnected() { active = WeakReference(this) }
    override fun onAccessibilityEvent(event: AccessibilityEvent?) = Unit
    override fun onInterrupt() = Unit
    override fun onDestroy() { if (active?.get() === this) active = null; super.onDestroy() }

    fun perform(command: String): Boolean = when (command) {
        "home" -> performGlobalAction(GLOBAL_ACTION_HOME)
        "back" -> performGlobalAction(GLOBAL_ACTION_BACK)
        "scroll up", "scroll down" -> {
            val display = resources.displayMetrics
            val x = display.widthPixels * 0.5f
            val high = display.heightPixels * 0.30f
            val low = display.heightPixels * 0.72f
            val path = Path().apply {
                moveTo(x, if (command == "scroll down") low else high)
                lineTo(x, if (command == "scroll down") high else low)
            }
            dispatchGesture(GestureDescription.Builder().addStroke(GestureDescription.StrokeDescription(path, 0, 350)).build(), null, null)
        }
        else -> false
    }

    companion object { var active: WeakReference<BridgePhoneAccessService>? = null; private set }
}
