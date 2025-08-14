var WKRouteRecovery = {
    saveRoute: function (route) {
        if (!window.cordova || !cordova.exec) return;
        cordova.exec(null, null, "WKRouteRecovery", "saveRoute", [route]);
    }
};

module.exports = WKRouteRecovery;
