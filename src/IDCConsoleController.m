#import "IDCConsoleController.h"
#import "IDCCommandEngine.h"
#import "IDCLogger.h"
#import "IDCNativeBridge.h"

#import <UIKit/UIKit.h>

static const NSInteger IDCInteractiveTag = 0x1DC;

@interface IDCPassthroughView : UIView
@end

@implementation IDCPassthroughView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (!hit || hit == self) return nil;
    if ([hit isKindOfClass:UIControl.class]) return hit;
    for (UIView *view = hit; view && view != self; view = view.superview) {
        if (view.tag == IDCInteractiveTag) return hit;
    }
    return nil;
}
@end

@interface IDCConsoleController () <UITextFieldDelegate, UITableViewDataSource,
                                    UITableViewDelegate>
@property(nonatomic, strong) IDCNativeBridge *bridge;
@property(nonatomic, strong) IDCCommandEngine *engine;
@property(nonatomic, strong) IDCPassthroughView *rootView;
@property(nonatomic, strong) UIButton *consoleButton;
@property(nonatomic, strong) UIView *panel;
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) UITextView *outputView;
@property(nonatomic, strong) UITableView *suggestionsTable;
@property(nonatomic, strong) UITextField *inputField;
@property(nonatomic, strong) UIButton *runButton;
@property(nonatomic, strong) UIButton *previousButton;
@property(nonatomic, strong) UIButton *nextButton;
@property(nonatomic, strong) UIButton *keyboardButton;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, copy) NSArray<IDCCommandSuggestion *> *suggestions;
@property(nonatomic, strong) NSMutableArray<NSString *> *history;
@property(nonatomic) NSInteger historyIndex;
@property(nonatomic) CGFloat keyboardOverlap;
@property(nonatomic) BOOL keyboardVisible;
@end

@implementation IDCConsoleController

- (instancetype)initWithBridge:(IDCNativeBridge *)bridge engine:(IDCCommandEngine *)engine {
    self = [super init];
    if (self) {
        _bridge = bridge;
        _engine = engine;
        _suggestions = @[];
        _history = [NSMutableArray array];
        _historyIndex = 0;
    }
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)start {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        [center addObserver:self selector:@selector(keyboardFrameChanged:)
                       name:UIKeyboardWillChangeFrameNotification object:nil];
        [center addObserver:self selector:@selector(keyboardWillHide:)
                       name:UIKeyboardWillHideNotification object:nil];
        [self attachIfNeeded];
        self.timer = [NSTimer scheduledTimerWithTimeInterval:0.25 target:self
                                                    selector:@selector(tick:)
                                                    userInfo:nil repeats:YES];
    });
}

- (UIWindow *)gameWindow {
    UIWindow *fallback = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.hidden || window.alpha <= 0 || window.windowLevel != UIWindowLevelNormal) continue;
            if (window.isKeyWindow) return window;
            if (!fallback) fallback = window;
        }
    }
    return fallback;
}

- (UIButton *)buttonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.96];
    button.layer.cornerRadius = 7;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.20].CGColor;
    button.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)attachIfNeeded {
    UIWindow *window = [self gameWindow];
    if (!window || CGRectIsEmpty(window.bounds)) return;
    if (self.rootView.superview == window) return;
    [self.rootView removeFromSuperview];

    IDCPassthroughView *root = [[IDCPassthroughView alloc] initWithFrame:window.bounds];
    root.backgroundColor = UIColor.clearColor;
    root.userInteractionEnabled = YES;
    root.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    UIButton *consoleButton = [self buttonWithTitle:@"Console" action:@selector(toggleConsole:)];
    consoleButton.frame = CGRectMake(14, window.bounds.size.height - 48, 82, 34);
    consoleButton.backgroundColor = [UIColor colorWithWhite:0 alpha:0.78];
    consoleButton.layer.cornerRadius = 8;
    consoleButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.28].CGColor;
    consoleButton.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    consoleButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleTopMargin;
    consoleButton.hidden = YES;

    UIView *panel = [[UIView alloc] initWithFrame:CGRectZero];
    panel.backgroundColor = [UIColor colorWithRed:0.025 green:0.030 blue:0.038 alpha:0.97];
    panel.layer.cornerRadius = 12;
    panel.layer.borderWidth = 1;
    panel.layer.borderColor = [UIColor colorWithRed:0.35 green:0.78 blue:1 alpha:0.7].CGColor;
    panel.clipsToBounds = YES;
    panel.tag = IDCInteractiveTag;
    panel.hidden = YES;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectZero];
    title.text = @"Isaac Debug Console";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightBold];
    title.tag = 1001;
    [panel addSubview:title];

    UILabel *status = [[UILabel alloc] initWithFrame:CGRectZero];
    status.textColor = [UIColor colorWithWhite:0.68 alpha:1];
    status.textAlignment = NSTextAlignmentRight;
    status.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
    [panel addSubview:status];

    UIButton *close = [self buttonWithTitle:@"×" action:@selector(closeConsole:)];
    close.titleLabel.font = [UIFont systemFontOfSize:19 weight:UIFontWeightSemibold];
    close.tag = 1002;
    [panel addSubview:close];

    UITextView *output = [[UITextView alloc] initWithFrame:CGRectZero];
    output.backgroundColor = [UIColor colorWithWhite:0 alpha:0.42];
    output.textColor = [UIColor colorWithRed:0.80 green:0.93 blue:1 alpha:1];
    output.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    output.editable = NO;
    output.selectable = YES;
    output.layer.cornerRadius = 6;
    output.textContainerInset = UIEdgeInsetsMake(7, 8, 7, 8);
    output.text = @"Isaac Debug Console iOS 0.1.1\nType help for commands. Suggestions update while you type.\n";
    [panel addSubview:output];

    UITableView *suggestionsTable = [[UITableView alloc] initWithFrame:CGRectZero
                                                                 style:UITableViewStylePlain];
    suggestionsTable.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.98];
    suggestionsTable.separatorColor = [UIColor colorWithWhite:1 alpha:0.12];
    suggestionsTable.rowHeight = 32;
    suggestionsTable.dataSource = self;
    suggestionsTable.delegate = self;
    suggestionsTable.layer.cornerRadius = 6;
    suggestionsTable.hidden = YES;
    [panel addSubview:suggestionsTable];

    UITextField *input = [[UITextField alloc] initWithFrame:CGRectZero];
    input.backgroundColor = [UIColor colorWithWhite:0.10 alpha:1];
    input.textColor = UIColor.whiteColor;
    input.tintColor = UIColor.systemCyanColor;
    input.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    input.layer.cornerRadius = 7;
    input.layer.borderWidth = 1;
    input.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.20].CGColor;
    input.placeholder = @"Enter a command…";
    input.attributedPlaceholder = [[NSAttributedString alloc] initWithString:input.placeholder
        attributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:0.55 alpha:1]}];
    input.autocorrectionType = UITextAutocorrectionTypeNo;
    input.autocapitalizationType = UITextAutocapitalizationTypeNone;
    input.spellCheckingType = UITextSpellCheckingTypeNo;
    input.returnKeyType = UIReturnKeyGo;
    input.clearButtonMode = UITextFieldViewModeWhileEditing;
    input.delegate = self;
    [input addTarget:self action:@selector(inputChanged:)
       forControlEvents:UIControlEventEditingChanged];
    UIView *padding = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 9, 1)];
    input.leftView = padding;
    input.leftViewMode = UITextFieldViewModeAlways;
    [panel addSubview:input];

    UIButton *previous = [self buttonWithTitle:@"↑" action:@selector(previousHistory:)];
    UIButton *next = [self buttonWithTitle:@"↓" action:@selector(nextHistory:)];
    UIButton *keyboard = [self buttonWithTitle:@"⌨︎↓" action:@selector(toggleKeyboard:)];
    keyboard.accessibilityLabel = @"Hide keyboard";
    UIButton *run = [self buttonWithTitle:@"Run" action:@selector(runCommand:)];
    run.backgroundColor = [UIColor colorWithRed:0.05 green:0.48 blue:0.68 alpha:1];
    [panel addSubview:previous];
    [panel addSubview:next];
    [panel addSubview:keyboard];
    [panel addSubview:run];

    [root addSubview:consoleButton];
    [root addSubview:panel];
    [window addSubview:root];
    self.rootView = root;
    self.consoleButton = consoleButton;
    self.panel = panel;
    self.statusLabel = status;
    self.outputView = output;
    self.suggestionsTable = suggestionsTable;
    self.inputField = input;
    self.previousButton = previous;
    self.nextButton = next;
    self.keyboardButton = keyboard;
    self.runButton = run;
    [self layoutConsole];
    [self updateSuggestions];
    IDCLog(@"console overlay attached to Isaac window");
}

- (void)layoutConsole {
    if (!self.rootView || !self.panel) return;
    CGFloat width = self.rootView.bounds.size.width;
    CGFloat usableHeight = MAX(180, self.rootView.bounds.size.height - self.keyboardOverlap);
    CGFloat panelWidth = MIN(760, MAX(300, width - 20));
    CGFloat panelHeight = MIN(390, MAX(180, usableHeight - 14));
    self.panel.frame = CGRectMake((width - panelWidth) * 0.5,
                                  MAX(5, (usableHeight - panelHeight) * 0.5),
                                  panelWidth, panelHeight);
    UILabel *title = [self.panel viewWithTag:1001];
    UIButton *close = [self.panel viewWithTag:1002];
    title.frame = CGRectMake(12, 7, panelWidth * 0.48, 28);
    close.frame = CGRectMake(panelWidth - 43, 6, 35, 30);
    self.statusLabel.frame = CGRectMake(panelWidth * 0.43, 8, panelWidth * 0.50 - 49, 26);

    CGFloat bottomY = panelHeight - 44;
    CGFloat historyWidth = 34;
    CGFloat keyboardWidth = 40;
    CGFloat runWidth = 52;
    self.previousButton.frame = CGRectMake(8, bottomY, historyWidth, 34);
    self.nextButton.frame = CGRectMake(46, bottomY, historyWidth, 34);
    self.keyboardButton.frame = CGRectMake(84, bottomY, keyboardWidth, 34);
    self.runButton.frame = CGRectMake(panelWidth - runWidth - 8, bottomY, runWidth, 34);
    CGFloat inputX = CGRectGetMaxX(self.keyboardButton.frame) + 4;
    self.inputField.frame = CGRectMake(inputX, bottomY,
        MAX(72, panelWidth - inputX - runWidth - 12), 34);

    CGFloat suggestionHeight = self.suggestions.count
        ? MIN(96, self.suggestions.count * self.suggestionsTable.rowHeight) : 0;
    CGFloat outputTop = 40;
    CGFloat outputBottom = bottomY - 6 - suggestionHeight;
    self.outputView.frame = CGRectMake(8, outputTop, panelWidth - 16,
                                       MAX(60, outputBottom - outputTop));
    self.suggestionsTable.frame = CGRectMake(8, CGRectGetMaxY(self.outputView.frame) + 4,
                                              panelWidth - 16, suggestionHeight);
    self.suggestionsTable.hidden = suggestionHeight <= 0;
}

- (void)tick:(NSTimer *)timer {
    (void)timer;
    [self attachIfNeeded];
    IDCNativeSnapshot *snapshot = [self.bridge refreshSnapshot];
    BOOL available = snapshot.supportedBuild && snapshot.inGame &&
        snapshot.pauseStateAvailable && snapshot.paused;
    self.consoleButton.hidden = !available;
    self.statusLabel.text = snapshot.inGame
        ? [NSString stringWithFormat:@"%@ · seed %08X", snapshot.paused ? @"PAUSED" : @"PLAYING",
           snapshot.runSeed]
        : @"NO ACTIVE RUN";
    if (!available && !self.panel.hidden) [self closeConsole:nil];
    if (!self.panel.hidden) [self.rootView bringSubviewToFront:self.panel];
}

- (void)toggleConsole:(UIButton *)sender {
    (void)sender;
    if (self.panel.hidden) {
        self.panel.hidden = NO;
        [self.rootView bringSubviewToFront:self.panel];
        [self layoutConsole];
        [self.inputField becomeFirstResponder];
    } else {
        [self closeConsole:nil];
    }
}

- (void)closeConsole:(UIButton *)sender {
    (void)sender;
    self.panel.hidden = YES;
    self.keyboardOverlap = 0;
    [self.inputField resignFirstResponder];
    [self layoutConsole];
}

- (void)appendLine:(NSString *)line {
    if (!line.length) return;
    NSString *existing = self.outputView.text ?: @"";
    self.outputView.text = [existing stringByAppendingFormat:@"%@%@\n",
                            existing.length && ![existing hasSuffix:@"\n"] ? @"\n" : @"", line];
    NSRange end = NSMakeRange(self.outputView.text.length, 0);
    [self.outputView scrollRangeToVisible:end];
}

- (void)runCommand:(UIButton *)sender {
    (void)sender;
    NSString *input = [self.inputField.text stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!input.length) return;
    [self appendLine:[@"> " stringByAppendingString:input]];
    if (![self.history.lastObject isEqualToString:input]) [self.history addObject:input];
    self.historyIndex = self.history.count;
    IDCCommandResult *result = [self.engine executeInput:input];
    if (result.action == IDCCommandActionClear) {
        self.outputView.text = @"";
    } else if (result.action == IDCCommandActionClose) {
        [self closeConsole:nil];
    } else if (result.action == IDCCommandActionHistory) {
        if (!self.history.count) {
            [self appendLine:@"History is empty."];
        } else {
            NSMutableArray<NSString *> *lines = [NSMutableArray array];
            [self.history enumerateObjectsUsingBlock:
                ^(NSString *command, NSUInteger index, BOOL *stop) {
                (void)stop;
                [lines addObject:[NSString stringWithFormat:@"%lu  %@",
                                  (unsigned long)(index + 1), command]];
            }];
            [self appendLine:[lines componentsJoinedByString:@"\n"]];
        }
    } else if (result.output.length) {
        [self appendLine:result.output];
    }
    self.inputField.text = @"";
    [self updateSuggestions];
}

- (void)previousHistory:(UIButton *)sender {
    (void)sender;
    if (!self.history.count) return;
    self.historyIndex = MAX(0, self.historyIndex - 1);
    self.inputField.text = self.history[(NSUInteger)self.historyIndex];
    [self updateSuggestions];
}

- (void)nextHistory:(UIButton *)sender {
    (void)sender;
    if (!self.history.count) return;
    self.historyIndex = MIN((NSInteger)self.history.count, self.historyIndex + 1);
    self.inputField.text = self.historyIndex < (NSInteger)self.history.count
        ? self.history[(NSUInteger)self.historyIndex] : @"";
    [self updateSuggestions];
}

- (void)toggleKeyboard:(UIButton *)sender {
    (void)sender;
    if (self.inputField.isFirstResponder) {
        [self.inputField resignFirstResponder];
        self.keyboardVisible = NO;
        [self.keyboardButton setTitle:@"⌨︎↑" forState:UIControlStateNormal];
        self.keyboardButton.accessibilityLabel = @"Show keyboard";
    } else {
        [self.inputField becomeFirstResponder];
        self.keyboardVisible = YES;
        [self.keyboardButton setTitle:@"⌨︎↓" forState:UIControlStateNormal];
        self.keyboardButton.accessibilityLabel = @"Hide keyboard";
    }
}

- (void)inputChanged:(UITextField *)field {
    (void)field;
    [self updateSuggestions];
}

- (void)updateSuggestions {
    self.suggestions = [self.engine suggestionsForInput:self.inputField.text ?: @"" limit:5];
    [self.suggestionsTable reloadData];
    [self layoutConsole];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    (void)textField;
    [self runCommand:nil];
    return NO;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return self.suggestions.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"Suggestion";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                             reuseIdentifier:identifier];
    cell.backgroundColor = UIColor.clearColor;
    cell.textLabel.textColor = [UIColor colorWithWhite:0.9 alpha:1];
    cell.textLabel.font = [UIFont monospacedSystemFontOfSize:10.5 weight:UIFontWeightRegular];
    cell.textLabel.text = self.suggestions[(NSUInteger)indexPath.row].displayText;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    IDCCommandSuggestion *suggestion = self.suggestions[(NSUInteger)indexPath.row];
    self.inputField.text = suggestion.replacementText;
    [self updateSuggestions];
    [self.inputField becomeFirstResponder];
}

- (void)keyboardFrameChanged:(NSNotification *)notification {
    UIWindow *window = [self gameWindow];
    if (!window) return;
    CGRect screenFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect localFrame = [window convertRect:screenFrame fromWindow:nil];
    self.keyboardOverlap = MAX(0, CGRectGetMaxY(window.bounds) - CGRectGetMinY(localFrame));
    self.keyboardVisible = self.keyboardOverlap > 1;
    [self.keyboardButton setTitle:self.keyboardVisible ? @"⌨︎↓" : @"⌨︎↑"
                         forState:UIControlStateNormal];
    self.keyboardButton.accessibilityLabel = self.keyboardVisible
        ? @"Hide keyboard" : @"Show keyboard";
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey]
        doubleValue];
    [UIView animateWithDuration:duration animations:^{ [self layoutConsole]; }];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey]
        doubleValue];
    self.keyboardOverlap = 0;
    self.keyboardVisible = NO;
    [self.keyboardButton setTitle:@"⌨︎↑" forState:UIControlStateNormal];
    self.keyboardButton.accessibilityLabel = @"Show keyboard";
    [UIView animateWithDuration:duration animations:^{ [self layoutConsole]; }];
}

@end
