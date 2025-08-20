# WKWebView Recovery Plugin

A simple Cordova plugin that automatically recovers from WKWebView crashes (white screen) caused by the WebContent process being terminated by iOS.

## What This Plugin Does

This plugin automatically detects when the WKWebView WebContent process crashes and immediately reloads the current page to prevent white screen issues. It also provides a JavaScript interface to receive crash event details on the client side.

## How It Works

The plugin works by:
1. **Setting itself as the navigation delegate** of the WKWebView during initialization
2. **Detecting process termination** via `webViewWebContentProcessDidTerminate:` delegate method
3. **Automatically reloading** `www/index.html` from the currently active bundle (preserving SPA route/query) to recover from the crash
4. **Emitting crash events** to JavaScript with detailed crash information for monitoring and analytics

## Installation

```bash
cordova plugin add cordova-plugin-wkwebview-recovery
```

## Configuration

No configuration needed! The plugin works automatically after installation.

## Usage

### Automatic Recovery (Default Behavior)

The plugin works automatically - no JavaScript code needed. It will:
- Detect web content process crashes
- Automatically reload the current page to avoid white screen

### JavaScript Interface (Optional)

The plugin exposes a JavaScript API for receiving crash event details and monitoring recovery actions:

```javascript
// Get the plugin instance
var recovery = window.cordova.plugins.WKWebViewRecovery;

// Subscribe to crash events
var unsubscribe = recovery.onEvent(function(event) {
    console.log('Crash event received:', event);
    
    // Event object contains:
    // - type: "crash"
    // - reason: Description of what caused the crash
    // - iosVersion: iOS version where crash occurred
    // - model: Device model
    // - appVersion: App version
    // - timestamp: Unix timestamp in milliseconds
    
    // Handle the crash event (e.g., send to analytics, show user notification, etc.)
    if (event.type === 'crash') {
        // Send crash data to your analytics service
        analytics.track('wkwebview_crash', {
            reason: event.reason,
            device: event.model,
            iosVersion: event.iosVersion,
            appVersion: event.appVersion,
            timestamp: event.timestamp
        });
        
        // Optionally show user notification
        showCrashNotification(event.reason);
    }
});

// Unsubscribe when no longer needed
// unsubscribe();
```

#### Event Object Structure

When a crash occurs, the event object contains:

```javascript
{
    type: "crash",
    reason: "WebContent process crashed", // or "App entering foreground fallback"
    iosVersion: "16.0",
    model: "iPhone",
    appVersion: "1.0.0",
    timestamp: 1703123456789
}
```

#### Common Use Cases

1. **Analytics and Monitoring**
   ```javascript
   recovery.onEvent(function(event) {
       if (event.type === 'crash') {
           // Send to your crash reporting service
           Sentry.captureException(new Error(`WKWebView crash: ${event.reason}`), {
               tags: {
                   device: event.model,
                   iosVersion: event.iosVersion,
                   appVersion: event.appVersion
               }
           });
       }
   });
   ```

2. **User Experience Improvements**
   ```javascript
   recovery.onEvent(function(event) {
       if (event.type === 'crash') {
           // Show user-friendly message
           showToast('App recovered from a temporary issue. Please continue.');
           
           // Track recovery success
           trackRecoverySuccess();
       }
   });
   ```

3. **Debugging and Development**
   ```javascript
   recovery.onEvent(function(event) {
       console.group('WKWebView Recovery Event');
       console.log('Event:', event);
       console.log('Current URL:', window.location.href);
       console.log('User Agent:', navigator.userAgent);
       console.groupEnd();
   });
   ```

## Technical Details

### Key Methods (Objective‑C)

- `pluginInitialize` (CDVPlugin) — Called by Cordova when the plugin is created. Schedules setup on the main queue shortly after startup.
- `setupNavigationDelegate` (internal) — Grabs the app's `WKWebView`, remembers the existing `navigationDelegate`, and sets the plugin as the delegate so it can observe crash callbacks. If another delegate exists, we forward calls to it using Objective‑C forwarding.
- `respondsToSelector:` / `forwardingTargetForSelector:` — Ensures any navigation delegate methods not handled by this plugin get passed through to the original delegate to avoid breaking other plugins or app code.
- `webViewWebContentProcessDidTerminate:` (WKNavigationDelegate) — Invoked by WebKit when the WebContent process crashes. Computes the active `www/` base from the current URL and reloads `www/index.html` from that same base (works with CHCP/updated bundles). Falls back to `[webView reload]` if the URL cannot be determined.
- `emitCrashEventWithReason:` (internal) — Emits crash events to JavaScript with device and crash information.
- `subscribe:` (Cordova bridge) — Handles JavaScript subscription to crash events.
- `dispose` (CDVPlugin) — Called when Cordova disposes the plugin. Cleans up by unsetting itself as `navigationDelegate` if needed.

### JavaScript API (www/WKWebViewRecovery.js)

- `onEvent(callback)` — Subscribe to crash events. Returns an unsubscribe function.
- `ensureSubscribed()` (internal) — Sets up the native event subscription.
- Event listeners are automatically managed and cleaned up.

### Recovery Logic

When a process crash is detected:
1. **Emit crash event** - Send crash details to JavaScript before reload
2. **Read current URL** - Determine active `.../www/` base
3. **Rebuild entry URL** - Load `.../www/index.html` with cache-busting, preserving query/hash for SPA routing
4. **Fallback** - If base cannot be determined, call `webView.reload()`

### Crash Event Flow

1. **Crash Detection** - Native code detects WebContent process termination
2. **Event Emission** - Crash details are sent to JavaScript via Cordova bridge
3. **Page Reload** - Current page is automatically reloaded to recover
4. **Event Delivery** - If JavaScript wasn't ready, events are queued and delivered after reinitialization

## Requirements

- iOS 9.0+
- Cordova iOS 6.0+
- WKWebView (default in modern Cordova apps)

## Troubleshooting

### Plugin Not Working

1. **Check console logs** - Look for `[WKWebViewRecovery]` messages
2. **Verify installation** - Ensure the plugin is properly installed
3. **Check WKWebView** - Ensure your app is using WKWebView, not UIWebView

### JavaScript Events Not Working

1. **Check subscription** - Ensure you're calling `recovery.onEvent()` after `deviceready`
2. **Verify plugin loading** - Check that `window.cordova.plugins.WKWebViewRecovery` exists
3. **Check console errors** - Look for JavaScript errors that might prevent event handling

### Common Issues

- **White screen still appears** - Check that the plugin is properly installed
- **No recovery happening** - Verify WKWebView is being used
- **Events not received** - Ensure JavaScript subscription happens after `deviceready`
- **App crashes** - Check for conflicts with other plugins

### Specific Error Solutions

#### Process Termination Error
If you see: `Failed to terminate process: Error Domain=com.apple.extensionKit.errorDomain Code=18`
- This is usually a simulator issue, not a plugin problem
- Try running on a real device instead of simulator
- Restart Xcode and clean build folder

#### Module Already Defined Error
If you see: `Error: module cordova-plugin-wkwebview-recovery.WKWebViewRecovery already defined`
- The plugin JavaScript is being loaded multiple times
- Try removing and re-adding the plugin: `cordova plugin remove cordova-plugin-wkwebview-recovery && cordova plugin add cordova-plugin-wkwebview-recovery`
- Clean and rebuild your project

#### White Screen After Plugin Installation
- Check that the plugin is properly listed in your `config.xml`
- Verify the plugin appears in Xcode project navigator
- Look for `[WKWebViewRecovery]` logs in Xcode console

#### JavaScript Events Not Working
- Ensure you're calling `onEvent()` after the `deviceready` event
- Check that the plugin JavaScript is properly loaded
- Verify no JavaScript errors are preventing event handling

## Future Enhancements

This is a simple starting point. Future versions may include:
- URL caching to restore the last known good page
- App foreground/background crash detection
- More sophisticated recovery strategies
- Additional event types (recovery success, recovery failure, etc.)
- Configurable recovery behavior

## License

MIT License - see LICENSE file for details.
