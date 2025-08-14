#import <Cordova/CDV.h>
#import <WebKit/WebKit.h>

@interface WKRouteRecovery : CDVPlugin <WKNavigationDelegate>
@property (nonatomic, strong) NSString *lastRoute;
@property (nonatomic, strong) NSURL *startPageURL;
@end

@implementation WKRouteRecovery

- (void)pluginInitialize {
    WKWebView *wkWebView = (WKWebView *)self.webView;
    wkWebView.navigationDelegate = self;

    self.startPageURL = wkWebView.URL; // usually index.html
    NSLog(@"[WKRouteRecovery] Initialized. Start page: %@", self.startPageURL.absoluteString);
}

#pragma mark - JS -> Native
- (void)saveRoute:(CDVInvokedUrlCommand *)command {
    NSString *route = [command.arguments objectAtIndex:0];
    if (route && route.length > 0) {
        self.lastRoute = route;
        NSLog(@"[WKRouteRecovery] Saved route: %@", route);
    }
}

#pragma mark - WKNavigationDelegate
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    NSLog(@"[WKRouteRecovery] Web content process terminated. Reloading...");

    // Reload start page
    if (self.startPageURL) {
        NSURLRequest *req = [NSURLRequest requestWithURL:self.startPageURL];
        [webView loadRequest:req];
    } else {
        [webView reload];
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    // Restore last route if we are back on the start page
    if (self.lastRoute &&
        [webView.URL.absoluteString containsString:self.startPageURL.lastPathComponent]) {

        NSString *js = [NSString stringWithFormat:@"window.location.hash = '%@';", self.lastRoute];
        NSLog(@"[WKRouteRecovery] Restoring route via JS: %@", self.lastRoute);

        [webView evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
            if (error) {
                NSLog(@"[WKRouteRecovery] Error injecting route: %@", error);
            }
        }];
    }
}

@end
