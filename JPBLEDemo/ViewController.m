//
//  ViewController.m
//  JPBLEDemo
//
//  Created by yintao on 16/9/28.
//  Copyright © 2016年 yintao. All rights reserved.
//



#import "ViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "InputValueController.h"
static NSString *const ServiceUUID1 =  @"19B10010-E8F2-537E-4F6C-D104768A1214";


@interface ViewController ()<CBCentralManagerDelegate,CBPeripheralDelegate,UITableViewDelegate,UITableViewDataSource>
{
    //系统蓝牙设备管理对象
    CBCentralManager *_manager;
    
    //用于保存被发现设备
    NSMutableArray *_discoverPeripherals;
    //连接上的外部设备
    CBPeripheral *_peripheral ;
    //设备服务特性
    CBCharacteristic *_characteristic;
    
    
    /**
     *  需要初始化
     */
    BOOL _SurpriseSended;
    NSString *_sendString;
    NSString *_lastString;
}

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (nonatomic,strong) InputValueController *inputController;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.tableFooterView = [[UIView alloc]init];
    
    _discoverPeripherals = [NSMutableArray array];
    //初始化蓝牙管理对象
    _manager = [[CBCentralManager alloc]initWithDelegate:self queue:dispatch_get_main_queue()];

    
    UIButton *leftButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 60, 20)];
    [leftButton setTitle:@"开始扫描" forState:UIControlStateNormal];
    leftButton.titleLabel.font = [UIFont systemFontOfSize:14.0f];
    [leftButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [leftButton addTarget:self action:@selector(startScan) forControlEvents:UIControlEventTouchUpInside];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:leftButton];
}

- (void)startScan{
    _SurpriseSended = NO;
    //开始扫描周围的外设
    [_manager scanForPeripheralsWithServices:nil options:nil];
    
}


#pragma mark - <UITableViewDelegate,UITableViewDataSource>


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return _discoverPeripherals.count;

}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    static NSString *const cellID = @"cellId";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID];
    }
    CBPeripheral *peripheral = _discoverPeripherals [indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"设备名称 ：%@",peripheral.name];
    
    
    return cell;
}

//点击进行设备连接
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    CBPeripheral *peripheral = _discoverPeripherals [indexPath.row];
    _peripheral = peripheral;
    [_manager connectPeripheral:_peripheral options:nil];
    

}

#pragma mark - <CBCentralManagerDelegate,CBPeripheralDelegate>

-(void)centralManagerDidUpdateState:(CBCentralManager *)central{

    switch (central.state) {
        case CBCentralManagerStateUnknown:
            NSLog(@">>>CBCentralManagerStateUnknown");
            break;
        case CBCentralManagerStateResetting:
            NSLog(@">>>CBCentralManagerStateResetting");
            break;
        case CBCentralManagerStateUnsupported:
            NSLog(@">>>CBCentralManagerStateUnsupported");
            break;
        case CBCentralManagerStateUnauthorized:
            NSLog(@">>>CBCentralManagerStateUnauthorized");
            break;
        case CBCentralManagerStatePoweredOff:
            NSLog(@">>>CBCentralManagerStatePoweredOff");
            break;
        case CBCentralManagerStatePoweredOn:
            NSLog(@">>>CBCentralManagerStatePoweredOn");

            /*
             第一个参数nil就是扫描周围所有的外设，扫描到外设后会进入
             */
            break;
        default:
            break;
    }
}

//扫描到设备会进入方法
-(void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI{
    //接下连接我们的测试设备，如果你没有设备，可以下载一个app叫lightbule的app去模拟一个设备
    /*
     一个主设备最多能连7个外设，每个外设最多只能给一个主设备连接,连接成功，失败，断开会进入各自的委托
     - (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral;//连接外设成功的委托
     - (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error;//外设连接失败的委托
     - (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error;//断开外设的委托
     */
    //找到的设备必须持有它，否则CBCentralManager中也不会保存peripheral，那么CBPeripheralDelegate中的方法也不会被调用！！
   
    //将扫描到的 CBPeripheral外围设备 放到collection
    BOOL isExisted = NO;
    for (CBPeripheral *myPeropheral in _discoverPeripherals) {
        if (myPeropheral.identifier == peripheral.identifier) {
            isExisted = YES;
        }
    }
    
    
    if (!isExisted) {
        [_discoverPeripherals addObject:peripheral];
        NSLog(@"%@",_discoverPeripherals);
    }
    [self.tableView reloadData];

    }

//连接到Peripherals-失败
-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@">>>连接到名称为（%@）的设备-失败,原因:%@",[peripheral name],[error localizedDescription]);
}

//Peripherals断开连接
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    NSLog(@">>>外设连接断开连接 %@: %@\n", [peripheral name], [error localizedDescription]);
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"蓝牙设备%@已经断开",[peripheral name]] message:@"请重新扫描" delegate:self cancelButtonTitle:@"好的" otherButtonTitles: nil];
    [alertView show];
    
}

//连接到Peripherals-成功
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    _peripheral = peripheral;
    //外设寻找 services
    [peripheral discoverServices:nil];
    
    [peripheral setDelegate:self];
    self.title = peripheral.name ;
    [_manager stopScan];
    
    
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"已经连接上 %@",peripheral.name] message:nil preferredStyle:UIAlertControllerStyleAlert];
    
    [self presentViewController:alertController animated:YES completion:^{
        [alertController dismissViewControllerAnimated:NO completion:^{
            //连接上跳转
            [self presentViewController:self.inputController animated:YES completion:nil];
            self.inputController.imputValueBlock = ^(NSString *sendStr){
                _sendString = sendStr;
                NSString *str = _sendString;
                NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
                [self writeCharacteristic:peripheral characteristic:_characteristic value:data];
            };
        }];

    }];

}

//扫描到Services
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    //  NSLog(@">>>扫描到服务：%@",peripheral.services);
    if (error)
    {
        NSLog(@">>>Discovered services for %@ with error: %@", peripheral.name, [error localizedDescription]);
        return;
    }
    for (CBService *service in peripheral.services) {
        //serviceId筛选
        NSLog(@"----------");
        NSLog( service.UUID.UUIDString);
        if ([service.UUID.UUIDString isEqualToString:ServiceUUID1]) {
            [peripheral discoverCharacteristics:nil forService:service];

        }
    }
}

//扫描到Characteristics
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{
    if (error)
    {
        NSLog(@"error Discovered characteristics for %@ with error: %@", service.UUID, [error localizedDescription]);
        return;
    }
    
//    for (CBCharacteristic *characteristic in service.characteristics)
//    {
//        NSLog(@"service:%@ 的 Characteristic: %@",service.UUID,characteristic.UUID);
//    }
    
    //获取Characteristic的值，读到数据会进入方法：-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error

//    for (CBCharacteristic *characteristic in service.characteristics){
//        [peripheral readValueForCharacteristic:characteristic];
//        [self notifyCharacteristic:peripheral characteristic:characteristic];
//
//    }
    
    for (CBCharacteristic *characteristic in service.characteristics){
        //19B10011-E8F2-537E-4F6C-D104768A1214   read write
       //19B10012-E8F2-537E-4F6C-D104768A1214      notify
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"19B10011-E8F2-537E-4F6C-D104768A1214"]]){
            NSLog(@"找到可读特征readPowerCharacteristic : %@",characteristic);
            [peripheral readValueForCharacteristic:characteristic];
            //[peripheral setNotifyValue:YES forCharacteristic:characteristic];
            [self notifyCharacteristic:peripheral characteristic:characteristic];
    
        }else if([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"19B10012-E8F2-537E-4F6C-D104768A1214"]]){
            [self notifyCharacteristic:peripheral characteristic:characteristic];
            //[peripheral setNotifyValue:YES forCharacteristic:characteristic];
            //[peripheral readValueForCharacteristic:characteristic];
            NSLog(@" setNotifyValue : %@",characteristic);
        }
    }

}

//获取的charateristic的值
-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    

//    if (characteristic.value) {
//        NSString *value = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
//        NSLog(@"读取到特征值：%@",value);
//    }else{
//        NSLog(@"未发现特征值.");
//    }

    
    NSString *result = [[NSString alloc] initWithData:characteristic.value  encoding:NSASCIIStringEncoding];
    NSLog(@"result+characteristic uuid:%@  value:%@",[NSString stringWithFormat:@"%@",characteristic.UUID],result);
    if ([_lastString isEqualToString:result]) {
        return;
    }
//    NSString *str = @"Surprise";
//    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
//    [self writeCharacteristic:peripheral characteristic:characteristic value:data];
    _characteristic = characteristic;

 
    
}


//搜索到Characteristic的Descriptors
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    
    //打印出Characteristic和他的Descriptors
    for (CBDescriptor *descriptor in characteristic.descriptors) {
        
    }
    
}
//获取到Descriptors的值
-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error{
    NSString *result = [[NSString alloc] initWithData:descriptor.value  encoding:NSASCIIStringEncoding];
    //打印出DescriptorsUUID 和value
    //这个descriptor都是对于characteristic的描述，一般都是字符串，所以这里我们转换成字符串去解析
    NSLog(@"descriptor uuid:%@  value:%@",[NSString stringWithFormat:@"%@",descriptor.UUID],result);
}

//写数据
-(void)writeCharacteristic:(CBPeripheral *)peripheral
            characteristic:(CBCharacteristic *)characteristic
                     value:(NSData *)value{
    
    NSLog(@"%lu", (unsigned long)characteristic.properties);
    
    
    //只有 characteristic.properties 有write的权限才可以写
    if(characteristic.properties & CBCharacteristicPropertyWrite){
        /*
         最好一个type参数可以为CBCharacteristicWriteWithResponse或type:CBCharacteristicWriteWithResponse,区别是是否会有反馈
         */
        [peripheral writeValue:value forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
    }else{
        NSLog(@"该字段不可写！");
    }
}
#pragma mark 写数据后回调
- (void)peripheral:(CBPeripheral *)peripheral
didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error {
    if (error) {
        NSLog(@"Error writing characteristic value: %@",
              [error localizedDescription]);
        return;
    }
    
    NSLog(@"写入%@成功",characteristic);
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"写入成功" message:[NSString stringWithFormat:@"写入%@成功",characteristic] delegate:self cancelButtonTitle:@"好的" otherButtonTitles: nil];
    [alertView show];

    _lastString = [[NSString alloc] initWithData:characteristic.value  encoding:NSASCIIStringEncoding];
}

//将传入的NSData类型转换成NSString并返回

- (NSString*)hexadecimalString:(NSData *)data{
    
    NSString* result;
    
    const unsigned char* dataBuffer = (const unsigned char*)[data bytes];
    
    if(!dataBuffer){
        
        return nil;
        
    }
    
    NSUInteger dataLength = [data length];
    
    NSMutableString* hexString = [NSMutableString stringWithCapacity:(dataLength * 2)];
    
    for(int i = 0; i < dataLength; i++){
        
        [hexString appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)dataBuffer[i]]];
        
    }
    
    result = [NSString stringWithString:hexString];
    
    return result;
    
}



//设置通知
-(void)notifyCharacteristic:(CBPeripheral *)peripheral
             characteristic:(CBCharacteristic *)characteristic{
    //设置通知，数据通知会进入：didUpdateValueForCharacteristic方法
    [peripheral setNotifyValue:YES forCharacteristic:characteristic];
}

//取消通知
-(void)cancelNotifyCharacteristic:(CBPeripheral *)peripheral
                   characteristic:(CBCharacteristic *)characteristic{
    
    [peripheral setNotifyValue:NO forCharacteristic:characteristic];
}

//停止扫描并断开连接
-(void)disconnectPeripheral:(CBCentralManager *)centralManager
                 peripheral:(CBPeripheral *)peripheral{
    //停止扫描
    [centralManager stopScan];
    //断开连接
    [centralManager cancelPeripheralConnection:peripheral];
}

#pragma mark - init 

- (InputValueController *)inputController{
    if (!_inputController) {
        _inputController = [[InputValueController alloc] init];
    }
    return _inputController;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
