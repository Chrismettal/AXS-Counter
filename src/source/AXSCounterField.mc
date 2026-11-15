import Toybox.Activity;
import Toybox.FitContributor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Data field that renders the live bonus-button counter and a connect
//! indicator (green = receiving, red = no lock).
//!
//! Also records the counter into the activity's FIT file as developer data
//! (Toybox.FitContributor, available to data fields): a per-second record
//! timeline (chart on Garmin Connect) and a session-level final value
//! (activity summary). Field ids must match the <fitContributions> block in
//! strings.xml.
class AXSCounterField extends WatchUi.DataField {
    private const DOT_RADIUS = 6;
    //! Inset of the dot from the top/right edges of the field.
    private const DOT_PAD = 6;
    private const LABEL_STRING = "Counter";
    private const LABEL_FONT = Graphics.FONT_TINY;
    private const NUMBER_FONT = Graphics.FONT_NUMBER_HOT;
    //! FIT developer-data field ids; must match the fitField ids in the
    //! <fitContributions> block of strings.xml.
    private const FIT_FIELD_RECORD = 0;
    private const FIT_FIELD_SESSION = 1;
    //! Units written into the FIT file for both fields.
    private const FIT_UNITS = "presses";

    private var _counter as Number = 0;
    private var _connected as Boolean = false;
    private var _listener as AXSButtonListener?;
    //! FIT developer-data fields: the counter timeline (record messages →
    //! chart) and the final counter value (session message → summary).
    private var _recordField as FitContributor.Field;
    private var _sessionField as FitContributor.Field;

    //! Constructor.
    public function initialize() {
        DataField.initialize();
        _counter = 0;
        _connected = false;
        _listener = null;
        // Create the FIT developer-data fields. The framework ties them to
        // the active recording session; values are only written while an
        // activity records.
        _recordField = createField("axs_counter", FIT_FIELD_RECORD,
            FitContributor.DATA_TYPE_SINT16,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>FIT_UNITS});
        _sessionField = createField("axs_counter_final", FIT_FIELD_SESSION,
            FitContributor.DATA_TYPE_SINT16,
            {:mesgType=>FitContributor.MESG_TYPE_SESSION, :units=>FIT_UNITS});
    }

    //! Attach the listener that drives the counter and the connect dot.
    //! @param listener The listener that receives ANT+ shifting frames.
    public function setListener(listener as AXSButtonListener) as Void {
        _listener = listener;
    }

    //! Apply a counter delta from the listener.
    //! @param delta Amount to add to the counter.
    public function applyDelta(delta as Number) as Void {
        _counter = _counter + delta;
        pushCounterToFit();
        WatchUi.requestUpdate();
    }

    //! Reset the counter to zero (bound to the "Reset" action in settings).
    public function resetCounter() as Void {
        _counter = 0;
        pushCounterToFit();
        WatchUi.requestUpdate();
    }

    //! Write the current counter value into the FIT developer-data fields.
    //! Called when the value changes and once per second from `compute()` so
    //! the record timeline samples the counter even between presses (the
    //! session field only ever stores the latest value, so repeated writes
    //! are harmless).
    private function pushCounterToFit() as Void {
        _recordField.setData(_counter);
        _sessionField.setData(_counter);
    }

    //! Set the connection indicator.
    //! @param connected True while page-2 frames are actually arriving.
    public function setConnected(connected as Boolean) as Void {
        _connected = connected;
        WatchUi.requestUpdate();
    }

    //! Called by the framework once per second while the app runs.
    //! Drives the listener's stale-frame check (red dot when the shifter
    //! stops broadcasting) and samples the counter into the FIT record
    //! timeline.
    //! @param info The current activity info (unused).
    public function compute(info as Activity.Info) as Void {
        if (_listener != null) {
            _listener.tick();
        }
        pushCounterToFit();
    }

    //! Draw the field.
    //! @param dc Device context.
    public function onUpdate(dc as Dc) as Void {
        var bg = getBackgroundColor();
        var fg = (bg == Graphics.COLOR_WHITE) ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;

        dc.setColor(fg, bg);
        dc.clear();
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);

        var width = dc.getWidth();
        var height = dc.getHeight();

        // Field label.
        dc.drawText(width / 2, 0, LABEL_FONT, LABEL_STRING, Graphics.TEXT_JUSTIFY_CENTER);

        // Big counter, vertically centered below the label.
        var numberText = _counter.toString();
        var numberY = (Graphics.getFontAscent(LABEL_FONT) + height) / 2;
        dc.drawText(width / 2, numberY, NUMBER_FONT, numberText,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Connect indicator dot in the top-right corner.
        var dotColor = _connected ? Graphics.COLOR_GREEN : Graphics.COLOR_RED;
        var dotX = width - DOT_PAD - DOT_RADIUS;
        var dotY = DOT_PAD + DOT_RADIUS;
        dc.setColor(dotColor, dotColor);
        dc.fillCircle(dotX, dotY, DOT_RADIUS);
    }
}
