import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Data field that renders the live bonus-button counter and a connect
//! indicator (green = receiving, red = no lock).
class AXSCounterField extends WatchUi.DataField {
    private const PAD = 2;
    private const LABEL_STRING = "Counter";
    private const LABEL_FONT = Graphics.FONT_TINY;
    private const NUMBER_FONT = Graphics.FONT_NUMBER_HOT;
    private const DOT_RADIUS = 3;

    private var _counter as Number = 0;
    private var _connected as Boolean = false;
    private var _listener as AXSButtonListener?;

    //! Constructor.
    public function initialize() {
        DataField.initialize();
        _counter = 0;
        _connected = false;
        _listener = null;
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
        WatchUi.requestUpdate();
    }

    //! Set the connection indicator.
    //! @param connected True while page-2 frames are actually arriving.
    public function setConnected(connected as Boolean) as Void {
        _connected = connected;
        WatchUi.requestUpdate();
    }

    //! Called by the framework once per second while the app runs.
    //! Drives the listener's stale-frame check (red dot when the shifter
    //! stops broadcasting).
    //! @param info The current activity info (unused).
    public function compute(info as Activity.Info) as Void {
        if (_listener != null) {
            _listener.tick();
        }
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
        var dotX = width - PAD - DOT_RADIUS;
        var dotY = PAD + DOT_RADIUS;
        dc.setColor(dotColor, dotColor);
        dc.fillCircle(dotX, dotY, DOT_RADIUS);
    }
}
