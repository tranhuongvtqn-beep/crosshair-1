#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>

// --- Private API declaration để ép iOS vẽ đè hệ thống ---
@interface UIWindow (Private)
- (void)_setSecure:(BOOL)secure;
@end

// --- View Vẽ Tâm Ảo ---
@interface CrosshairView : UIView
@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, assign) NSInteger shapeIndex;
@property (nonatomic, strong) UIColor *crosshairColor;
@property (nonatomic, assign) CGFloat crosshairSize;
@property (nonatomic, assign) CGFloat thickness;
@property (nonatomic, assign) CGFloat offsetX;
@property (nonatomic, assign) CGFloat offsetY;
@end

@implementation CrosshairView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO; 
        self.isEnabled = YES;
        self.shapeIndex = 0;
        self.crosshairColor = [UIColor cyanColor];
        self.crosshairSize = 15.0;
        self.thickness = 2.0;
        self.offsetX = 0;
        self.offsetY = 0;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    if (!self.isEnabled) return;
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;
    CGContextClearRect(ctx, rect);
    
    CGFloat centerX = CGRectGetMidX(rect) + self.offsetX;
    CGFloat centerY = CGRectGetMidY(rect) + self.offsetY;
    CGFloat s = self.crosshairSize;
    CGFloat t = self.thickness;
    
    [self.crosshairColor setStroke];
    [self.crosshairColor setFill];
    CGContextSetLineWidth(ctx, t);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    
    NSInteger style = self.shapeIndex % 50;
    BOOL drawDot = (style == 1 || style % 3 == 0);
    BOOL drawCross = (style == 0 || style % 2 == 0);
    BOOL drawCircle = (style >= 5 && style <= 15) || (style % 5 == 0);
    CGFloat gap = (style % 4 == 0) ? (s * 0.3) : 0;
    
    if (drawCircle) {
        CGContextStrokeEllipseInRect(ctx, CGRectMake(centerX - s, centerY - s, s * 2, s * 2));
    }
    if (drawCross) {
        CGContextMoveToPoint(ctx, centerX - s - gap, centerY);
        CGContextAddLineToPoint(ctx, centerX - gap, centerY);
        CGContextMoveToPoint(ctx, centerX + gap, centerY);
        CGContextAddLineToPoint(ctx, centerX + s + gap, centerY);
        CGContextMoveToPoint(ctx, centerX, centerY - s - gap);
        CGContextAddLineToPoint(ctx, centerX, centerY - gap);
        CGContextMoveToPoint(ctx, centerX, centerY + gap);
        CGContextAddLineToPoint(ctx, centerX, centerY + s + gap);
        CGContextStrokePath(ctx);
    }
    if (drawDot) {
        CGFloat dotRadius = t * 1.2;
        CGContextFillEllipseInRect(ctx, CGRectMake(centerX - dotRadius, centerY - dotRadius, dotRadius * 2, dotRadius * 2));
    }
}
@end

// --- Quản lý System Overlay Window dành riêng cho TrollStore ---
@interface TrollOverlayManager : NSObject
+ (instancetype)shared;
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) CrosshairView *crosshairView;
@end

@implementation TrollOverlayManager
+ (instancetype)shared {
    static TrollOverlayManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[TrollOverlayManager alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        
        // 1. Khởi tạo Window với level cao vượt khung hệ thống (StatusBar level)
        self.overlayWindow = [[UIWindow alloc] initWithFrame:screenBounds];
        self.overlayWindow.backgroundColor = [UIColor clearColor];
        
        // Kích hoạt Window Level tối thượng cho TrollStore Root
        self.overlayWindow.windowLevel = CGFLOAT_MAX; 
        self.overlayWindow.userInteractionEnabled = NO;
        
        // 2. Bảo vệ Window không bị iOS tự động giải phóng / đóng băng
        if ([self.overlayWindow respondsToSelector:@selector(_setSecure:)]) {
            [self.overlayWindow _setSecure:YES];
        }
        
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        vc.view.userInteractionEnabled = NO;
        
        self.crosshairView = [[CrosshairView alloc] initWithFrame:screenBounds];
        [vc.view addSubview:self.crosshairView];
        
        self.overlayWindow.rootViewController = vc;
        self.overlayWindow.hidden = NO;
    }
    return self;
}
@end

// --- Giao diện Control UI (Glassmorphism Dark) ---
@interface MainViewController : UIViewController
@property (nonatomic, strong) NSArray<UIColor *> *colorPalette;
@property (nonatomic, strong) UILabel *shapeLabel;
@end

@implementation MainViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = self.view.bounds;
    gradient.colors = @[(id)[UIColor colorWithRed:0.05 green:0.05 blue:0.1 alpha:1.0].CGColor,
                        (id)[UIColor colorWithRed:0.02 green:0.02 blue:0.05 alpha:1.0].CGColor];
    [self.view.layer insertSublayer:gradient atIndex:0];
    
    [self initColorPalette];
    [self setupHeader];
    [self setupControls];
}

- (void)initColorPalette {
    NSMutableArray *colors = [NSMutableArray array];
    for (int i = 0; i < 30; i++) {
        [colors addObject:[UIColor colorWithHue:(CGFloat)i/30.0 saturation:1.0 brightness:1.0 alpha:1.0]];
    }
    self.colorPalette = colors;
}

- (void)setupHeader {
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 60, self.view.bounds.size.width - 40, 40)];
    titleLabel.text = @"CROSSHAIR PRO TROLL";
    titleLabel.font = [UIFont systemFontOfSize:26 weight:UIFontWeightBlack];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.layer.shadowColor = [UIColor cyanColor].CGColor;
    titleLabel.layer.shadowRadius = 8.0;
    titleLabel.layer.shadowOpacity = 0.6;
    [self.view addSubview:titleLabel];
}

- (void)setupControls {
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(20, 110, self.view.bounds.size.width - 40, self.view.bounds.size.height - 130)];
    scrollView.contentSize = CGSizeMake(scrollView.bounds.size.width, 680);
    scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:scrollView];
    
    CGFloat y = 10;
    
    // Card 1: Bật/Tắt
    UIView *card1 = [self createGlassCard:CGRectMake(0, y, scrollView.bounds.size.width, 70)];
    UILabel *swLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, 200, 30)];
    swLabel.text = @"Bật Tâm Đè Game";
    swLabel.textColor = [UIColor whiteColor];
    swLabel.font = [UIFont boldSystemFontOfSize:17];
    [card1 addSubview:swLabel];
    
    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(card1.bounds.size.width - 70, 20, 0, 0)];
    sw.on = YES;
    sw.onTintColor = [UIColor cyanColor];
    [sw addTarget:self action:@selector(toggleSwitch:) forControlEvents:UIControlEventValueChanged];
    [card1 addSubview:sw];
    [scrollView addSubview:card1];
    y += 85;
    
    // Card 2: Kiểu tâm
    UIView *card2 = [self createGlassCard:CGRectMake(0, y, scrollView.bounds.size.width, 85)];
    self.shapeLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 15, 200, 25)];
    self.shapeLabel.text = @"Kiểu tâm: 1 / 50";
    self.shapeLabel.textColor = [UIColor whiteColor];
    self.shapeLabel.font = [UIFont boldSystemFontOfSize:16];
    [card2 addSubview:self.shapeLabel];
    
    UIStepper *stepper = [[UIStepper alloc] initWithFrame:CGRectMake(card2.bounds.size.width - 110, 40, 0, 0)];
    stepper.minimumValue = 0;
    stepper.maximumValue = 49;
    stepper.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
    stepper.layer.cornerRadius = 8;
    [stepper addTarget:self action:@selector(shapeChanged:) forControlEvents:UIControlEventValueChanged];
    [card2 addSubview:stepper];
    [scrollView addSubview:card2];
    y += 100;
    
    // Card 3: Slider
    UIView *card3 = [self createGlassCard:CGRectMake(0, y, scrollView.bounds.size.width, 270)];
    [self addSliderToView:card3 title:@"Kích thước" min:5 max:80 val:15 y:15 tag:101];
    [self addSliderToView:card3 title:@"Độ dày" min:1 max:15 val:2 y:80 tag:102];
    [self addSliderToView:card3 title:@"Lệch X (Căn chỉnh)" min:-200 max:200 val:0 y:145 tag:103];
    [self addSliderToView:card3 title:@"Lệch Y (Căn chỉnh)" min:-200 max:200 val:0 y:210 tag:104];
    [scrollView addSubview:card3];
    y += 285;
    
    // Card 4: Màu sắc
    UIView *card4 = [self createGlassCard:CGRectMake(0, y, scrollView.bounds.size.width, 180)];
    CGFloat btnW = (card4.bounds.size.width - 50) / 6;
    for (int i = 0; i < 30; i++) {
        int row = i / 6; int col = i % 6;
        UIButton *cBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        cBtn.frame = CGRectMake(20 + col * (btnW + 2), 20 + row * 30, btnW, 25);
        cBtn.backgroundColor = self.colorPalette[i];
        cBtn.layer.cornerRadius = 6;
        cBtn.tag = i;
        [cBtn addTarget:self action:@selector(colorSelected:) forControlEvents:UIControlEventTouchUpInside];
        [card4 addSubview:cBtn];
    }
    [scrollView addSubview:card4];
}

- (UIView *)createGlassCard:(CGRect)frame {
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    blurView.frame = frame;
    blurView.layer.cornerRadius = 16;
    blurView.clipsToBounds = YES;
    blurView.layer.borderWidth = 1;
    blurView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.1].CGColor;
    return blurView.contentView;
}

- (void)addSliderToView:(UIView *)parent title:(NSString *)title min:(float)min max:(float)max val:(float)val y:(CGFloat)posY tag:(NSInteger)tag {
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(20, posY, 200, 20)];
    lbl.text = title;
    lbl.textColor = [UIColor lightGrayColor];
    lbl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [parent addSubview:lbl];
    
    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(20, posY + 25, parent.bounds.size.width - 40, 30)];
    slider.minimumValue = min;
    slider.maximumValue = max;
    slider.value = val;
    slider.tag = tag;
    slider.minimumTrackTintColor = [UIColor cyanColor];
    slider.thumbTintColor = [UIColor whiteColor];
    [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [parent addSubview:slider];
}

- (void)toggleSwitch:(UISwitch *)sw {
    [TrollOverlayManager shared].crosshairView.isEnabled = sw.isOn;
    [[TrollOverlayManager shared].crosshairView setNeedsDisplay];
}
- (void)shapeChanged:(UIStepper *)st {
    NSInteger val = (NSInteger)st.value;
    self.shapeLabel.text = [NSString stringWithFormat:@"Kiểu tâm: %ld / 50", (long)val + 1];
    [TrollOverlayManager shared].crosshairView.shapeIndex = val;
    [[TrollOverlayManager shared].crosshairView setNeedsDisplay];
}
- (void)sliderChanged:(UISlider *)sd {
    CrosshairView *v = [TrollOverlayManager shared].crosshairView;
    if (sd.tag == 101) v.crosshairSize = sd.value;
    if (sd.tag == 102) v.thickness = sd.value;
    if (sd.tag == 103) v.offsetX = sd.value;
    if (sd.tag == 104) v.offsetY = sd.value;
    [v setNeedsDisplay];
}
- (void)colorSelected:(UIButton *)btn {
    [TrollOverlayManager shared].crosshairView.crosshairColor = self.colorPalette[btn.tag];
    [[TrollOverlayManager shared].crosshairView setNeedsDisplay];
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [[MainViewController alloc] init];
    [self.window makeKeyAndVisible];
    
    // Kích hoạt System Overlay
    [TrollOverlayManager shared];
    return YES;
}
@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
