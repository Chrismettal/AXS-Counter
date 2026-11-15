import Toybox.Ant;
import Toybox.AntPlus;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! Listener that taps the Edge's native ANT+ Shifting channel and decodes the
//! SRAM Force AXS bonus-button events.
//!
//! The bonus buttons are exposed by SRAM as ANT+ *function sets* on the
//! Shifting profile (device type 0x22). On every button press the shifter
//! broadcasts a fresh **data page 2** frame:
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
class AXSButtonListener extends AntPlus.ShiftingListener {
    //! Button data page number on the Shifting profile.
    private const BUTTON_PAGE = 2;
    //! Function-set values (lower 5 bits of the event byte).
    private const FUNCTION_SET_LEFT = 1;
    private const FUNCTION_SET_RIGHT = 2;
    private const FUNCTION_SET_BOTH = 3;
    //! Long-press flag (bit 5 of the event byte).
    private const LONG_PRESS_FLAG = 0x20;

    private var _field as AXSCounterField;
    //! Last observed event counter; -1 until the first page-2 frame arrives.
    private var _lastCounter as Number = -1;

    //! Constructor.
    //! @param field The data field that receives counter deltas and connection state.
    public function initialize(field as AXSCounterField) {
        ShiftingListener.initialize();
        _field = field;
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

    //! Connection-state handler: drives the green/red indicator.
    //! @param data The device state (state + device number).
    public function onDeviceStateUpdate(data as AntPlus.DeviceState) as Void {
        var connected = (data.state == AntPlus.DEVICE_STATE_TRACKING);
        _field.setConnected(connected);
    }

    //! Map a decoded function-set event to a counter delta.
    //!
    //! Increment-only for now: both-buttons (FS3) -> +1. Left (FS1) and right
    //! (FS2) are reserved so +/- support can be added without touching the
    //! frame decoding above.
    //! @param functionSet The decoded function set (1, 2 or 3).
    //! @param longPress True for a long press, false for a single press.
    //! @return The counter delta to apply (0 = ignore).
    private function deltaFor(functionSet as Number, longPress as Boolean) as Number {
        if (functionSet == FUNCTION_SET_BOTH) {
            return 1;
        }
        // FUNCTION_SET_LEFT / FUNCTION_SET_RIGHT: reserved for future +/- support.
        return 0;
    }
}
