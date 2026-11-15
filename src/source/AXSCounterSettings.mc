import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! On-device settings for the AXS-Counter data field.
//!
//! Data fields cannot push arbitrary views during normal operation, but
//! `AppBase.getSettingsView()` is the sanctioned exception: the framework
//! shows it when the field is added to a data page (the "configure this
//! field?" prompt) and from the data page menu ("ConnectIQ Fields" entry,
//! reached by swiping up on the Edge). Unlike the phone settings dialog
//! (which requires the app to be in the Connect IQ App Store), this works
//! with **sideloaded** apps.
//!
//! The Edge 1050 has no Menu button (only Start and Lap), so the settings
//! open *directly into the root menu* instead of a "Press Menu" placeholder
//! view.
//!
//! The three actions (increment / decrement / reset) each open a submenu
//! with 17 options (Unassigned + FS 1-8 x short/long). The choice is stored
//! in the same app properties the phone dialog would use
//! (`actionIncrement` / `actionDecrement` / `actionReset`, see
//! properties.xml), so both paths edit the same values. After a change the
//! running listener is reloaded directly, so the new binding is active
//! immediately.
//!
//! Binding encoding (shared with properties.xml and the listener):
//! 0 = unassigned, 1-8 = FS 1-8 short press, 9-16 = FS 1-8 long press.
//!
//! NOTE: shared constants are declared at module scope (top level) and
//! referenced as `$.CONST`, because class-scope `const` is not reachable as
//! `ClassName.CONST` by this compiler (the SDK samples use module scope for
//! exactly this reason).

//! Action ids used as menu item identifiers (module scope, shared).
const ACTION_INCREMENT = 1;
const ACTION_DECREMENT = 2;
const ACTION_RESET = 3;

//! Option labels indexed by binding value (0 = unassigned, 1-8 short, 9-16 long).
const BINDING_LABELS = [
    $.Rez.Strings.SettingUnassigned,
    $.Rez.Strings.SettingFS1Short, $.Rez.Strings.SettingFS2Short, $.Rez.Strings.SettingFS3Short,
    $.Rez.Strings.SettingFS4Short, $.Rez.Strings.SettingFS5Short, $.Rez.Strings.SettingFS6Short,
    $.Rez.Strings.SettingFS7Short, $.Rez.Strings.SettingFS8Short,
    $.Rez.Strings.SettingFS1Long, $.Rez.Strings.SettingFS2Long, $.Rez.Strings.SettingFS3Long,
    $.Rez.Strings.SettingFS4Long, $.Rez.Strings.SettingFS5Long, $.Rez.Strings.SettingFS6Long,
    $.Rez.Strings.SettingFS7Long, $.Rez.Strings.SettingFS8Long
];

//! Action titles indexed by (action id - 1).
const ACTION_TITLES = [
    $.Rez.Strings.SettingIncrementTitle,
    $.Rez.Strings.SettingDecrementTitle,
    $.Rez.Strings.SettingResetTitle
];

//! Root menu: one item per action; the sub-label shows the current binding.
class AXSCounterSettingsMenu extends WatchUi.Menu2 {
    //! Constructor: builds the three action items with their current values.
    public function initialize() {
        Menu2.initialize({:title => $.Rez.Strings.AppName});
        addItem(new WatchUi.MenuItem($.Rez.Strings.SettingIncrementTitle,
                    labelFor(Properties.getValue($.PROP_INCREMENT)),
                    $.ACTION_INCREMENT, null));
        addItem(new WatchUi.MenuItem($.Rez.Strings.SettingDecrementTitle,
                    labelFor(Properties.getValue($.PROP_DECREMENT)),
                    $.ACTION_DECREMENT, null));
        addItem(new WatchUi.MenuItem($.Rez.Strings.SettingResetTitle,
                    labelFor(Properties.getValue($.PROP_RESET)),
                    $.ACTION_RESET, null));
    }

    //! @param value The raw property value (a Number, or null if unset).
    private function labelFor(value as Object) as ResourceId {
        if (!(value instanceof Number)) {
            return $.Rez.Strings.SettingUnassigned;
        }
        var binding = value as Number;
        if ((binding < 0) || (binding > 16)) {
            return $.Rez.Strings.SettingUnassigned;
        }
        return $.BINDING_LABELS[binding];
    }
}

//! Pushes the binding submenu for the selected action.
class AXSCounterSettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _listener as AXSButtonListener?;

    //! @param listener The running counter listener (null if the app is not started).
    public function initialize(listener as AXSButtonListener?) {
        Menu2InputDelegate.initialize();
        _listener = listener;
    }

    //! @param item The selected action item.
    public function onSelect(item as MenuItem) as Void {
        var actionId = item.getId() as Number;
        var menu = new AXSCounterBindingMenu(actionId);
        WatchUi.pushView(menu, new AXSCounterBindingMenuDelegate(actionId, _listener),
                         WatchUi.SLIDE_IMMEDIATE);
    }
}

//! Submenu with the 17 binding options for one action.
class AXSCounterBindingMenu extends WatchUi.Menu2 {
    //! @param actionId One of $.ACTION_*.
    public function initialize(actionId as Number) {
        Menu2.initialize({:title => $.ACTION_TITLES[actionId - 1]});
        for (var binding = 0; binding <= 16; binding++) {
            addItem(new WatchUi.MenuItem($.BINDING_LABELS[binding], null, binding, null));
        }
    }
}

//! Stores the chosen binding and reloads the listener.
class AXSCounterBindingMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _actionId as Number;
    private var _listener as AXSButtonListener?;

    //! @param actionId One of $.ACTION_*.
    //! @param listener The running counter listener (null if the app is not started).
    public function initialize(actionId as Number, listener as AXSButtonListener?) {
        Menu2InputDelegate.initialize();
        _actionId = actionId;
        _listener = listener;
    }

    //! @param item The selected binding option (id = binding value).
    public function onSelect(item as MenuItem) as Void {
        var value = item.getId() as Number;
        var key = propertyKeyFor(_actionId);
        Properties.setValue(key, value);
        System.println("AXSButton: setting " + key + " = " + value);
        if (_listener != null) {
            _listener.onSettingsChanged();
        }
        // Back to the root menu; the user leaves the settings with Back.
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

    //! @param actionId One of $.ACTION_*.
    private function propertyKeyFor(actionId as Number) as String {
        if (actionId == $.ACTION_INCREMENT) {
            return $.PROP_INCREMENT;
        }
        if (actionId == $.ACTION_DECREMENT) {
            return $.PROP_DECREMENT;
        }
        return $.PROP_RESET;
    }
}
