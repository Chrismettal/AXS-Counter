import Toybox.Ant;
import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! App entry point for the Überholzähler ANT+ sniffer data field.
//!
//! Opens the raw ANT+ background-scan channel on app start and passes it to
//! the data field, which renders the captured frames. The channel is closed
//! on app stop.
class SnifferApp extends Application.AppBase {
    private var _channel as SnifferChannel?;

    //! Constructor.
    public function initialize() {
        AppBase.initialize();
    }

    //! Handle app startup: open the sniffer channel.
    //! @param state Startup arguments.
    public function onStart(state as Dictionary?) as Void {
        try {
            _channel = new SnifferChannel();
            _channel.open();
            System.println("SnifferApp: channel opened");
        } catch (e instanceof Ant.UnableToAcquireChannelException) {
            System.println("SnifferApp: " + e.getErrorMessage());
            _channel = null;
        }
    }

    //! Handle app shutdown: close the sniffer channel.
    //! @param state Shutdown arguments.
    public function onStop(state as Dictionary?) as Void {
        if (_channel != null) {
            _channel.close();
            _channel = null;
        }
    }

    //! Return the initial view for the app.
    //! @return Array [View].
    public function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new $.SnifferField(_channel)];
    }
}
