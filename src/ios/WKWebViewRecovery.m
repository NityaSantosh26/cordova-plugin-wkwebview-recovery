#import "WKWebViewRecovery.h"

@implementation WKWebViewRecovery

- (void)pluginInitialize {
    NSLog(@"[WKWebViewRecovery] Plugin initializing...");
    
    // Wait a bit for the web view to be fully initialized
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self setupNavigationDelegate];
    });
}

- (void)setupNavigationDelegate {
    @try {
        // Get the web view from the main view controller
        if (self.webView && [self.webView isKindOfClass:[WKWebView class]]) {
            self.wkWebView = (WKWebView *)self.webView;
            NSLog(@"[WKWebViewRecovery] ✅ Got WKWebView reference");
            
            // Capture previous delegate
            self.previousNavigationDelegate = self.wkWebView.navigationDelegate;
            if (self.previousNavigationDelegate) {
                NSLog(@"[WKWebViewRecovery] Previous delegate: %@", NSStringFromClass([self.previousNavigationDelegate class]));
            }
            
            // Only set delegate if we're not already the delegate
            if (self.wkWebView.navigationDelegate != self) {
                self.wkWebView.navigationDelegate = self;
                NSLog(@"[WKWebViewRecovery] ✅ Set self as navigation delegate");
            } else {
                NSLog(@"[WKWebViewRecovery] ⚠️ Already the navigation delegate");
            }
            
            NSLog(@"[WKWebViewRecovery] ✅ Plugin initialized successfully");
        } else {
            NSLog(@"[WKWebViewRecovery] ❌ WebView is not WKWebView: %@", NSStringFromClass([self.webView class]));
        }
    } @catch (NSException *exception) {
        NSLog(@"[WKWebViewRecovery] ❌ Error setting up navigation delegate: %@", exception.reason);
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
    NSLog(@"[WKWebViewRecovery] 🚨🚨🚨 PROCESS TERMINATED - WebContent process crashed! 🚨🚨🚨");
    NSLog(@"[WKWebViewRecovery] Current URL at termination: %@", webView.URL.absoluteString);
    
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
        NSLog(@"[WKWebViewRecovery] 🔄 Reloading with URL: %@", reloadURL.absoluteString);
        NSURLRequest *req = [NSURLRequest requestWithURL:reloadURL
                                             cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                         timeoutInterval:20.0];
        [webView loadRequest:req];
    } else {
        NSLog(@"[WKWebViewRecovery] ⚠️ Could not determine reload URL, falling back to reload");
        [webView reload];
    }
}

// (No other delegate methods required)

#pragma mark - Cleanup

- (void)dispose {
    NSLog(@"[WKWebViewRecovery] 🧹 Cleaning up plugin");
    
    // Reset navigation delegate if we're still the delegate
    if (self.wkWebView && self.wkWebView.navigationDelegate == self) {
        self.wkWebView.navigationDelegate = nil;
        NSLog(@"[WKWebViewRecovery] ✅ Reset navigation delegate");
    }
    
    [super dispose];
}

@end
