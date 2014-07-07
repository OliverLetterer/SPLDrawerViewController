//
//  SPLDrawerViewController.m
//
//  The MIT License (MIT)
//  Copyright (c) 2014 Oliver Letterer, Sparrow-Labs
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "SPLDrawerViewController.h"



@interface SPLDrawerViewController () <UICollisionBehaviorDelegate, UIDynamicAnimatorDelegate>

@property (nonatomic, readonly) BOOL isInCompactHorizontalSizeClass;

@property (nonatomic, assign) NSInteger collisionCount;

@property (nonatomic, assign) BOOL drawerWasVisible;
@property (nonatomic, readonly) BOOL isDrawerVisible;
@property (nonatomic, readonly) CGFloat drawerSize;

@property (nonatomic, readonly) UIView *drawerView;
@property (nonatomic, readonly) UIView *drawerContainerView;

@property (nonatomic, strong) UIDynamicAnimator *dynamicAnimator;

@property (nonatomic, readonly) UIView *dismissView;

@end



@implementation SPLDrawerViewController

#pragma mark - setters and getters

- (BOOL)isDrawerVisible
{
    return CGRectGetMinX(self.drawerView.frame) < CGRectGetMaxX(self.masterViewController.view.bounds);
}

- (BOOL)isInCompactHorizontalSizeClass
{
#ifdef __IPHONE_8_0
    if ([self respondsToSelector:@selector(traitCollection)]) {
        return self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassCompact;
    }
#endif

    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    if (self.isInCompactHorizontalSizeClass && CGRectGetMinX(self.drawerView.frame) < CGRectGetWidth(self.view.bounds)) {
        return UIStatusBarStyleLightContent;
    }

    return [super preferredStatusBarStyle];
}

- (CGFloat)drawerSize
{
    return self.isInCompactHorizontalSizeClass ? CGRectGetWidth(self.view.bounds) : 320.0;
}

#pragma mark - Initialization

- (instancetype)initWithMasterViewController:(UIViewController *)masterViewController drawerViewController:(UIViewController *)drawerViewController
{
    if (self = [super init]) {
        _masterViewController = masterViewController;
        _drawerViewController = drawerViewController;

        [self addChildViewController:_masterViewController];
        [_masterViewController didMoveToParentViewController:self];

        [self addChildViewController:_drawerViewController];
        [_drawerViewController didMoveToParentViewController:self];

        if ([self respondsToSelector:@selector(setRestorationIdentifier:)]) {
            self.restorationIdentifier = NSStringFromClass(self.class);
            self.restorationClass = self.class;
        }
    }
    return self;
}

#pragma mark - View lifecycle

- (void)loadView
{
    [super loadView];

    self.masterViewController.view.frame = self.view.bounds;
    self.masterViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.masterViewController.view];

    _dismissView = [[UIView alloc] initWithFrame:self.view.bounds];
    _dismissView.backgroundColor = [UIColor clearColor];
    _dismissView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _dismissView.hidden = YES;
    [self.view addSubview:_dismissView];

    UITapGestureRecognizer *dismissGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_dismissDrawer)];
    [_dismissView addGestureRecognizer:dismissGestureRecognizer];

    [self _loadDrawerView];
    self.drawerView.frame = CGRectMake(CGRectGetWidth(self.view.bounds), 0.0, self.drawerSize, CGRectGetHeight(self.view.bounds));

    self.drawerViewController.view.frame = self.drawerView.bounds;
    self.drawerViewController.view.backgroundColor = [UIColor clearColor];
    [self.drawerContainerView addSubview:self.drawerViewController.view];

    UIScreenEdgePanGestureRecognizer *edgePanGestureRecognizer = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(_panGestureRecognized:)];
    edgePanGestureRecognizer.edges = UIRectEdgeRight;
    [self.view addGestureRecognizer:edgePanGestureRecognizer];

    UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_panGestureRecognized:)];
    [self.drawerView addGestureRecognizer:panGestureRecognizer];

    _panGestureRecognizers = @[ edgePanGestureRecognizer, panGestureRecognizer ];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self _layoutDrawerView];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    self.drawerWasVisible = self.isDrawerVisible;
}

- (NSUInteger)supportedInterfaceOrientations
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return UIInterfaceOrientationMaskAll;
    } else {
        return UIInterfaceOrientationMaskPortrait;
    }
}

#pragma mark - UIViewControllerRestoration

+ (UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    return [[self alloc] init];
}

#pragma mark - UIStateRestoration

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];

}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];

}

#pragma mark - UIDynamicAnimatorDelegate

- (void)dynamicAnimatorDidPause:(UIDynamicAnimator *)animator
{
    [self _animationDidStop];
}

#pragma mark - UICollisionBehaviorDelegate

- (void)collisionBehavior:(UICollisionBehavior*)behavior beganContactForItem:(id <UIDynamicItem>)item withBoundaryIdentifier:(id <NSCopying>)identifier atPoint:(CGPoint)p
{
    self.collisionCount++;

    if (self.collisionCount == 2) {
        [self _animationDidStop];
    }
}

#pragma mark - Private category implementation ()

- (void)_loadDrawerView
{
#ifdef __IPHONE_8_0
    if ([UIVisualEffectView class]) {
        UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        UIVisualEffectView *drawerView = [[UIVisualEffectView alloc] initWithEffect:effect];
        drawerView.frame = self.view.bounds;

        UIVisualEffectView *vibrancyEffectView = [[UIVisualEffectView alloc] initWithEffect:[UIVibrancyEffect effectForBlurEffect:effect]];
        vibrancyEffectView.frame = drawerView.bounds;
        vibrancyEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [drawerView.contentView addSubview:vibrancyEffectView];

        _drawerView = drawerView;
        _drawerContainerView = vibrancyEffectView.contentView;

        [self.view addSubview:_drawerView];
        return;
    }
#endif

    UINavigationBar *navigationBar = [[UINavigationBar alloc] initWithFrame:self.view.bounds];
    navigationBar.barTintColor = [UIColor blackColor];

    _drawerView = navigationBar;
    _drawerContainerView = navigationBar;

    [self.view addSubview:_drawerView];
}

- (void)_panGestureRecognized:(UIPanGestureRecognizer *)recognizer
{
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            self.collisionCount = 0;
            self.dynamicAnimator = nil;
            break;
        }
        case UIGestureRecognizerStateChanged: {
            CGFloat translation = [recognizer translationInView:self.view].x;
            [recognizer setTranslation:CGPointZero inView:self.view];

            CGPoint center = self.drawerView.center;
            center.x += translation;

            center.x = MAX(center.x, CGRectGetMaxX(self.view.bounds) - self.drawerSize / 2.0);
            center.x = MIN(center.x, CGRectGetMaxX(self.view.bounds) + self.drawerSize / 2.0);
            self.drawerView.center = center;
            break;
        }
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateEnded: {
            CGFloat velocity = [recognizer velocityInView:self.view].x;
            [self _animateDrawerWithVelocity:velocity];
            break;
        }
        default:
            break;
    }
}

- (void)_animateDrawerWithVelocity:(CGFloat)velocity
{
    self.dynamicAnimator = [[UIDynamicAnimator alloc] initWithReferenceView:self.view];
    self.dynamicAnimator.delegate = self;

    UICollisionBehavior *collisionBevavior = [[UICollisionBehavior alloc] initWithItems:@[ self.drawerView ]];
    collisionBevavior.collisionDelegate = self;
    [collisionBevavior setTranslatesReferenceBoundsIntoBoundaryWithInsets:UIEdgeInsetsMake(0.0, CGRectGetWidth(self.view.bounds) - self.drawerSize, 0.0, - self.drawerSize)];
    [self.dynamicAnimator addBehavior:collisionBevavior];

    UIDynamicItemBehavior *behavior = [[UIDynamicItemBehavior alloc] initWithItems:@[ self.drawerView ]];
    [behavior addLinearVelocity:CGPointMake(velocity, 0.0) forItem:self.drawerView];
    [self.dynamicAnimator addBehavior:behavior];

    UIGravityBehavior *gravityBehavior = [[UIGravityBehavior alloc] initWithItems:@[ self.drawerView ]];
    gravityBehavior.gravityDirection = CGVectorMake(velocity < 0.0 ? - 5.0 : 5.0, 0.0);
    [self.dynamicAnimator addBehavior:gravityBehavior];
}

- (void)_animationDidStop
{
    self.dynamicAnimator = nil;

    CGRect visibleDrawerRect = UIEdgeInsetsInsetRect(self.view.bounds, UIEdgeInsetsMake(0.0, CGRectGetWidth(self.view.bounds) - self.drawerSize, 0.0, - self.drawerSize));
    self.drawerWasVisible = fabs(CGRectGetMinX(self.drawerView.frame) - CGRectGetMinX(visibleDrawerRect)) < fabs(CGRectGetMaxX(self.drawerView.frame) - CGRectGetMaxX(visibleDrawerRect));

    [self _layoutDrawerView];
}

- (void)_layoutDrawerView
{
    CGFloat drawerSize = self.drawerSize;

    if (self.drawerWasVisible) {
        self.drawerView.frame = CGRectMake(CGRectGetWidth(self.view.bounds) - drawerSize, 0.0, drawerSize, CGRectGetHeight(self.view.bounds));
    } else {
        self.drawerView.frame = CGRectMake(CGRectGetWidth(self.view.bounds), 0.0, drawerSize, CGRectGetHeight(self.view.bounds));
    }

    [self setNeedsStatusBarAppearanceUpdate];
    self.dismissView.hidden = !self.isDrawerVisible;
}

- (void)_dismissDrawer
{
    [self _animateDrawerWithVelocity:0.01];
}

@end



@implementation UIViewController (SPLDrawerViewController)

- (SPLDrawerViewController *)drawerViewController
{
    UIViewController *drawerViewController = self;

    while (drawerViewController && ![drawerViewController isKindOfClass:[SPLDrawerViewController class]]) {
        drawerViewController = drawerViewController.parentViewController;
    }
    
    return (SPLDrawerViewController *)drawerViewController;
}

@end
