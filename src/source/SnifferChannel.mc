import Toybox.Ant;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! A single captured ANT+ frame (device id + 8-byte payload).
class SnifferFrame {
    var deviceNumber as Number = 0;
    var deviceType as Number = 0;
    var transmissionType as Number = 0;
    var payload as Array<Number> = [];

    public function initialize() {
        deviceNumber = 0;
        deviceType = 0;
        transmissionType = 0;
        payload = [];
    }
}

//! Raw ANT+ background-scan channel for the Überholzähler sniffer.
//!
//! Opens a receive-only ANT+ channel with background scanning enabled and an
//! all-wildcard channel id (device number / type / transmission type = 0).
//! This eavesdrops on every nearby ANT+ broadcast without pairing, so it can
//! capture the SRAM Force AXS shifting channel (device type 0x22) button
//! events even though the Edge is already paired to the SRAM on its own
//! built-in channel.
//!
//! Frames are kept in a small ring buffer so a transient button-event payload
//! can be read after the fact.
class SnifferChannel extends Ant.GenericChannel {
    //! ANT+ RF frequency (2457 MHz).
    private const RF_FREQUENCY = 57;
    //! Default ANT+ message period (4 Hz).
    private const MESSAGE_PERIOD = 8192;
    //! Low-priority search timeout, in 2.5 s units (10 * 2.5 s = 25 s).
    private const SEARCH_TIMEOUT_LOW = 10;
    //! Number of recent frames to keep for display.
    private const FRAME_BUFFER_SIZE = 4;

    private var _frames as Array<SnifferFrame>;
    private var _head as Number = 0;
    private var _rxCount as Number = 0;

    //! Constructor.
    public function initialize() {
        // Receive-only channel on the ANT+ network, background scan enabled.
        var chanAssign = new Ant.ChannelAssignment(
            Ant.CHANNEL_TYPE_RX_ONLY,
            Ant.NETWORK_PLUS);
        chanAssign.setBackgroundScan(true);
        GenericChannel.initialize(method(:onMessage), chanAssign);

        // All-wildcard channel id: capture every nearby ANT+ broadcast.
        var deviceCfg = new Ant.DeviceConfig({
            :deviceNumber => 0,
            :deviceType => 0,
            :transmissionType => 0,
            :messagePeriod => MESSAGE_PERIOD,
            :radioFrequency => RF_FREQUENCY,
            :searchTimeoutLowPriority => SEARCH_TIMEOUT_LOW,
            :searchThreshold => 0});
        GenericChannel.setDeviceConfig(deviceCfg);

        _frames = new Array<SnifferFrame>[FRAME_BUFFER_SIZE];
        for (var i = 0; i < FRAME_BUFFER_SIZE; i++) {
            _frames[i] = new SnifferFrame();
        }
        _head = 0;
        _rxCount = 0;
    }

    //! Open the channel and reset the capture state.
    public function open() as Boolean {
        var result = GenericChannel.open();
        _head = 0;
        _rxCount = 0;
        return result;
    }

    //! Close the channel.
    public function close() as Boolean {
        return GenericChannel.close();
    }

    //! ANT message handler.
    //! @param msg The message received on the channel.
    public function onMessage(msg as Ant.Message) as Void {
        var messageId = msg.messageId;
        if ((messageId == Ant.MSG_ID_BROADCAST_DATA) || (messageId == Ant.MSG_ID_ACKNOWLEDGED_DATA)) {
            var src = msg.getPayload();
            if (src != null) {
                var frame = new SnifferFrame();
                frame.deviceNumber = (msg.deviceNumber != null) ? msg.deviceNumber : 0;
                frame.deviceType = (msg.deviceType != null) ? msg.deviceType : 0;
                frame.transmissionType = (msg.transmissionType != null) ? msg.transmissionType : 0;

                // Copy the payload so it is not affected by stack buffer reuse.
                var copy = [] as Array<Number>;
                var n = src.size();
                if (n > 8) {
                    n = 8;
                }
                for (var i = 0; i < n; i++) {
                    copy.add(src[i]);
                }
                frame.payload = copy;

                _frames[_head] = frame;
                _head = (_head + 1) % FRAME_BUFFER_SIZE;
                _rxCount++;
                WatchUi.requestUpdate();
            }
        } else if (messageId == Ant.MSG_ID_RF_EVENT) {
            var payload = msg.getPayload();
            if ((payload != null) && (payload.size() > 1) && (payload[1] == Ant.MSG_CODE_EVENT_CHANNEL_CLOSED)) {
                // Channel dropped; reopen so the sniffer keeps listening.
                GenericChannel.open();
            }
        }
    }

    //! Total broadcast/acknowledged frames received since open.
    public function getRxCount() as Number {
        return _rxCount;
    }

    //! Number of valid frames currently in the buffer.
    public function getFrameCount() as Number {
        if (_rxCount < FRAME_BUFFER_SIZE) {
            return _rxCount;
        }
        return FRAME_BUFFER_SIZE;
    }

    //! Return a frame from the ring buffer.
    //! @param newestIndex 0 = newest frame, 1 = next newest, and so on.
    public function getFrame(newestIndex as Number) as SnifferFrame {
        var idx = _head - 1 - newestIndex;
        idx = idx % FRAME_BUFFER_SIZE;
        if (idx < 0) {
            idx += FRAME_BUFFER_SIZE;
        }
        return _frames[idx];
    }
}
