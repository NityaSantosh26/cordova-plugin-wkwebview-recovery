var exec = require('cordova/exec');

var listeners = [];
var lastEvent = null;

function ensureSubscribed() {
    exec(function (event) {
        lastEvent = event;
        for (var i = 0; i < listeners.length; i++) {
            try { listeners[i](event); } catch (e) { /* swallow */ }
        }
    }, function (err) {
        // No-op; keep callback alive regardless
    }, 'WKWebViewRecovery', 'subscribe', []);
}

var api = {
    onEvent: function (fn) {
        if (typeof fn === 'function') {
            if (listeners.length === 0) {
                ensureSubscribed();
            }
            listeners.push(fn);
            if (lastEvent) {
                try { fn(lastEvent); } catch (e) {}
            }
        }
        return function unsubscribe() {
            var idx = listeners.indexOf(fn);
            if (idx >= 0) listeners.splice(idx, 1);
        };
    }
};

module.exports = api;
