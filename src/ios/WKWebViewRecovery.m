#import "WKWebViewRecovery.h"

@implementation WKWebViewRecovery

- (void)pluginInitialize {
    NSLog(@"[WKWebViewRecovery] Plugin initializing...");
    
    // Wait a bit for the web view to be fully initialized
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self setupNavigationDelegate];
    });

    // Observe app foreground to handle potential white-screen cases
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onAppWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
}

- (void)setupNavigationDelegate {
    @try {
        // Get the web view from the main view controller
        if (self.webView && [self.webView isKindOfClass:[WKWebView class]]) {
            self.wkWebView = (WKWebView *)self.webView;
            NSLog(@"[WKWebViewRecovery] Got WKWebView reference");
            
            // Capture previous delegate
            self.previousNavigationDelegate = self.wkWebView.navigationDelegate;
            if (self.previousNavigationDelegate) {
                NSLog(@"[WKWebViewRecovery] Previous delegate: %@", NSStringFromClass([self.previousNavigationDelegate class]));
            }
            
            // Only set delegate if we're not already the delegate
            if (self.wkWebView.navigationDelegate != self) {
                self.wkWebView.navigationDelegate = self;
                NSLog(@"[WKWebViewRecovery] Set self as navigation delegate");
            } else {
                NSLog(@"[WKWebViewRecovery] Already the navigation delegate");
            }
            
            NSLog(@"[WKWebViewRecovery] Plugin initialized successfully");
        } else {
            NSLog(@"[WKWebViewRecovery] WebView is not WKWebView: %@", NSStringFromClass([self.webView class]));
        }
    } @catch (NSException *exception) {
        NSLog(@"[WKWebViewRecovery] Error setting up navigation delegate: %@", exception.reason);
    }
}

#pragma mark - Reload Logic

- (void)performReloadForWebView:(WKWebView *)webView reason:(NSString *)reason crashed:(BOOL)crashed {
    if (!webView) {
        NSLog(@"[WKWebViewRecovery] Cannot reload: webView is nil (reason: %@)", reason ?: @"unknown");
        return;
    }

    NSLog(@"[WKWebViewRecovery] Triggering reload (reason: %@)", reason ?: @"unknown");
    NSLog(@"[WKWebViewRecovery] Current URL before reload: %@", webView.URL.absoluteString);

    // Emit analytics before reload. Only send if this is a crash case.
    if (crashed) {
        [self emitCrashEventWithReason:reason beforeReload:YES];
    }

    NSURL *reloadURL = nil;

    if (webView.URL && ![webView.URL.absoluteString isEqualToString:@"about:blank"]) {
        NSString *absolute = webView.URL.absoluteString;
        NSRange range = [absolute rangeOfString:@"www/"];
        if (range.location != NSNotFound) {
            NSString *base = [absolute substringToIndex:range.location + range.length];
            NSString *reloadURLString = [NSString stringWithFormat:@"%@index.html", base];
            reloadURL = [NSURL URLWithString:reloadURLString];
        }
    }

    if (reloadURL) {
        NSLog(@"[WKWebViewRecovery] Loading URL: %@", reloadURL.absoluteString);
        NSURLRequest *req = [NSURLRequest requestWithURL:reloadURL
                                             cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                         timeoutInterval:20.0];
        [webView loadRequest:req];
    } else {
        NSLog(@"[WKWebViewRecovery] Reload URL could not be determined; calling reload");
        [webView reload];
    }
}

#pragma mark - Navigation Delegate

- (BOOL)respondsToSelector:(SEL)aSelector {
    if ([super respondsToSelector:aSelector]) return YES;
    return [self.previousNavigationDelegate respondsToSelector:aSelector];
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    if ([self.previousNavigationDelegate respondsToSelector:aSelector]) {
        return self.previousNavigationDelegate;
    }
    return [super forwardingTargetForSelector:aSelector];
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    NSLog(@"[WKWebViewRecovery] WebContent process terminated (crashed)");
    [self performReloadForWebView:webView reason:@"WebContent process crashed" crashed:YES];
}

// (No other delegate methods required)

#pragma mark - App Lifecycle

- (void)onAppWillEnterForeground:(NSNotification*)notification {
    NSLog(@"[WKWebViewRecovery] App will enter foreground");
    if (!self.wkWebView) {
        NSLog(@"[WKWebViewRecovery] No WKWebView reference available on foreground entry");
        return;
    }

    NSURL *currentURL = self.wkWebView.URL;
    BOOL hasValidURL = (currentURL != nil) && ![currentURL.absoluteString isEqualToString:@"about:blank"];
    if (!hasValidURL) {
        // Treat this as a crash fallback: white screen/blank URL upon foreground
        [self performReloadForWebView:self.wkWebView reason:@"App entering foreground fallback" crashed:YES];
    } else {
        NSLog(@"[WKWebViewRecovery] Skipping reload on foreground: URL is valid");
    }
}

#pragma mark - Cleanup

- (void)dispose {
    NSLog(@"[WKWebViewRecovery] Cleaning up plugin");
    
    // Reset navigation delegate if we're still the delegate
    if (self.wkWebView && self.wkWebView.navigationDelegate == self) {
        self.wkWebView.navigationDelegate = nil;
        NSLog(@"[WKWebViewRecovery] Reset navigation delegate");
    }
    
    // Remove app lifecycle observer
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];

    [super dispose];
}

/*
 * MARK: - Cordova bridge API
 */

- (void)subscribe:(CDVInvokedUrlCommand *)command {
    // Save callbackId for continuous event stream
    self.eventCallbackId = command.callbackId;

    // If a crash happened just before reload and JS is now back, deliver pending info
    if (self.pendingCrashInfo != nil) {
        [self sendEvent:self.pendingCrashInfo keepCallback:YES];
        self.pendingCrashInfo = nil;
    }
}

// Removed getEnvironment to keep the surface area minimal

#pragma mark - Internal event helpers

- (void)emitCrashEventWithReason:(NSString *)reason beforeReload:(BOOL)beforeReload {
    UIDevice *device = [UIDevice currentDevice];
    NSDictionary *payload = @{ @"type": @"crash",
                               @"crashed": @YES,
                               @"reason": reason ?: @"",
                               @"phase": beforeReload ? @"beforeReload" : @"afterReload",
                               @"iosVersion": device.systemVersion ?: @"",
                               @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000) };

    // When the content process is terminated or we're about to reload, the JS bridge is not reliable.
    // Queue the event to deliver after the app reinitializes and re-subscribes.
    if (beforeReload) {
        self.pendingCrashInfo = payload;
        return;
    }

    if (self.eventCallbackId != nil) {
        [self sendEvent:payload keepCallback:YES];
    } else {
        self.pendingCrashInfo = payload;
    }
}

- (void)sendEvent:(NSDictionary *)event keepCallback:(BOOL)keep {
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:event];
    [result setKeepCallbackAsBool:keep];
    [self.commandDelegate sendPluginResult:result callbackId:self.eventCallbackId];
}

@end
