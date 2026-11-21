import Toybox.AntPlus;
import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! App entry point for the AXS-Counter bonus-button counter data field.
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
        _field.setListener(_listener);
        _shifting = new AntPlus.Shifting(_listener);
    }

    //! Handle app shutdown: detach the listener and release the device.
    //! @param state Shutdown arguments.
    public function onStop(state as Dictionary?) as Void {
        _shifting = null;
        _listener = null;
    }

    //! Called when the user changes the app settings from the phone while the
    //! field is running. Reloads the action bindings in the listener.
    public function onSettingsChanged() as Void {
        if (_listener != null) {
            _listener.onSettingsChanged();
        }
    }

    //! Return the initial view for the app.
    //! @return Array [View].
    public function getInitialView() as [Views] or [Views, InputDelegates] {
        return [_field];
    }

    //! Return the on-device settings view. The framework offers this when the
    //! field is added to a data page, and it stays reachable from the data page
    //! menu ("ConnectIQ Fields" entry, swipe up on the Edge). Works with
    //! sideloaded apps, unlike the phone settings dialog (which requires the
    //! Connect IQ App Store).
    //!
    //! The Edge 1050 has no Menu button, so the settings open directly into
    //! the root menu (action list) rather than a placeholder view.
    //! @return Array [View, Delegate].
    public function getSettingsView() as [Views] or [Views, InputDelegates] or Null {
        var menu = new AXSCounterSettingsMenu();
        return [menu, new AXSCounterSettingsMenuDelegate(menu, _listener)];
    }
}
