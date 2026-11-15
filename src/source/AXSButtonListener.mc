import Toybox.Ant;
import Toybox.AntPlus;
import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
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
//! **Action bindings** are user-configurable from the phone (Garmin Connect
//! app settings): each of the actions *increment*, *decrement* and *reset* is
//! bound to one of the 16 function-set/press-type combinations, or unassigned.
//! The bindings are stored as app properties (see properties.xml) and reloaded
//! in `onSettingsChanged()`, so changes from the phone take effect immediately
//! while the field is running.
//!
//! The connect dot is driven by *actual frame reception*: any page-2 frame
//! turns it green, and the field's once-per-second `compute()` hook calls
//! `tick()` to turn it red again when frames stop arriving (SRAM asleep /
//! out of range / channel lost). The AntPlus device state is deliberately
//! *not* used for this: DEVICE_STATE_TRACKING only becomes true while an
//! activity records, even though frames arrive while idle too.
//!
//! NOTE: `Toybox.Timer` is NOT available to `type="datafield"` apps (the
//! firmware raises "Permission Required" at runtime), so the stale check is
//! driven from the data field's `compute()` instead. `System.getTimer()` is
//! allowed and is used for the timestamp.
//! Property keys (see properties.xml). Module scope so both this listener and
//! the on-device settings view (AXSCounterSettings.mc) reference the same
//! property names; accessed cross-file as $.PROP_*.
const PROP_INCREMENT = "actionIncrement";
const PROP_DECREMENT = "actionDecrement";
const PROP_RESET = "actionReset";

class AXSButtonListener extends AntPlus.ShiftingListener {
    //! Button data page number on the Shifting profile.
    private const BUTTON_PAGE = 2;
    //! Long-press flag (bit 5 of the event byte).
    private const LONG_PRESS_FLAG = 0x20;
    //! Frames older than this mean the shifter is no longer broadcasting.
    private const STALE_MS = 5000;
    //! Binding values: 0 = unassigned, 1-8 = FS 1-8 short press,
    //! 9-16 = FS 1-8 long press (functionSet + 8).
    private const BINDING_UNASSIGNED = 0;
    private const LONG_PRESS_OFFSET = 8;

    private var _field as AXSCounterField;
    //! Last observed event counter; -1 until the first page-2 frame arrives.
    private var _lastCounter as Number = -1;
    //! System clock (ms) of the last page-2 frame received.
    private var _lastFrameMs as Number = 0;
    //! True while page-2 frames are arriving (drives the green/red dot).
    private var _connected as Boolean = false;
    //! Configured bindings (see properties.xml).
    private var _incrementBinding as Number = BINDING_UNASSIGNED;
    private var _decrementBinding as Number = BINDING_UNASSIGNED;
    private var _resetBinding as Number = BINDING_UNASSIGNED;

    //! Constructor.
    //! @param field The data field that receives counter deltas and connection state.
    public function initialize(field as AXSCounterField) {
        ShiftingListener.initialize();
        _field = field;
        loadBindings();
    }

    //! Load the action bindings from the app properties.
    private function loadBindings() as Void {
        _incrementBinding = Properties.getValue($.PROP_INCREMENT) as Number;
        _decrementBinding = Properties.getValue($.PROP_DECREMENT) as Number;
        _resetBinding = Properties.getValue($.PROP_RESET) as Number;
        System.println("AXSButton: bindings inc=" + _incrementBinding +
                       " dec=" + _decrementBinding + " rst=" + _resetBinding);
    }

    //! Called by the app when the user changes the settings from the phone.
    //! Reloads the bindings so they take effect immediately.
    public function onSettingsChanged() as Void {
        loadBindings();
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
        handleEvent(functionSet, longPress);
    }

    //! Map a decoded function-set event to the configured action and apply it.
    //!
    //! The event is converted to a binding value and compared against the
    //! three configured bindings. If several actions are bound to the same
    //! combination (user error), the priority is
    //! increment > decrement > reset.
    //! @param functionSet The decoded function set (1-8).
    //! @param longPress True for a long press, false for a single press.
    private function handleEvent(functionSet as Number, longPress as Boolean) as Void {
        // Ignore invalid function sets (0 or > 8): a binding value of 0 means
        // "unassigned" and must never match a real event.
        if ((functionSet < 1) || (functionSet > 8)) {
            return;
        }
        var binding = functionSet + (longPress ? LONG_PRESS_OFFSET : 0);
        System.println("AXSButton: fn=" + functionSet + " long=" + longPress +
                       " binding=" + binding);
        if (binding == _incrementBinding) {
            _field.applyDelta(1);
        } else if (binding == _decrementBinding) {
            _field.applyDelta(-1);
        } else if (binding == _resetBinding) {
            _field.resetCounter();
        }
    }

    //! Stale check, called once per second by the field's `compute()`.
    //! Turns the dot red when page-2 frames stopped arriving.
    public function tick() as Void {
        if (_connected && (System.getTimer() - _lastFrameMs > STALE_MS)) {
            _connected = false;
            _field.setConnected(false);
        }
    }
}
