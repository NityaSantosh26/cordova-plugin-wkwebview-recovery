# WKWebView Recovery Cordova Plugin

A Cordova iOS plugin that automatically recovers from WKWebView crashes (white screen) caused by the WebContent process being terminated by iOS.

## What it does

This plugin automatically detects and recovers from WKWebView crashes by:

1. **Monitoring URL changes** using Key-Value Observing (KVO)
2. **Detecting process termination** via `webViewWebContentProcessDidTerminate:`
3. **Handling app foreground transitions** to catch background-related crashes
4. **Automatically reloading** the last known good URL

## Why you need this

WKWebView's WebContent process can be terminated by iOS when:
- Memory pressure is high
- CPU usage is excessive
- App is backgrounded for extended periods
- System resources are constrained

When this happens, your Cordova app shows a white screen and becomes unresponsive. This plugin automatically detects these situations and recovers your app to the last working state.

## Features

- ✅ **Zero configuration** - Works automatically after installation
- ✅ **No JavaScript integration required** - No need to call any methods from your app
- ✅ **Comprehensive crash detection** - Handles both process termination and app foreground transitions
- ✅ **Smart URL recovery** - Restores the exact page you were on before the crash
- ✅ **Robust fallback chain** - Multiple recovery strategies ensure your app always recovers
- ✅ **Cordova-compatible** - Preserves all existing Cordova functionality and other plugins

## Installation

```bash
cordova plugin add cordova-plugin-wkwebview-recovery
```

## How it works

### 1. Automatic URL Tracking
The plugin uses KVO to monitor all URL changes in your WKWebView, automatically caching the last known good URL.

### 2. Crash Detection
- **Process Termination**: Listens for `webViewWebContentProcessDidTerminate:` delegate method
- **App Foreground**: Monitors `UIApplicationWillEnterForegroundNotification` to catch background-related crashes

### 3. Smart Recovery
When a crash is detected, the plugin follows this recovery strategy:
1. **Last Good URL** - Restore the most recently cached valid URL
2. **Current URL** - Fall back to the current URL if it's valid
3. **App URL** - Final fallback to your app's main entry point

### 4. Safe Integration
- Preserves the original navigation delegate to maintain Cordova functionality
- Forwards all delegate methods to ensure compatibility with other plugins
- Proper cleanup of observers and notifications

## Requirements

- iOS 13.0+
- Cordova iOS 6.0+
- WKWebView (default in modern Cordova apps)

## Usage

Simply install the plugin - no additional code required! The plugin works automatically in the background.

```bash
# Install the plugin
cordova plugin add cordova-plugin-wkwebview-recovery

# Build your app
cordova build ios
```

## Testing

To test the recovery functionality:

1. **Memory Pressure Test**: Use Xcode's Memory Graph Debugger to simulate memory pressure
2. **Background Test**: Put your app in background for extended periods
3. **Process Termination**: Use Xcode's Debug > Simulate Background App Refresh

## Logging

The plugin provides detailed logging to help with debugging:

```
[WKWebViewRecovery] Initialized and tracking URLs
[WKWebViewRecovery] Cached good URL: file:///var/containers/Bundle/Application/.../index.html#/dashboard
[WKWebViewRecovery] Process terminated — attempting recovery
[WKWebViewRecovery] Using last good URL: file:///var/containers/Bundle/Application/.../index.html#/dashboard
```

## Troubleshooting

### White screen still appears
- Ensure you're using WKWebView (not UIWebView)
- Check that the plugin is properly installed in your `config.xml`
- Verify iOS version compatibility (iOS 13+)

### App crashes on startup
- Check for conflicts with other WKWebView-related plugins
- Ensure proper delegate forwarding is working

### Recovery not working
- Check console logs for recovery attempts
- Verify that valid URLs are being cached
- Test with a simple URL first

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## Support

For issues and questions:
- Check the troubleshooting section above
- Review the console logs for error messages
- Open an issue on GitHub with detailed reproduction steps
