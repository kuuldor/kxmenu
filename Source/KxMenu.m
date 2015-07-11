//
//  KxMenu.m
//  kxmenu project
//  https://github.com/kolyvan/kxmenu/
//
//  Created by Kolyvan on 17.05.13.
//

/*
 Copyright (c) 2013 Konstantin Bukreev. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 - Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

/*
 Some ideas was taken from QBPopupMenu project by Katsuma Tanaka.
 https://github.com/questbeat/QBPopupMenu
*/

#import "KxMenu.h"
#import <QuartzCore/QuartzCore.h>
#import "UIImage+ImageEffects.h"
@import Accelerate;

const CGFloat kArrowSize = 12.f;

////////////////////////////////////////////////////////////////////////////////

@implementation KxMenuOverlay

//- (void) dealloc { NSLog(@"dealloc <%@ %p>", [self class], self); }

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
    }
    return self;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UIView *touched = [[touches anyObject] view];
    if (touched == self) {        
        //[self.nextResponder touchesBegan:touches withEvent:event];
        [self.menuView dismissMenu:YES];
    }
}

- (KxMenu *) menuView
{
    for (UIView *v in self.subviews) {
        if ([v isKindOfClass:[KxMenu class]]) {
            return (KxMenu *)v;
        }
    }
    return nil;
}

@end

////////////////////////////////////////////////////////////////////////////////

@implementation KxMenuItem

+ (instancetype) menuItem:(NSString *) title
                    image:(UIImage *) image
                   target:(id)target
                   action:(SEL) action
{
    return [[KxMenuItem alloc] init:title
                              image:image
                             target:target
                             action:action];
}

- (instancetype) initWithTitle:(NSString *) title
                         image:(UIImage *) image
                       handler:(void(^)()) handler
{
    NSParameterAssert(title.length || image);
    
    self = [super init];
    if (self) {        
        _title = title;
        _image = image;
        _handler = handler;
    }
    return self;
}


- (id) init:(NSString *) title
      image:(UIImage *) image
     target:(id)target
     action:(SEL) action
{
    NSParameterAssert(title.length || image);
    
    self = [super init];
    if (self) {
        
        _title = title;
        _image = image;
        _target = target;
        _action = action;
    }
    return self;
}

- (BOOL) enabled
{
    return (_target != nil && _action != NULL) || (_handler != nil);
}

- (void) performAction
{
    __strong id target = self.target;
    
    if (target && [target respondsToSelector:_action]) {
        
        [target performSelectorOnMainThread:_action withObject:self waitUntilDone:YES];
    } else if (_handler) {
        _handler();
    }
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"<%@ #%p %@>", [self class], self, _title];
}

@end

////////////////////////////////////////////////////////////////////////////////

typedef enum {
  
    KxMenuViewArrowDirectionNone,
    KxMenuViewArrowDirectionUp,
    KxMenuViewArrowDirectionDown,
    KxMenuViewArrowDirectionLeft,
    KxMenuViewArrowDirectionRight,
    
} KxMenuViewArrowDirection;


@implementation KxMenu {
    
    KxMenuViewArrowDirection    _arrowDirection;
    CGFloat                     _arrowPosition;
    UIView                      *_contentView;
    NSArray                     *_menuItems;
    UIImage                     *_backImage;
    BOOL                        _didObserve;
}

- (id)init
{
    self = [super initWithFrame:CGRectZero];    
    if(self) {
        
        self.backgroundColor = [UIColor clearColor];
        self.opaque = YES;
        self.alpha = 0;
        
        _didObserve = YES;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(orientationWillChange:)
                                                     name:UIApplicationWillChangeStatusBarOrientationNotification
                                                   object:nil];
    }

    return self;
}

- (void) dealloc
{
    if (_didObserve) {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }    
    //NSLog(@"dealloc <%@ %p>", [self class], self);
}

- (void) orientationWillChange: (NSNotification *) n
{
    [self dismissMenu:NO];
}

- (void) setupFrameInView:(UIView *)view
                 fromRect:(CGRect)fromRect
{
    const CGSize contentSize = _contentView.frame.size;
    
    const CGFloat outerWidth = view.bounds.size.width;
    const CGFloat outerHeight = view.bounds.size.height;
    
    const CGFloat rectX0 = fromRect.origin.x;
    const CGFloat rectX1 = fromRect.origin.x + fromRect.size.width;
    const CGFloat rectXM = fromRect.origin.x + fromRect.size.width * 0.5f;
    const CGFloat rectY0 = fromRect.origin.y;
    const CGFloat rectY1 = fromRect.origin.y + fromRect.size.height;
    const CGFloat rectYM = fromRect.origin.y + fromRect.size.height * 0.5f;;
    
    const CGFloat widthPlusArrow = contentSize.width + kArrowSize;
    const CGFloat heightPlusArrow = contentSize.height + kArrowSize;
    const CGFloat widthHalf = contentSize.width * 0.5f;
    const CGFloat heightHalf = contentSize.height * 0.5f;
    
    const CGFloat kMargin = 5.f;
    
    if (heightPlusArrow < (outerHeight - rectY1)) {
    
        _arrowDirection = KxMenuViewArrowDirectionUp;
        CGPoint point = (CGPoint){
            rectXM - widthHalf,
            rectY1
        };
        
        if (point.x < kMargin)
            point.x = kMargin;
        
        if ((point.x + contentSize.width + kMargin) > outerWidth)
            point.x = outerWidth - contentSize.width - kMargin;
        
        _arrowPosition = rectXM - point.x;
        _arrowPosition = MAX(20.f, MIN(_arrowPosition, contentSize.width - 20.f));
        _contentView.frame = (CGRect){0, kArrowSize, contentSize};
                
        self.frame = (CGRect) {
            
            point,
            contentSize.width,
            contentSize.height + kArrowSize
        };
        
    } else if (heightPlusArrow < rectY0) {
        
        _arrowDirection = KxMenuViewArrowDirectionDown;
        CGPoint point = (CGPoint){
            rectXM - widthHalf,
            rectY0 - heightPlusArrow
        };
        
        if (point.x < kMargin)
            point.x = kMargin;
        
        if ((point.x + contentSize.width + kMargin) > outerWidth)
            point.x = outerWidth - contentSize.width - kMargin;
        
        _arrowPosition = rectXM - point.x;
        _arrowPosition = MAX(20.f, MIN(_arrowPosition, contentSize.width - 20.f));
        _contentView.frame = (CGRect){CGPointZero, contentSize};
        
        self.frame = (CGRect) {
            
            point,
            contentSize.width,
            contentSize.height + kArrowSize
        };
        
    } else if (widthPlusArrow < (outerWidth - rectX1)) {
        
        _arrowDirection = KxMenuViewArrowDirectionLeft;
        CGPoint point = (CGPoint){
            rectX1,
            rectYM - heightHalf
        };
        
        if (point.y < kMargin)
            point.y = kMargin;
        
        if ((point.y + contentSize.height + kMargin) > outerHeight)
            point.y = outerHeight - contentSize.height - kMargin;
        
        _arrowPosition = rectYM - point.y;
        _contentView.frame = (CGRect){kArrowSize, 0, contentSize};
        
        self.frame = (CGRect) {
            
            point,
            contentSize.width + kArrowSize,
            contentSize.height
        };
        
    } else if (widthPlusArrow < rectX0) {
        
        _arrowDirection = KxMenuViewArrowDirectionRight;
        CGPoint point = (CGPoint){
            rectX0 - widthPlusArrow,
            rectYM - heightHalf
        };
        
        if (point.y < kMargin)
            point.y = kMargin;
        
        if ((point.y + contentSize.height + 5) > outerHeight)
            point.y = outerHeight - contentSize.height - kMargin;
        
        _arrowPosition = rectYM - point.y;
        _contentView.frame = (CGRect){CGPointZero, contentSize};
        
        self.frame = (CGRect) {
            
            point,
            contentSize.width  + kArrowSize,
            contentSize.height
        };
        
    } else {
        
        _arrowDirection = KxMenuViewArrowDirectionNone;
        
        self.frame = (CGRect) {
            
            (outerWidth - contentSize.width)   * 0.5f,
            (outerHeight - contentSize.height) * 0.5f,
            contentSize,
        };
    }    
}

- (void)showMenuInView:(UIView *)view
              fromRect:(CGRect)rect
{
    _contentView = [self mkContentView];
    [self addSubview:_contentView];
    
    [self setupFrameInView:view fromRect:rect];
    
    _contentView.hidden = YES;
    
    const CGRect toFrame = self.frame;
    
    if (_blurredBackground) {
        
        UIColor *tintColor = self.tintColor;
        if (!tintColor) {
            tintColor = [UIColor colorWithRed:0.04f green:0.04f blue:0.04f alpha:0.5f];
        }
        
        _backImage = [KxMenu blurredBackground:view
                                        inRect:toFrame
                                     tintColor:tintColor];
    }
    
    self.frame = (CGRect){self.arrowPoint, 1, 1};
    
    Class overlayClass = _overlayClass ? _overlayClass : [KxMenuOverlay class];
    KxMenuOverlay *overlay = [[overlayClass alloc] initWithFrame:view.bounds];
    [overlay addSubview:self];
    [view addSubview:overlay];
    
    [self setNeedsDisplay];
    
    self.frame = toFrame;
    [UIView animateWithDuration:0.02
                     animations:^(void) {
                         
                         self.alpha = 1.0f;
                         
                     } completion:^(BOOL completed) {
                         
                         _contentView.hidden = NO;
                     }];
   
}

- (void)dismissMenu
{
    [self dismissMenu:YES];
}

- (void)dismissMenu:(BOOL) animated
{
    if (self.completion) {
        self.completion(-1);
        self.completion = nil;
    }
    
    if (!self.superview) {
        return;
    }
    
    if (animated) {
        
        if (_contentView.hidden) {
            [self dismissMenu:NO];
            return;
        }
        
        _contentView.hidden = YES;
        const CGRect toFrame = (CGRect){self.arrowPoint, 1, 1};
        
        [UIView animateWithDuration:0.2
                         animations:^(void) {
                             
                             self.alpha = 0;
                             self.frame = toFrame;
                             
                         } completion:^(BOOL finished) {
                             
                             [self dismissMenu:NO];
                         }];
        
    } else {
        
        Class overlayClass = _overlayClass ? _overlayClass : [KxMenuOverlay class];
        UIView *v = self.superview;
        [self removeFromSuperview];
        if ([v isKindOfClass:overlayClass]) {
            [v removeFromSuperview];
        }
    }
}

- (void)performAction:(id)sender
{
    
    UIButton *button = (UIButton *)sender;
    
    KxMenuItem *menuItem = _menuItems[button.tag];
    [menuItem performAction];
    
    if (self.completion != nil) {
        self.completion(button.tag);
        self.completion = nil;
    }

    [self dismissMenu:YES];
}

- (UIView *) mkContentView
{
    for (UIView *v in self.subviews) {
        [v removeFromSuperview];
    }
    
    if (!_menuItems.count)
        return nil;
 
    const CGFloat kMinMenuItemHeight = 32.f;
    const CGFloat kMinMenuItemWidth = 32.f;
    const CGFloat kMarginX = 10.f;
    const CGFloat kMarginY = 5.f;
    
    UIFont *titleFont = self.titleFont;
    if (!titleFont) titleFont = [UIFont boldSystemFontOfSize:16];
    
    CGFloat maxImageWidth = 0;    
    CGFloat maxItemHeight = 0;
    CGFloat maxItemWidth = 0;
    
    for (KxMenuItem *menuItem in _menuItems) {
        
        const CGSize imageSize = menuItem.image.size;        
        if (imageSize.width > maxImageWidth)
            maxImageWidth = imageSize.width;        
    }
    
    for (KxMenuItem *menuItem in _menuItems) {

        const CGSize titleSize = [menuItem.title sizeWithAttributes:@{NSFontAttributeName: titleFont}];
        const CGSize imageSize = menuItem.image.size;

        const CGFloat itemHeight = MAX(titleSize.height, imageSize.height) + kMarginY * 2;
        const CGFloat itemWidth = ((!menuItem.enabled && !menuItem.image) ? titleSize.width : maxImageWidth + titleSize.width) + kMarginX * 4;
        
        if (itemHeight > maxItemHeight)
            maxItemHeight = itemHeight;
        
        if (itemWidth > maxItemWidth)
            maxItemWidth = itemWidth;
    }
       
    maxItemWidth  = MAX(maxItemWidth, kMinMenuItemWidth);
    maxItemHeight = MAX(maxItemHeight, kMinMenuItemHeight);

    const CGFloat titleX = kMarginX + maxImageWidth;
    const CGFloat titleWidth = maxItemWidth - titleX - kMarginX * 2;
    
    UIImage *selectedImage = [self selectedImage:(CGSize){maxItemWidth, maxItemHeight + 2}];
    UIImage *gradientLine = [KxMenu gradientLine: (CGSize){maxItemWidth - kMarginX * 2, 1}];
    
    UIView *contentView = [[UIView alloc] initWithFrame:CGRectZero];
    contentView.autoresizingMask = UIViewAutoresizingNone;
    contentView.backgroundColor = [UIColor clearColor];
    contentView.opaque = NO;
    
    CGFloat itemY = kMarginY * 2;
    NSUInteger itemNum = 0;
        
    for (KxMenuItem *menuItem in _menuItems) {
                
        const CGRect itemFrame = (CGRect){0, itemY, maxItemWidth, maxItemHeight};
        
        UIView *itemView = [[UIView alloc] initWithFrame:itemFrame];
        itemView.autoresizingMask = UIViewAutoresizingNone;
        itemView.backgroundColor = [UIColor clearColor];        
        itemView.opaque = NO;
                
        [contentView addSubview:itemView];
        
        if (menuItem.enabled) {
        
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            button.tag = itemNum;
            button.frame = itemView.bounds;
            button.enabled = menuItem.enabled;
            button.backgroundColor = [UIColor clearColor];
            button.opaque = NO;
            button.autoresizingMask = UIViewAutoresizingNone;
            
            [button addTarget:self
                       action:@selector(performAction:)
             forControlEvents:UIControlEventTouchUpInside];
            
            [button setBackgroundImage:selectedImage forState:UIControlStateHighlighted];
            
            [itemView addSubview:button];
        }
        
        if (menuItem.title.length) {
            
            CGRect titleFrame;
            
            if (!menuItem.enabled && !menuItem.image) {
                
                titleFrame = (CGRect){
                    kMarginX,
                    kMarginY,
                    maxItemWidth - kMarginX * 2,
                    maxItemHeight - kMarginY * 2
                };
                
            } else {
                
                titleFrame = (CGRect){
                    titleX,
                    kMarginY,
                    titleWidth,
                    maxItemHeight - kMarginY * 2
                };
            }
            
            UILabel *titleLabel = [[UILabel alloc] initWithFrame:titleFrame];
            titleLabel.text = menuItem.title;
            titleLabel.font = titleFont;
            titleLabel.textAlignment = menuItem.alignment;
            titleLabel.textColor = menuItem.foreColor ? menuItem.foreColor : [UIColor whiteColor];
            titleLabel.backgroundColor = [UIColor clearColor];
            titleLabel.autoresizingMask = UIViewAutoresizingNone;
            //titleLabel.backgroundColor = [UIColor greenColor];
            [itemView addSubview:titleLabel];            
        }
        
        if (menuItem.image) {
            
            const CGRect imageFrame = {kMarginX, kMarginY, maxImageWidth, maxItemHeight - kMarginY * 2};
            UIImageView *imageView = [[UIImageView alloc] initWithFrame:imageFrame];
            imageView.image = menuItem.image;
            imageView.clipsToBounds = YES;
            imageView.contentMode = UIViewContentModeCenter;
            imageView.autoresizingMask = UIViewAutoresizingNone;
            [itemView addSubview:imageView];
        }
        
        if (itemNum < _menuItems.count - 1) {
            
            UIImageView *gradientView = [[UIImageView alloc] initWithImage:gradientLine];
            gradientView.frame = (CGRect){kMarginX, maxItemHeight + 1, gradientLine.size};
            gradientView.contentMode = UIViewContentModeLeft;
            [itemView addSubview:gradientView];
            
            itemY += 2;
        }
        
        itemY += maxItemHeight;
        ++itemNum;
    }    
    
    contentView.frame = (CGRect){0, 0, maxItemWidth, itemY + kMarginY * 2};
    
    return contentView;
}

- (CGPoint) arrowPoint
{
    CGPoint point;
    
    if (_arrowDirection == KxMenuViewArrowDirectionUp) {
        
        point = (CGPoint){ CGRectGetMinX(self.frame) + _arrowPosition, CGRectGetMinY(self.frame) };
        
    } else if (_arrowDirection == KxMenuViewArrowDirectionDown) {
        
        point = (CGPoint){ CGRectGetMinX(self.frame) + _arrowPosition, CGRectGetMaxY(self.frame) };
        
    } else if (_arrowDirection == KxMenuViewArrowDirectionLeft) {
        
        point = (CGPoint){ CGRectGetMinX(self.frame), CGRectGetMinY(self.frame) + _arrowPosition  };
        
    } else if (_arrowDirection == KxMenuViewArrowDirectionRight) {
        
        point = (CGPoint){ CGRectGetMaxX(self.frame), CGRectGetMinY(self.frame) + _arrowPosition  };
        
    } else {
        
        point = self.center;
    }
    
    return point;
}

- (UIImage *) selectedImage:(CGSize) size
{
    CGFloat R0 = 0.216, G0 = 0.471, B0 = 0.871;
    CGFloat R1 = 0.059, G1 = 0.353, B1 = 0.839;
    
    if (_selectedColor) {
        CGFloat a;
        [_selectedColor getRed:&R0 green:&G0 blue:&B0 alpha:&a];
    }
    
    if (_selectedColor1) {
        CGFloat a;
        [_selectedColor1 getRed:&R1 green:&G1 blue:&B1 alpha:&a];
    }
    
    const CGFloat locations[] = {0,1};
    const CGFloat components[] = {
        R0, G0, B0, 1,
        R1, G1, B1, 1,
    };
    
    return [KxMenu gradientImageWithSize:size locations:locations components:components count:2];
}

+ (UIImage *) gradientLine:(CGSize) size
{
    const CGFloat locations[5] = {0,0.2,0.5,0.8,1};
    
    const CGFloat R = 0.44f, G = 0.44f, B = 0.44f;
        
    const CGFloat components[20] = {
        R,G,B,0.1,
        R,G,B,0.4,
        R,G,B,0.7,
        R,G,B,0.4,
        R,G,B,0.1
    };
    
    return [self gradientImageWithSize:size locations:locations components:components count:5];
}

+ (UIImage *) gradientImageWithSize:(CGSize) size
                          locations:(const CGFloat []) locations
                         components:(const CGFloat []) components
                              count:(NSUInteger)count
{
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGGradientRef colorGradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, 2);
    CGColorSpaceRelease(colorSpace);
    CGContextDrawLinearGradient(context, colorGradient, (CGPoint){0, 0}, (CGPoint){size.width, 0}, 0);
    CGGradientRelease(colorGradient);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void) drawRect:(CGRect)rect
{
    [self drawBackground:self.bounds
               inContext:UIGraphicsGetCurrentContext()];
}

- (void)drawBackground:(CGRect)frame
             inContext:(CGContextRef) context
{
    CGFloat X0 = frame.origin.x;
    CGFloat X1 = frame.origin.x + frame.size.width;
    CGFloat Y0 = frame.origin.y;
    CGFloat Y1 = frame.origin.y + frame.size.height;
    
    // render arrow
    
    UIBezierPath *arrowPath = [UIBezierPath bezierPath];
    
    if (_arrowDirection == KxMenuViewArrowDirectionUp) {
        
        const CGFloat arrowXM = _arrowPosition;
        const CGFloat arrowX0 = arrowXM - kArrowSize;
        const CGFloat arrowX1 = arrowXM + kArrowSize;
        const CGFloat arrowY0 = Y0;
        const CGFloat arrowY1 = Y0 + kArrowSize;
        
        [arrowPath moveToPoint:    (CGPoint){arrowXM, arrowY0}];
        [arrowPath addLineToPoint: (CGPoint){arrowX1, arrowY1}];
        [arrowPath addLineToPoint: (CGPoint){arrowX0, arrowY1}];
        [arrowPath addLineToPoint: (CGPoint){arrowXM, arrowY0}];
        
        Y0 += kArrowSize;
        
    } else if (_arrowDirection == KxMenuViewArrowDirectionDown) {
        
        const CGFloat arrowXM = _arrowPosition;
        const CGFloat arrowX0 = arrowXM - kArrowSize;
        const CGFloat arrowX1 = arrowXM + kArrowSize;
        const CGFloat arrowY0 = Y1 - kArrowSize;
        const CGFloat arrowY1 = Y1;
        
        [arrowPath moveToPoint:    (CGPoint){arrowXM, arrowY1}];
        [arrowPath addLineToPoint: (CGPoint){arrowX1, arrowY0}];
        [arrowPath addLineToPoint: (CGPoint){arrowX0, arrowY0}];
        [arrowPath addLineToPoint: (CGPoint){arrowXM, arrowY1}];
        
        Y1 -= kArrowSize;
        
    } else if (_arrowDirection == KxMenuViewArrowDirectionLeft) {
        
        const CGFloat arrowYM = _arrowPosition;        
        const CGFloat arrowX0 = X0;
        const CGFloat arrowX1 = X0 + kArrowSize;
        const CGFloat arrowY0 = arrowYM - kArrowSize;;
        const CGFloat arrowY1 = arrowYM + kArrowSize;
        
        [arrowPath moveToPoint:    (CGPoint){arrowX0, arrowYM}];
        [arrowPath addLineToPoint: (CGPoint){arrowX1, arrowY0}];
        [arrowPath addLineToPoint: (CGPoint){arrowX1, arrowY1}];
        [arrowPath addLineToPoint: (CGPoint){arrowX0, arrowYM}];
        
        X0 += kArrowSize;
        
    } else if (_arrowDirection == KxMenuViewArrowDirectionRight) {
        
        const CGFloat arrowYM = _arrowPosition;        
        const CGFloat arrowX0 = X1;
        const CGFloat arrowX1 = X1 - kArrowSize;
        const CGFloat arrowY0 = arrowYM - kArrowSize;;
        const CGFloat arrowY1 = arrowYM + kArrowSize;
        
        [arrowPath moveToPoint:    (CGPoint){arrowX0, arrowYM}];
        [arrowPath addLineToPoint: (CGPoint){arrowX1, arrowY0}];
        [arrowPath addLineToPoint: (CGPoint){arrowX1, arrowY1}];
        [arrowPath addLineToPoint: (CGPoint){arrowX0, arrowYM}];
        
        X1 -= kArrowSize;
    }
    
    const CGRect bodyFrame = {X0, Y0, X1 - X0, Y1 - Y0};
    
    UIBezierPath *borderPath = [UIBezierPath bezierPathWithRoundedRect:bodyFrame
                                                          cornerRadius:8];
    
    if (_backImage)
    {
        [borderPath appendPath:arrowPath];
        [borderPath addClip];
        [_backImage drawInRect:frame];
        
    } else {
    
        CGFloat R0 = 0.267, G0 = 0.303, B0 = 0.335;
        CGFloat R1 = 0.040, G1 = 0.040, B1 = 0.040;
        
        if (_tintColor) {
            CGFloat a;
            [_tintColor getRed:&R0 green:&G0 blue:&B0 alpha:&a];
        }

        if (_tintColor1) {
            CGFloat a;
            [_tintColor1 getRed:&R1 green:&G1 blue:&B1 alpha:&a];
        }
        
        if (_arrowDirection == KxMenuViewArrowDirectionUp ||
            _arrowDirection == KxMenuViewArrowDirectionLeft) {
            
            [[UIColor colorWithRed:R0 green:G0 blue:B0 alpha:1] set];
            
        } else {
            
            [[UIColor colorWithRed:R1 green:G1 blue:B1 alpha:1] set];
        }
        
        [arrowPath fill];

        // render body
        
        const CGFloat locations[] = {0, 1};
        const CGFloat components[] = {
            R0, G0, B0, 1,
            R1, G1, B1, 1,
        };
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace,
                                                                     components,
                                                                     locations,
                                                                     sizeof(locations)/sizeof(locations[0]));
        CGColorSpaceRelease(colorSpace);
        
        
        [borderPath addClip];
        
        CGPoint start, end;
        
        if (_arrowDirection == KxMenuViewArrowDirectionLeft ||
            _arrowDirection == KxMenuViewArrowDirectionRight) {
            
            start = (CGPoint){X0, Y0};
            end = (CGPoint){X1, Y0};
            
        } else {
            
            start = (CGPoint){X0, Y0};
            end = (CGPoint){X0, Y1};
        }
        
        CGContextDrawLinearGradient(context, gradient, start, end, 0);
        
        CGGradientRelease(gradient);
    }
}

+ (UIImage *) blurredBackground:(UIView *)v
                         inRect:(CGRect)rect
                      tintColor:(UIColor *)tintColor
{
    const CGFloat screenScale = 1.0f; //v.window.screen.scale;
    
    UIImage *image;

    UIGraphicsBeginImageContextWithOptions(rect.size, NO, screenScale);
    
    CGContextTranslateCTM(UIGraphicsGetCurrentContext(),
                          -rect.origin.x,
                          -rect.origin.y);
    
    if ([v respondsToSelector:@selector(drawViewHierarchyInRect:afterScreenUpdates:)] &&
        [v drawViewHierarchyInRect:v.bounds afterScreenUpdates:NO])
    {
        image = UIGraphicsGetImageFromCurrentImageContext();
    }
    
    if (!image) {
        
        [v.layer renderInContext:UIGraphicsGetCurrentContext()];
        image = UIGraphicsGetImageFromCurrentImageContext();
    }
    
    UIGraphicsEndImageContext();

    return [image applyBlurWithRadius:6
                            tintColor:tintColor
                saturationDeltaFactor:1.8
                            maskImage:nil];
}

+ (instancetype) showMenuInView:(UIView *)view
                       fromRect:(CGRect)rect
                      menuItems:(NSArray *)menuItems
{
    KxMenu *menu = [[self alloc] init];
    menu.menuItems = menuItems;
    dispatch_async(dispatch_get_main_queue(), ^{
        // it allows to tune parameters before showing menu
        [menu showMenuInView:view fromRect:rect];
    });
    return menu;
}

+ (instancetype) showMenuInView:(UIView *)view
                       fromRect:(CGRect)rect
                      menuItems:(NSArray *)menuItems
                     completion:(void (^)(NSInteger)) completion
{
    KxMenu *menu = [[self alloc] init];
    menu.menuItems = menuItems;
    menu.completion = completion;
    dispatch_async(dispatch_get_main_queue(), ^{
        // it allows to tune parameters before showing menu
        [menu showMenuInView:view fromRect:rect];
    });
    return menu;
}

@end
