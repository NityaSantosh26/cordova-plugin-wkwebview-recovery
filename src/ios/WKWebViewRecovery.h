#import <Cordova/CDV.h>
#import <WebKit/WebKit.h>

@interface WKWebViewRecovery : CDVPlugin <WKNavigationDelegate>

@property (nonatomic, strong) WKWebView *wkWebView;
@property (nonatomic, weak) id<WKNavigationDelegate> previousNavigationDelegate;

@end
