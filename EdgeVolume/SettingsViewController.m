#import "SettingsViewController.h"
#import "EVSettings.h"
#import "VolumeController.h"
#import "AppDelegate.h"

typedef NS_ENUM(NSInteger, EVRowTag) {
    EVRowEnabled = 100,
    EVRowOverlay,
    EVRowEdge,
    EVRowLength,
    EVRowAlpha,
    EVRowLock,
    EVRowTouchMode,
    EVRowCategory,
    EVRowVolumeNow,
    EVRowTestVolume,
    EVRowKeepAlive,
    EVRowStatus,
    EVRowReset
};

@interface SettingsViewController ()
@property (nonatomic, assign) BOOL suppressReload;

- (UITableViewCell *)textCellWithTitle:(NSString *)title detail:(NSString *)detail in:(UITableView *)tableView;
- (UITableViewCell *)switchCellWithTitle:(NSString *)title tag:(NSInteger)tag on:(BOOL)on in:(UITableView *)tableView;
- (UITableViewCell *)segmentCellWithTitle:(NSString *)title items:(NSArray *)items tag:(NSInteger)tag selected:(NSInteger)selected in:(UITableView *)tableView;
- (UITableViewCell *)sliderCellWithTitle:(NSString *)title tag:(NSInteger)tag value:(CGFloat)value min:(CGFloat)min max:(CGFloat)max unit:(NSString *)unit in:(UITableView *)tableView;
- (UITableViewCell *)buttonCellWithTitle:(NSString *)title tag:(NSInteger)tag in:(UITableView *)tableView;
- (NSString *)statusText;
@end

@implementation SettingsViewController

- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self) {
        self.title = @"边缘音量";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(reloadQuietly) name:kEVSettingsChangedNotification object:nil];
    [nc addObserver:self selector:@selector(reloadQuietly) name:kEVOverlayStatusChangedNotification object:nil];
    [nc addObserver:self selector:@selector(backendChanged) name:kEVVolumeBackendChangedNotification object:nil];
    [nc addObserver:self selector:@selector(volumeChanged) name:kEVSystemVolumeChangedNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - 通知

- (void)reloadQuietly {
    if (self.suppressReload) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.tableView) [self.tableView reloadData];
    });
}

- (void)backendChanged {
    [self reloadQuietly];
}

- (void)volumeChanged {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.tableView) return;
        NSIndexPath *ip = [NSIndexPath indexPathForRow:1 inSection:1];
        [self.tableView reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
    });
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 7;
        case 1: return 3;
        default: return 3;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"悬浮条";
        case 1: return @"音量";
        default: return @"高级";
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"上下滑动滑动条 = 调节音量；左右拖动 = 移动位置；单击 = 显示当前音量；长按 = 紧急隐藏悬浮窗。";
        case 1: return @"若测试无效，请切换音量类别（部分机型的媒体音量与铃声音量是分开的）。";
        default: return @"重启 iPad 后需要重新打开一次本应用，悬浮条才会出现。";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        switch (indexPath.row) {
            case 0: return [self switchCellWithTitle:@"全局悬浮窗" tag:EVRowOverlay on:[EVSettings shared].overlayEnabled in:tableView];
            case 1: return [self switchCellWithTitle:@"启用悬浮条" tag:EVRowEnabled on:[EVSettings shared].enabled in:tableView];
            case 2: return [self segmentCellWithTitle:@"贴边位置" items:@[@"左", @"右"] tag:EVRowEdge selected:[EVSettings shared].edge in:tableView];
            case 3: return [self sliderCellWithTitle:@"长度" tag:EVRowLength value:[EVSettings shared].trackLength min:80 max:320 unit:@"pt" in:tableView];
            case 4: return [self sliderCellWithTitle:@"不透明度" tag:EVRowAlpha value:[EVSettings shared].trackAlpha min:0.05 max:1.0 unit:@"" in:tableView];
            case 5: return [self switchCellWithTitle:@"锁定位置" tag:EVRowLock on:[EVSettings shared].lockPosition in:tableView];
            case 6: return [self segmentCellWithTitle:@"触摸模式" items:@[@"小窗", @"全屏"] tag:EVRowTouchMode selected:([EVSettings shared].smallWindowMode ? 0 : 1) in:tableView];
        }
    }
    else if (indexPath.section == 1) {
        switch (indexPath.row) {
            case 0: return [self segmentCellWithTitle:@"音量类别" items:@[@"媒体", @"铃声"] tag:EVRowCategory selected:[EVSettings shared].volumeCategory in:tableView];
            case 1: {
                float v = [VolumeController shared].volume;
                UITableViewCell *cell = [self textCellWithTitle:@"当前音量" detail:[NSString stringWithFormat:@"%d%%", (int)lroundf(v * 100.0f)] in:tableView];
                return cell;
            }
            case 2: return [self buttonCellWithTitle:@"测试：把音量设为 50%" tag:EVRowTestVolume in:tableView];
        }
    }
    else {
        switch (indexPath.row) {
            case 0: return [self switchCellWithTitle:@"后台保活（静音播放）" tag:EVRowKeepAlive on:[EVSettings shared].keepAlive in:tableView];
            case 1: {
                UITableViewCell *cell = [self textCellWithTitle:@"运行状态" detail:[self statusText] in:tableView];
                cell.textLabel.numberOfLines = 0;
                cell.detailTextLabel.numberOfLines = 0;
                cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
                return cell;
            }
            case 2: return [self buttonCellWithTitle:@"恢复默认位置与外观" tag:EVRowReset in:tableView];
        }
    }
    return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"EVEmpty"];
}

#pragma mark - 单元格构造

- (UITableViewCell *)switchCellWithTitle:(NSString *)title tag:(NSInteger)tag on:(BOOL)on in:(UITableView *)tableView {
    NSString *rid = [NSString stringWithFormat:@"EVSwitch%ld", (long)tag];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:rid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:rid];
        UISwitch *sw = [[UISwitch alloc] init];
        sw.tag = tag;
        [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
    }
    cell.textLabel.text = title;
    ((UISwitch *)cell.accessoryView).on = on;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (UITableViewCell *)segmentCellWithTitle:(NSString *)title items:(NSArray *)items tag:(NSInteger)tag selected:(NSInteger)selected in:(UITableView *)tableView {
    NSString *rid = [NSString stringWithFormat:@"EVSegment%ld", (long)tag];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:rid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:rid];
        UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:items];
        seg.tag = tag;
        seg.frame = CGRectMake(0.0, 0.0, 120.0, 31.0);
        [seg addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = seg;
    }
    cell.textLabel.text = title;
    ((UISegmentedControl *)cell.accessoryView).selectedSegmentIndex = selected;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (UITableViewCell *)sliderCellWithTitle:(NSString *)title tag:(NSInteger)tag value:(CGFloat)value min:(CGFloat)min max:(CGFloat)max unit:(NSString *)unit in:(UITableView *)tableView {
    NSString *rid = [NSString stringWithFormat:@"EVSlider%ld", (long)tag];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:rid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:rid];
        UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(0.0, 0.0, 130.0, 31.0)];
        slider.tag = tag;
        slider.minimumValue = min;
        slider.maximumValue = max;
        [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
        [slider addTarget:self action:@selector(sliderTouchUp:) forControlEvents:UIControlEventTouchUpInside];
        cell.accessoryView = slider;
    }
    cell.textLabel.text = title;
    UISlider *slider = (UISlider *)cell.accessoryView;
    slider.value = value;
    if (unit.length > 0) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%.0f%@", value, unit];
    } else {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%.0f%%", value * 100.0];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (UITableViewCell *)buttonCellWithTitle:(NSString *)title tag:(NSInteger)tag in:(UITableView *)tableView {
    NSString *rid = [NSString stringWithFormat:@"EVButton%ld", (long)tag];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:rid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:rid];
    }
    cell.tag = tag;
    cell.textLabel.text = title;
    cell.textLabel.textAlignment = NSTextAlignmentCenter;
    cell.textLabel.textColor = [UIColor systemBlueColor];
    cell.accessoryView = nil;
    return cell;
}

- (UITableViewCell *)textCellWithTitle:(NSString *)title detail:(NSString *)detail in:(UITableView *)tableView {
    NSString *rid = @"EVText";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:rid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:rid];
    }
    cell.textLabel.text = title;
    cell.detailTextLabel.text = detail;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

#pragma mark - 控件事件

- (void)switchChanged:(UISwitch *)sw {
    self.suppressReload = YES;
    switch (sw.tag) {
        case EVRowOverlay:  [EVSettings shared].overlayEnabled = sw.on;
                            if (sw.on) {
                                AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
                                [ad startFloatingOverlay];
                                [ad setOverlayHidden:NO];   // 已初始化过时取消隐藏
                            } else {
                                [(AppDelegate *)[UIApplication sharedApplication].delegate setOverlayHidden:YES];
                            }
                            break;
        case EVRowEnabled:   [EVSettings shared].enabled = sw.on; break;
        case EVRowLock:      [EVSettings shared].lockPosition = sw.on; break;
        case EVRowKeepAlive: [EVSettings shared].keepAlive = sw.on;
                           [[VolumeController shared] setKeepAliveEnabled:sw.on]; break;
    }
    self.suppressReload = NO;
}

- (void)segmentChanged:(UISegmentedControl *)seg {
    self.suppressReload = YES;
    switch (seg.tag) {
        case EVRowEdge:      [EVSettings shared].edge = (EVEdge)seg.selectedSegmentIndex; break;
        case EVRowTouchMode: [EVSettings shared].smallWindowMode = (seg.selectedSegmentIndex == 0); break;
        case EVRowCategory:  [EVSettings shared].volumeCategory = seg.selectedSegmentIndex; break;
    }
    self.suppressReload = NO;
}

- (void)sliderChanged:(UISlider *)slider {
    self.suppressReload = YES;
    switch (slider.tag) {
        case EVRowLength: [EVSettings shared].trackLength = slider.value; break;
        case EVRowAlpha:  [EVSettings shared].trackAlpha = slider.value; break;
    }
    self.suppressReload = NO;
    // 只刷新数值文本，避免打断拖动
    for (UITableViewCell *cell in [self.tableView visibleCells]) {
        if (cell.accessoryView == slider && [cell isKindOfClass:[UITableViewCell class]]) {
            if (slider.tag == EVRowLength) {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.0fpt", slider.value];
            } else {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.0f%%", slider.value * 100.0];
            }
        }
    }
}

- (void)sliderTouchUp:(UISlider *)slider {
    [self reloadQuietly];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if (cell.accessoryView) return;
    if (cell.tag == EVRowTestVolume) {
        // 测试：设为 50%
        [[VolumeController shared] applyVolume:0.5];
    } else if (cell.tag == EVRowReset) {
        // 恢复默认
        self.suppressReload = YES;
        [EVSettings shared].edge = EVEdgeRight;
        [EVSettings shared].centerYFraction = 0.45;
        [EVSettings shared].trackLength = 180.0;
        [EVSettings shared].trackAlpha = 0.55;
        self.suppressReload = NO;
        [self reloadQuietly];
    }
}

#pragma mark - 状态文本

- (NSString *)statusText {
    AppDelegate *ad = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSMutableArray *parts = [NSMutableArray array];
    if ([ad isKindOfClass:NSClassFromString(@"AppDelegate")]) {
        [parts addObject:ad.shellRegistered ? @"系统Shell:已注册" : @"系统Shell:未注册"];
        // 两层窗口各自的状态：场景层负责桌面常驻，占位层负责 App 前台兜底
        NSString *sceneLayer = ad.sceneTouchLayerCreated ? @"场景层:已创建" : @"场景层:未创建";
        NSString *placeLayer = ad.placeholderTouchWindow && !ad.placeholderTouchWindow.hidden ? @"占位层:显示中" : @"占位层:已隐藏";
        [parts addObject:[NSString stringWithFormat:@"%@ / %@", sceneLayer, placeLayer]];
        if (ad.overlayHidden) [parts addObject:@"状态:已紧急隐藏(打开App恢复)"];
    }
    switch ([VolumeController shared].backend) {
        case EVVolumeBackendAVSystemController: [parts addObject:@"音量API:私有接口"]; break;
        case EVVolumeBackendMPVolumeView:       [parts addObject:@"音量API:MPVolumeView兜底"]; break;
        default:                                [parts addObject:@"音量API:检测中"]; break;
    }
    NSArray<NSString *> *log = ad.eventLog;
    if (log.count > 0) {
        [parts addObject:@"—— 事件日志 ——"];
        for (NSInteger i = log.count - 1; i >= 0 && i >= (NSInteger)log.count - 6; i--) {
            [parts addObject:log[i]];
        }
    }
    return [parts componentsJoinedByString:@"\n"];
}

@end
