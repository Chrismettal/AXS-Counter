import Toybox.Ant;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! Data field that displays raw ANT+ frames captured by the sniffer channel.
//!
//! Shows the most recent captured frame as an 8-byte hex dump plus the source
//! device number and type, and a short history of the previous frames. Press
//! the SRAM bonus button (action 3 = both) while the field is visible and the
//! matching payload will be visible in the history.
class SnifferField extends WatchUi.DataField {
    private const PAD = 2;
    private const LABEL_STRING = "AXS SNIF";
    private const LABEL_FONT = Graphics.FONT_XTINY;
    private const HEX_FONT = Graphics.FONT_XTINY;
    private const ID_FONT = Graphics.FONT_XTINY;
    private const HEX_CHARS = "0123456789ABCDEF";

    private var _channel as SnifferChannel?;

    //! Constructor.
    //! @param channel The sniffer channel (may be null if it could not open).
    public function initialize(channel as SnifferChannel?) {
        DataField.initialize();
        _channel = channel;
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

        var channel = _channel;
        if (channel == null) {
            dc.drawText(width / 2, height / 2, Graphics.FONT_TINY, "NO CHANNEL", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var count = channel.getFrameCount();
        if (count == 0) {
            dc.drawText(width / 2, height / 2, Graphics.FONT_TINY, "SCANNING", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(width / 2, height - 4, ID_FONT, "rx " + channel.getRxCount(), Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        // Draw the newest frame (full) plus the previous ones (compact).
        var y = Graphics.getFontAscent(LABEL_FONT) + PAD;
        for (var i = 0; i < count; i++) {
            var frame = channel.getFrame(i);
            var hex = hexBytes(frame.payload);
            var idLine = "d" + hex16(frame.deviceNumber) + " t" + hex8(frame.deviceType);
            if (i == 0) {
                dc.drawText(PAD, y, HEX_FONT, hex, Graphics.TEXT_JUSTIFY_LEFT);
                y += Graphics.getFontAscent(HEX_FONT) + 1;
                dc.drawText(PAD, y, ID_FONT, idLine, Graphics.TEXT_JUSTIFY_LEFT);
                y += Graphics.getFontAscent(ID_FONT) + 2;
            } else {
                dc.drawText(PAD, y, ID_FONT, idLine + " " + hex, Graphics.TEXT_JUSTIFY_LEFT);
                y += Graphics.getFontAscent(ID_FONT) + 1;
            }
        }

        // Frame counter in the corner.
        dc.drawText(width - PAD, height - 4, ID_FONT, "rx " + channel.getRxCount(), Graphics.TEXT_JUSTIFY_RIGHT);
    }

    //! Format an array of bytes as a space-separated hex string.
    private function hexBytes(bytes as Array<Number>) as String {
        var s = "";
        for (var i = 0; i < bytes.size(); i++) {
            var b = bytes[i];
            if (b < 0) {
                b += 256;
            }
            if (i > 0) {
                s += " ";
            }
            s += HEX_CHARS.substring(Math.floor(b / 16), Math.floor(b / 16) + 1);
            s += HEX_CHARS.substring(b % 16, b % 16 + 1);
        }
        return s;
    }

    //! Format a 16-bit value as 4 hex digits.
    private function hex16(value as Number) as String {
        return hex8(Math.floor(value / 256)) + hex8(value % 256);
    }

    //! Format an 8-bit value as 2 hex digits.
    private function hex8(value as Number) as String {
        var v = value % 256;
        if (v < 0) {
            v += 256;
        }
        return HEX_CHARS.substring(Math.floor(v / 16), Math.floor(v / 16) + 1) +
               HEX_CHARS.substring(v % 16, v % 16 + 1);
    }
}
