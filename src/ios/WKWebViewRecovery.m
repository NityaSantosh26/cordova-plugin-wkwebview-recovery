#import <Cordova/CDV.h>
#import <WebKit/WebKit.h>

@interface WKWebViewRecovery : CDVPlugin <WKNavigationDelegate>
@property (nonatomic, strong) NSURL *lastGoodURL;
@property (nonatomic, strong) WKWebView *wkWebView;
@property (nonatomic, weak) id<WKNavigationDelegate> previousNavigationDelegate;
@end

@implementation WKWebViewRecovery

static void * KVOContext = &KVOContext;

- (void)pluginInitialize {
    self.wkWebView = (WKWebView *)self.webView;
    
    // Store and forward the previous delegate
    self.previousNavigationDelegate = self.wkWebView.navigationDelegate;
    self.wkWebView.navigationDelegate = self;

    // Observe URL changes
    [self.wkWebView addObserver:self
                     forKeyPath:@"URL"
                        options:NSKeyValueObservingOptionNew
                        context:KVOContext];

    // Listen for app resume
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onAppWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];

    NSLog(@"[WKWebViewRecovery] Initialized and tracking URLs");
}

#pragma mark - URL Observation

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {

    if (context == KVOContext &&
        object == self.wkWebView &&
        [keyPath isEqualToString:@"URL"]) {

        NSURL *currentURL = self.wkWebView.URL;
        if (currentURL &&
            ![currentURL.absoluteString isEqualToString:@"about:blank"] &&
            ![currentURL.absoluteString isEqualToString:@""]) {
            self.lastGoodURL = currentURL;
            NSLog(@"[WKWebViewRecovery] Cached good URL: %@", currentURL.absoluteString);
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - Navigation Delegate Forwarding

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

#pragma mark - Navigation Delegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    if (webView.URL &&
        ![webView.URL.absoluteString isEqualToString:@"about:blank"] &&
        ![webView.URL.absoluteString isEqualToString:@""]) {
        self.lastGoodURL = webView.URL;
        NSLog(@"[WKWebViewRecovery] Cached good URL on finish: %@", webView.URL.absoluteString);
    }
    
    // Forward to previous delegate
    if ([self.previousNavigationDelegate respondsToSelector:@selector(webView:didFinishNavigation:)]) {
        [self.previousNavigationDelegate webView:webView didFinishNavigation:navigation];
    }
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    NSLog(@"[WKWebViewRecovery] Process terminated — attempting recovery");
    [self reloadLastGoodURLOrFallback];
}

#pragma mark - App Resume

- (void)onAppWillEnterForeground:(NSNotification *)notification {
    NSLog(@"[WKWebViewRecovery] App entering foreground — checking reload");
    [self reloadLastGoodURLOrFallback];
}

#pragma mark - Recovery Logic

- (void)reloadLastGoodURLOrFallback {
    NSURL *currentURL = self.wkWebView.URL;
    NSURL *urlToLoad = nil;

    if (self.lastGoodURL) {
        urlToLoad = self.lastGoodURL;
        NSLog(@"[WKWebViewRecovery] Using last good URL: %@", urlToLoad.absoluteString);
    } else if (currentURL &&
               ![currentURL.absoluteString isEqualToString:@"about:blank"] &&
               ![currentURL.absoluteString isEqualToString:@""]) {
        urlToLoad = currentURL;
        NSLog(@"[WKWebViewRecovery] Using current URL: %@", urlToLoad.absoluteString);
    } else {
        urlToLoad = ((CDVViewController *)self.viewController).appUrl;
        NSLog(@"[WKWebViewRecovery] Using fallback app URL: %@", urlToLoad.absoluteString);
    }

    if (urlToLoad) {
        NSURLRequest *req = [NSURLRequest requestWithURL:urlToLoad
                                             cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                         timeoutInterval:20.0];
        [self.wkWebView loadRequest:req];
    }
}

#pragma mark - Cleanup

- (void)dispose {
    [self.wkWebView removeObserver:self forKeyPath:@"URL" context:KVOContext];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dispose];
}

@end
