import Toybox.AntPlus;
import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! App entry point for the Überholzähler bonus-button counter data field.
//!
//! Taps the Edge's native ANT+ Shifting channel (the one already paired to the
//! SRAM drivetrain) via an AntPlus.Shifting device + ShiftingListener. No raw
//! channel, no device number, no background scan: the bonus-button function-set
//! events arrive on data page 2 of the shifting channel and are decoded in
//! AXSButtonListener.
class AXSCounterApp extends Application.AppBase {
    private var _field as AXSCounterField;
    private var _listener as AXSButtonListener?;
    private var _shifting as AntPlus.Shifting?;

    //! Constructor.
    public function initialize() {
        AppBase.initialize();
        // Created here (not in onStart) so the exact instance the listener
        // drives is the one getInitialView() returns, regardless of the
        // onStart/getInitialView ordering.
        _field = new AXSCounterField();
    }

    //! Handle app startup: attach the listener to the native shifting channel.
    //! @param state Startup arguments.
    public function onStart(state as Dictionary?) as Void {
        _listener = new AXSButtonListener(_field);
        _shifting = new AntPlus.Shifting(_listener);
        System.println("AXSCounterApp: shifting listener attached");
    }

    //! Handle app shutdown: detach the listener and release the device.
    //! @param state Shutdown arguments.
    public function onStop(state as Dictionary?) as Void {
        _shifting = null;
        _listener = null;
    }

    //! Return the initial view for the app.
    //! @return Array [View].
    public function getInitialView() as [Views] or [Views, InputDelegates] {
        return [_field];
    }
}
