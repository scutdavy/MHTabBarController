/*
 * Copyright (c) 2011-2012 Matthijs Hollemans
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import "MHTabBarController.h"

static const NSInteger TagOffset = 1000;

@interface MHTabBarController ()
@property (nonatomic) UIView *tabButtonsContainerView;
@property (nonatomic) UIView *contentContainerView;
@end

@implementation MHTabBarController

- (void)viewDidLoad {
	[super viewDidLoad];

	self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

	CGRect rect = CGRectMake(0.0f, self.view.bounds.size.height-[self tabBarHeight], self.view.bounds.size.width, [self tabBarHeight]);
	self.tabButtonsContainerView = [[UIView alloc] initWithFrame:rect];
	self.tabButtonsContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.view addSubview:self.tabButtonsContainerView];

	rect.origin.y = 0;
	rect.size.height = self.view.bounds.size.height - [self tabBarHeight];
	self.contentContainerView = [[UIView alloc] initWithFrame:rect];
	self.contentContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:self.contentContainerView];

	[self reloadTabButtons];
}

- (void)viewWillLayoutSubviews {
	[super viewWillLayoutSubviews];
	[self layoutTabButtons];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	// Only rotate if all child view controllers agree on the new orientation.
	for (UIViewController *viewController in self.viewControllers)
	{
		if (![viewController shouldAutorotateToInterfaceOrientation:interfaceOrientation])
			return NO;
	}
	return YES;
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];

	if ([self isViewLoaded] && self.view.window == nil) {
		self.view = nil;
		self.tabButtonsContainerView = nil;
		self.contentContainerView = nil;
	}
}

- (void)reloadTabButtons {
	[self removeTabButtons];
	[self addTabButtons];

	// Force redraw of the previously active tab.
	NSUInteger lastIndex = _selectedIndex;
	_selectedIndex = NSNotFound;
	self.selectedIndex = lastIndex;
}

- (void)addTabButtons {
	NSUInteger index = 0;
	for (UIViewController *viewController in self.viewControllers) {
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		button.tag = TagOffset + index;
		button.titleLabel.font = [UIFont boldSystemFontOfSize:18];
		button.titleLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);

		UIOffset offset = viewController.tabBarItem.titlePositionAdjustment;
		button.titleEdgeInsets = UIEdgeInsetsMake(offset.vertical, offset.horizontal, 0.0f, 0.0f);
		button.imageEdgeInsets = viewController.tabBarItem.imageInsets;
		[button setTitle:viewController.tabBarItem.title forState:UIControlStateNormal];
		[button setImage:viewController.tabBarItem.image forState:UIControlStateNormal];

		[button addTarget:self action:@selector(tabButtonPressed:) forControlEvents:UIControlEventTouchDown];

		[self deselectTabButton:button];
		[self.tabButtonsContainerView addSubview:button];

		++index;
	}
}

- (void)removeTabButtons {
	while ([self.tabButtonsContainerView.subviews count] > 0) {
		[[self.tabButtonsContainerView.subviews lastObject] removeFromSuperview];
	}
}

- (void)layoutTabButtons {
	NSUInteger index = 0;
	NSUInteger count = [self.viewControllers count];

	CGRect rect = CGRectMake(0.0f, 0.0f, floorf(self.view.bounds.size.width / count), [self tabBarHeight]);

	NSArray *buttons = [self.tabButtonsContainerView subviews];
	for (UIButton *button in buttons) {
		if (index == count - 1)
			rect.size.width = self.view.bounds.size.width - rect.origin.x;

		button.frame = rect;
		rect.origin.x += rect.size.width;

		++index;
	}
}

- (void)setViewControllers:(NSArray *)newViewControllers {
	NSAssert([newViewControllers count] >= 2, @"MHTabBarController requires at least two view controllers");

	UIViewController *oldSelectedViewController = self.selectedViewController;

	// Remove the old child view controllers.
	for (UIViewController *viewController in _viewControllers)
	{
		[viewController willMoveToParentViewController:nil];
		[viewController removeFromParentViewController];
	}

	_viewControllers = [newViewControllers copy];

	// This follows the same rules as UITabBarController for trying to
	// re-select the previously selected view controller.
	NSUInteger newIndex = [_viewControllers indexOfObject:oldSelectedViewController];
	if (newIndex != NSNotFound)
		_selectedIndex = newIndex;
	else if (newIndex < [_viewControllers count])
		_selectedIndex = newIndex;
	else
		_selectedIndex = 0;

	// Add the new child view controllers.
	for (UIViewController *viewController in _viewControllers) {
		[self addChildViewController:viewController];
		[viewController didMoveToParentViewController:self];
	}

	if ([self isViewLoaded])
		[self reloadTabButtons];
}

- (void)setSelectedIndex:(NSUInteger)newSelectedIndex {
	[self setSelectedIndex:newSelectedIndex animated:NO];
}

- (void)setSelectedIndex:(NSUInteger)newSelectedIndex animated:(BOOL)animated {
	NSAssert(newSelectedIndex < [self.viewControllers count], @"View controller index out of bounds");

	if ([self.delegate respondsToSelector:@selector(mh_tabBarController:shouldSelectViewController:atIndex:)]) {
		UIViewController *toViewController = (self.viewControllers)[newSelectedIndex];
		if (![self.delegate mh_tabBarController:self shouldSelectViewController:toViewController atIndex:newSelectedIndex])
			return;
	}

	if (![self isViewLoaded]) {
		_selectedIndex = newSelectedIndex;
	}
	else if (_selectedIndex != newSelectedIndex) {
		UIViewController *fromViewController;
		UIViewController *toViewController;

		if (_selectedIndex != NSNotFound) {
			UIButton *fromButton = (UIButton *)[self.tabButtonsContainerView viewWithTag:TagOffset + _selectedIndex];
			[self deselectTabButton:fromButton];
			fromViewController = self.selectedViewController;
		}

		NSUInteger oldSelectedIndex = _selectedIndex;
		_selectedIndex = newSelectedIndex;

		UIButton *toButton;
		if (_selectedIndex != NSNotFound) {
			toButton = (UIButton *)[self.tabButtonsContainerView viewWithTag:TagOffset + _selectedIndex];
			[self selectTabButton:toButton];
			toViewController = self.selectedViewController;
		}

		if (toViewController == nil) {// don't animate
			[fromViewController.view removeFromSuperview];
		}
		else if (fromViewController == nil) {// don't animate
			toViewController.view.frame = self.contentContainerView.bounds;
			[self.contentContainerView addSubview:toViewController.view];

			if ([self.delegate respondsToSelector:@selector(mh_tabBarController:didSelectViewController:atIndex:)])
				[self.delegate mh_tabBarController:self didSelectViewController:toViewController atIndex:newSelectedIndex];
		}
		else if (animated) {
			CGRect rect = self.contentContainerView.bounds;
			if (oldSelectedIndex < newSelectedIndex)
				rect.origin.x = rect.size.width;
			else
				rect.origin.x = -rect.size.width;

			toViewController.view.frame = rect;
			self.tabButtonsContainerView.userInteractionEnabled = NO;

			[self transitionFromViewController:fromViewController
				toViewController:toViewController
				duration:0.3f
				options:UIViewAnimationOptionLayoutSubviews | UIViewAnimationOptionCurveEaseOut
				animations:^ {
					CGRect rect = fromViewController.view.frame;
					if (oldSelectedIndex < newSelectedIndex)
						rect.origin.x = -rect.size.width;
					else
						rect.origin.x = rect.size.width;

					fromViewController.view.frame = rect;
					toViewController.view.frame = self.contentContainerView.bounds;
				}
				completion:^(BOOL finished) {
					self.tabButtonsContainerView.userInteractionEnabled = YES;

					if ([self.delegate respondsToSelector:@selector(mh_tabBarController:didSelectViewController:atIndex:)])
						[self.delegate mh_tabBarController:self didSelectViewController:toViewController atIndex:newSelectedIndex];
				}];
		}
		else {// not animated
			[fromViewController.view removeFromSuperview];

			toViewController.view.frame = self.contentContainerView.bounds;
			[self.contentContainerView addSubview:toViewController.view];

			if ([self.delegate respondsToSelector:@selector(mh_tabBarController:didSelectViewController:atIndex:)])
				[self.delegate mh_tabBarController:self didSelectViewController:toViewController atIndex:newSelectedIndex];
		}
	}
}

- (UIViewController *)selectedViewController {
	if (self.selectedIndex != NSNotFound)
		return (self.viewControllers)[self.selectedIndex];
	else
		return nil;
}

- (void)setSelectedViewController:(UIViewController *)newSelectedViewController {
	[self setSelectedViewController:newSelectedViewController animated:NO];
}

- (void)setSelectedViewController:(UIViewController *)newSelectedViewController animated:(BOOL)animated {
	NSUInteger index = [self.viewControllers indexOfObject:newSelectedViewController];
	if (index != NSNotFound)
		[self setSelectedIndex:index animated:animated];
}

- (void)tabButtonPressed:(UIButton *)sender {
	[self setSelectedIndex:sender.tag - TagOffset animated:YES];
}

#pragma mark - Change these methods to customize the look of the buttons

- (void)selectTabButton:(UIButton *)button {
	[button setTitleColor:[UIColor redColor] forState:UIControlStateNormal];

	UIImage *image = [[UIImage imageNamed:@"MHTabBarActiveTab"] stretchableImageWithLeftCapWidth:0 topCapHeight:0];
	[button setBackgroundImage:image forState:UIControlStateNormal];
	[button setBackgroundImage:image forState:UIControlStateHighlighted];
	
	[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[button setTitleShadowColor:[UIColor colorWithWhite:0.0f alpha:0.5f] forState:UIControlStateNormal];
}

- (void)deselectTabButton:(UIButton *)button {
	[button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];

	UIImage *image = [[UIImage imageNamed:@"MHTabBarInactiveTab"] stretchableImageWithLeftCapWidth:1 topCapHeight:0];
	[button setBackgroundImage:image forState:UIControlStateNormal];
	[button setBackgroundImage:image forState:UIControlStateHighlighted];

	[button setTitleColor:[UIColor colorWithRed:175/255.0f green:85/255.0f blue:58/255.0f alpha:1.0f] forState:UIControlStateNormal];
	[button setTitleShadowColor:[UIColor whiteColor] forState:UIControlStateNormal];
}

- (CGFloat)tabBarHeight {
	return 44.0f;
}

@end
