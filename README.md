# WK Route Recovery Cordova Plugin

A Cordova iOS plugin that recovers the last viewed route in a **Single Page Application (SPA)** after a WKWebView crash (white screen) caused by the WebContent process being terminated by iOS.

## Features
- Hooks into WKWebView's `webViewWebContentProcessDidTerminate:` to detect crashes.
- Reloads the Cordova app's start page (`index.html`) after crash.
- Restores the last known internal route of your SPA by injecting JavaScript after reload.
- Works with Angular, React, Vue, or any client-side router.

## Why?
WKWebView's WebContent process can be terminated by iOS when memory usage or CPU load is high, causing a white screen in Cordova apps.  
By default, a reload will just take you back to `index.html`.  
This plugin remembers the last route so you land back where you were before the crash.

## Installation
```bash
cordova plugin add cordova-plugin-wk-route-recovery
