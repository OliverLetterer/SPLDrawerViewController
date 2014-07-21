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

@interface SPLDrawerViewController () <UIViewControllerTransitioningDelegate, UIViewControllerAnimatedTransitioning, UIViewControllerInteractiveTransitioning, UIDynamicAnimatorDelegate, UICollisionBehaviorDelegate>

@property (nonatomic, readonly) CGFloat progress;

@property (nonatomic, strong) UIView *dimmingBackgroundView;
@property (nonatomic, readonly) UIView *drawerView;
@property (nonatomic, readonly) UIView *drawerContainerView;

@property (nonatomic, readonly) BOOL isInCompactHorizontalSizeClass;

@property (nonatomic, assign) NSInteger collisionCount;
@property (nonatomic, readonly) CGFloat drawerSize;

@property (nonatomic, strong) UIDynamicAnimator *dynamicAnimator;

@property (nonatomic, strong) UIPanGestureRecognizer *dismissPanGestureRecognizer;
@property (nonatomic, strong) id<UIViewControllerContextTransitioning> interactiveTransitionContext;

@property (nonatomic, strong) dispatch_block_t animationCompletionHandler;

@end

@implementation SPLDrawerViewController

#pragma mark - setters and getters

- (CGFloat)progress
{
    CGFloat progress = (CGRectGetWidth(self.view.bounds) - CGRectGetMinX(self.drawerView.frame)) / self.drawerSize;

    if (self.isBeingDismissed) {
        progress = 1.0 - progress;
    }

    return MAX(MIN(progress, 1.0), 0.0);
}

- (void)setScreenEdgePanGestureRecognizer:(UIScreenEdgePanGestureRecognizer *)screenEdgePanGestureRecognizer
{
    NSParameterAssert(screenEdgePanGestureRecognizer && screenEdgePanGestureRecognizer.state == UIGestureRecognizerStateBegan);

    if (screenEdgePanGestureRecognizer != _screenEdgePanGestureRecognizer) {
        _screenEdgePanGestureRecognizer = screenEdgePanGestureRecognizer;

        [_screenEdgePanGestureRecognizer addTarget:self action:@selector(_panGestureRecognized:)];
    }
}

- (void)setAnimationCompletionHandler:(dispatch_block_t)animationCompletionHandler
{
    if (!animationCompletionHandler) {
        _animationCompletionHandler = nil;
        return;
    }

    __weak typeof(self) weakSelf = self;
    _animationCompletionHandler = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.animationCompletionHandler = nil;
        strongSelf.dynamicAnimator = nil;

        animationCompletionHandler();
    };
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
    return self.presentingViewController.preferredStatusBarStyle;
}

- (CGFloat)drawerSize
{
    return self.drawerViewController.preferredContentSize.width;
}

#pragma mark - UIViewController

- (id<UIViewControllerTransitioningDelegate>)transitioningDelegate
{
    return self;
}

- (UIModalPresentationStyle)modalPresentationStyle
{
    return UIModalPresentationCustom;
}

- (instancetype)initWithDrawerViewController:(UIViewController *)drawerViewController
{
    if (self = [super init]) {
        _drawerViewController = drawerViewController;
        [self addChildViewController:_drawerViewController];
        [_drawerViewController didMoveToParentViewController:self];
    }
    return self;
}

#pragma mark - View lifecycle

- (void)loadView
{
    [super loadView];

    _dimmingBackgroundView = [[UIView alloc] initWithFrame:self.view.bounds];
    _dimmingBackgroundView.alpha = 0.0;
    _dimmingBackgroundView.userInteractionEnabled = NO;
    _dimmingBackgroundView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    _dimmingBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_dimmingBackgroundView];

    [self _loadDrawerView];
    self.drawerView.frame = CGRectMake(CGRectGetWidth(self.view.bounds), 0.0, self.drawerSize, CGRectGetHeight(self.view.bounds));

    self.drawerViewController.view.frame = self.drawerView.bounds;
    self.drawerViewController.view.backgroundColor = [UIColor clearColor];
    [self.drawerContainerView addSubview:self.drawerViewController.view];

    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_dismissDrawerTapped)];
    [self.view addGestureRecognizer:tapRecognizer];

    _dismissPanGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_panGestureRecognized:)];
    [self.view addGestureRecognizer:_dismissPanGestureRecognizer];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    if (self.isBeingPresented && self.interactiveTransitionContext) {
        self.drawerView.frame = CGRectMake(CGRectGetWidth(self.view.bounds), 0.0, self.drawerSize, CGRectGetHeight(self.view.bounds));
    } else {
        self.drawerView.frame = CGRectMake(CGRectGetWidth(self.view.bounds) - self.drawerSize, 0.0, self.drawerSize, CGRectGetHeight(self.view.bounds));
    }
}

- (NSUInteger)supportedInterfaceOrientations
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return UIInterfaceOrientationMaskAll;
    } else {
        return UIInterfaceOrientationMaskPortrait;
    }
}

#pragma mark - UIViewControllerTransitioningDelegate

- (id <UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source
{
    return self;
}

- (id <UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed
{
    return self;
}

- (id <UIViewControllerInteractiveTransitioning>)interactionControllerForPresentation:(id <UIViewControllerAnimatedTransitioning>)animator
{
    if (self.screenEdgePanGestureRecognizer && self.screenEdgePanGestureRecognizer.state == UIGestureRecognizerStateBegan) {
        return self;
    }

    return nil;
}

- (id <UIViewControllerInteractiveTransitioning>)interactionControllerForDismissal:(id <UIViewControllerAnimatedTransitioning>)animator
{
    if (self.dismissPanGestureRecognizer.state == UIGestureRecognizerStateBegan) {
        return self;
    }

    return nil;
}

#pragma mark - UIViewControllerInteractiveTransitioning

- (void)startInteractiveTransition:(id <UIViewControllerContextTransitioning>)transitionContext
{
    if (self.isBeingPresented) {
        UIView *containerView = [transitionContext containerView];

        self.view.frame = containerView.bounds;
        [containerView addSubview:self.view];
    }

    self.interactiveTransitionContext = transitionContext;
}

#pragma mark - UIViewControllerAnimatedTransitioning

- (NSTimeInterval)transitionDuration:(id <UIViewControllerContextTransitioning>)transitionContext
{
    UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    return toViewController.isBeingPresented ? 0.5 : 0.3;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];

    if (toViewController.isBeingPresented) {
        [self _performPresentViewControllerAnimationInTransitionInContext:transitionContext];
    } else {
        [self _performDismissTransitionInContext:transitionContext];
    }
}

- (void)_performPresentViewControllerAnimationInTransitionInContext:(id<UIViewControllerContextTransitioning>)transitionContext
{
    UIView *containerView = [transitionContext containerView];

    self.view.frame = containerView.bounds;
    [containerView addSubview:self.view];

    UIViewAnimationOptions options = UIViewAnimationOptionAllowUserInteraction;
    [UIView animateWithDuration:[self transitionDuration:transitionContext] delay:0.0 usingSpringWithDamping:1.0 initialSpringVelocity:0.0 options:options animations:^{
        self.dimmingBackgroundView.alpha = 1.0;
        self.drawerView.frame = CGRectMake(CGRectGetWidth(self.view.bounds) - self.drawerSize, 0.0, self.drawerSize, CGRectGetHeight(self.view.bounds));
    } completion:NULL];

    double delayInSeconds = [self transitionDuration:transitionContext] / 2.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [transitionContext completeTransition:YES];
    });
}

- (void)_performDismissTransitionInContext:(id<UIViewControllerContextTransitioning>)transitionContext
{
    UIViewAnimationOptions options = UIViewAnimationOptionAllowUserInteraction;
    [UIView animateWithDuration:[self transitionDuration:transitionContext] delay:0.0 usingSpringWithDamping:1.0 initialSpringVelocity:0.0 options:options animations:^{
        self.dimmingBackgroundView.alpha = 0.0;
        self.drawerView.frame = CGRectMake(CGRectGetWidth(self.view.bounds), 0.0, self.drawerSize, CGRectGetHeight(self.view.bounds));
    } completion:^(BOOL finished) {
        [transitionContext completeTransition:YES];
    }];
}

#pragma mark - UIDynamicAnimatorDelegate

- (void)dynamicAnimatorDidPause:(UIDynamicAnimator *)animator
{
    self.animationCompletionHandler();
}

#pragma mark - UICollisionBehaviorDelegate

- (void)collisionBehavior:(UICollisionBehavior*)behavior beganContactForItem:(id <UIDynamicItem>)item withBoundaryIdentifier:(id <NSCopying>)identifier atPoint:(CGPoint)p
{
    self.collisionCount++;

    if (self.collisionCount == 2) {
        self.animationCompletionHandler();
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

- (void)_dismissDrawerTapped
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)_panGestureRecognized:(UIPanGestureRecognizer *)recognizer
{
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            self.collisionCount = 0;
            self.dynamicAnimator = nil;

            if (recognizer == self.dismissPanGestureRecognizer && !self.isBeingDismissed) {
                [self dismissViewControllerAnimated:YES completion:NULL];
            }
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

            [self _updateDimmingBackgroundView];
            [self.interactiveTransitionContext updateInteractiveTransition:self.progress];
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

    __weak typeof(self) weakSelf = self;
    UIDynamicBehavior *progressBehavior = [[UIDynamicBehavior alloc] init];
    [progressBehavior setAction:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;

        [strongSelf _updateDimmingBackgroundView];
        [strongSelf.interactiveTransitionContext updateInteractiveTransition:strongSelf.progress];
    }];
    [self.dynamicAnimator addBehavior:progressBehavior];

    [self setAnimationCompletionHandler:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;

        [strongSelf.screenEdgePanGestureRecognizer removeTarget:strongSelf action:@selector(_panGestureRecognized:)];
        if ((velocity < 0 && strongSelf.isBeingDismissed) || (velocity > 0 && strongSelf.isBeingPresented)) {
            [strongSelf.interactiveTransitionContext cancelInteractiveTransition];
            [strongSelf.interactiveTransitionContext completeTransition:NO];
        } else {
            [strongSelf.interactiveTransitionContext finishInteractiveTransition];
            [strongSelf.interactiveTransitionContext completeTransition:YES];
        }

        strongSelf.interactiveTransitionContext = nil;
    }];
}

- (void)_updateDimmingBackgroundView
{
    if (self.isBeingPresented) {
        self.dimmingBackgroundView.alpha = self.progress;
    } else if (self.isBeingDismissed) {
        self.dimmingBackgroundView.alpha = 1.0 - self.progress;
    } else {
        self.dimmingBackgroundView.alpha = 1.0;
    }
}

@end
