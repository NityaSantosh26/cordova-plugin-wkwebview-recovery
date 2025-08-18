# WKWebView Recovery Plugin

A simple Cordova plugin that automatically recovers from WKWebView crashes (white screen) caused by the WebContent process being terminated by iOS.

## What This Plugin Does

This plugin automatically detects when the WKWebView WebContent process crashes and immediately reloads the current page to prevent white screen issues.

## How It Works

The plugin works by:
1. **Setting itself as the navigation delegate** of the WKWebView during initialization
2. **Detecting process termination** via `webViewWebContentProcessDidTerminate:` delegate method
3. **Automatically reloading** `www/index.html` from the currently active bundle (preserving SPA route/query) to recover from the crash

## Installation

```bash
cordova plugin add cordova-plugin-wkwebview-recovery
```

## Configuration

No configuration needed! The plugin works automatically after installation.

## Usage

The plugin works automatically - no JavaScript code needed. It will:
- Detect web content process crashes
- Automatically reload the current page to avoid white screen

### JavaScript Interface (Optional)

No JavaScript initialization is required. The plugin auto-initializes natively. A minimal namespace is exposed at `window.cordova.plugins.WKWebViewRecovery` for future use, but you do not need to call anything for recovery to work.

## Technical Details

### Key Methods (Objective‑C)

- `pluginInitialize` (CDVPlugin) — Called by Cordova when the plugin is created. Schedules setup on the main queue shortly after startup.
- `setupNavigationDelegate` (internal) — Grabs the app's `WKWebView`, remembers the existing `navigationDelegate`, and sets the plugin as the delegate so it can observe crash callbacks. If another delegate exists, we forward calls to it using Objective‑C forwarding.
- `respondsToSelector:` / `forwardingTargetForSelector:` — Ensures any navigation delegate methods not handled by this plugin get passed through to the original delegate to avoid breaking other plugins or app code.
- `webViewWebContentProcessDidTerminate:` (WKNavigationDelegate) — Invoked by WebKit when the WebContent process crashes. Computes the active `www/` base from the current URL and reloads `www/index.html` from that same base (works with CHCP/updated bundles). Falls back to `[webView reload]` if the URL cannot be determined.
- `dispose` (CDVPlugin) — Called when Cordova disposes the plugin. Cleans up by unsetting itself as `navigationDelegate` if needed.

### Recovery Logic

When a process crash is detected:
1. **Read current URL** - Determine active `.../www/` base
2. **Rebuild entry URL** - Load `.../www/index.html` with cache-busting, preserving query/hash for SPA routing
3. **Fallback** - If base cannot be determined, call `webView.reload()`

## Requirements

- iOS 9.0+
- Cordova iOS 6.0+
- WKWebView (default in modern Cordova apps)

## Troubleshooting

### Plugin Not Working

1. **Check console logs** - Look for `[WKWebViewRecovery]` messages
2. **Verify installation** - Ensure the plugin is properly installed
3. **Check WKWebView** - Ensure your app is using WKWebView, not UIWebView

### Common Issues

- **White screen still appears** - Check that the plugin is properly installed
- **No recovery happening** - Verify WKWebView is being used
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

## Future Enhancements

This is a simple starting point. Future versions may include:
- URL caching to restore the last known good page
- App foreground/background crash detection
- More sophisticated recovery strategies

## License

MIT License - see LICENSE file for details.
