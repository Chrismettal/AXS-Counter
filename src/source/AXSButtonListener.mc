import Toybox.Ant;
import Toybox.AntPlus;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

//! Listener that taps the Edge's native ANT+ Shifting channel and decodes the
//! SRAM Force AXS bonus-button events.
//!
//! The bonus buttons are exposed by SRAM as ANT+ *function sets* on the
//! Shifting profile (device type 0x22). The shifter broadcasts a **data page 2**
//! frame about once per second while it is awake:
//!
//!     [2, counter, newest, e2, e3, e4, e5, 0]
//!
//!   * byte 0    = 2 (button page)
//!   * byte 1    = event counter, increments on every press
//!   * bytes 2..6 = last 5 events, most recent first
//!   * event byte = functionSet | (longPress ? 0x20 : 0)
//!       1 = left (FS1) single, 2 = right (FS2) single, 3 = both (FS3) single
//!       33 = left long, 34 = right long, 35 = both long
//!
//! A new press is detected by the counter changing; the newest event is then
//! byte 2. This is verified on-device (see maca88/SmartBikeLights#123).
//!
//! The connect dot is driven by *actual frame reception*: any page-2 frame
//! turns it green, and a watchdog turns it red again when frames stop
//! arriving (SRAM asleep / out of range / channel lost). The AntPlus device
//! state is deliberately *not* used for this: DEVICE_STATE_TRACKING only
//! becomes true while an activity records, even though frames arrive while
//! idle too.
class AXSButtonListener extends AntPlus.ShiftingListener {
    //! Button data page number on the Shifting profile.
    private const BUTTON_PAGE = 2;
    //! Function-set values (lower 5 bits of the event byte).
    private const FUNCTION_SET_LEFT = 1;
    private const FUNCTION_SET_RIGHT = 2;
    private const FUNCTION_SET_BOTH = 3;
    //! Long-press flag (bit 5 of the event byte).
    private const LONG_PRESS_FLAG = 0x20;
    //! Watchdog tick period in ms.
    private const TICK_MS = 1000;
    //! Frames older than this mean the shifter is no longer broadcasting.
    private const STALE_MS = 5000;

    private var _field as AXSCounterField;
    //! Last observed event counter; -1 until the first page-2 frame arrives.
    private var _lastCounter as Number = -1;
    //! System clock (ms) of the last page-2 frame received.
    private var _lastFrameMs as Number = 0;
    //! True while page-2 frames are arriving (drives the green/red dot).
    private var _connected as Boolean = false;
    private var _timer as Timer.Timer;

    //! Constructor.
    //! @param field The data field that receives counter deltas and connection state.
    public function initialize(field as AXSCounterField) {
        ShiftingListener.initialize();
        _field = field;
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), TICK_MS, true);
    }

    //! Raw ANT frame handler.
    //! @param msg The ANT message received on the shifting channel.
    public function onMessage(msg as Ant.Message) as Void {
        var payload = msg.getPayload();
        if ((payload == null) || (payload.size() < 3)) {
            return;
        }
        // Only the button page carries function-set events.
        if (payload[0] != BUTTON_PAGE) {
            return;
        }
        // Any page-2 frame means the shifter is awake and broadcasting: green.
        _lastFrameMs = System.getTimer();
        if (!_connected) {
            _connected = true;
            _field.setConnected(true);
        }
        var counter = payload[1];
        if (_lastCounter < 0) {
            // First frame: record the baseline counter, no event yet.
            _lastCounter = counter;
            return;
        }
        if (counter == _lastCounter) {
            return; // No new press since the last frame.
        }
        _lastCounter = counter;

        var eventByte = payload[2];
        var functionSet = eventByte & 0x1F;
        var longPress = (eventByte & LONG_PRESS_FLAG) != 0;
        var delta = deltaFor(functionSet, longPress);
        System.println("AXSButton: fn=" + functionSet + " long=" + longPress + " delta=" + delta);
        if (delta != 0) {
            _field.applyDelta(delta);
        }
    }

    //! Stop the watchdog timer. Called by the app on shutdown.
    public function shutdown() as Void {
        _timer.stop();
    }

    //! Watchdog tick: red dot when page-2 frames stopped arriving.
    public function onTick() as Void {
        if (_connected && (System.getTimer() - _lastFrameMs > STALE_MS)) {
            _connected = false;
            _field.setConnected(false);
        }
    }

    //! Map a decoded function-set event to a counter delta.
    //!
    //! Both-buttons (FS3): short press -> +1, long press -> ignored (reserved
    //! for a future -1). Left (FS1) and right (FS2) are reserved so +/-
    //! support can be added without touching the frame decoding above.
    //! @param functionSet The decoded function set (1, 2 or 3).
    //! @param longPress True for a long press, false for a single press.
    //! @return The counter delta to apply (0 = ignore).
    private function deltaFor(functionSet as Number, longPress as Boolean) as Number {
        if ((functionSet == FUNCTION_SET_BOTH) && !longPress) {
            return 1;
        }
        return 0;
    }
}
