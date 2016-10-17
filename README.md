>蓝牙开发是我之前在一个车联网的项目里用到的，捣鼓了半天整理了一些东西。使用环境是手机和蓝牙车载记录仪的通信，大体流程是手机作为服务端通过发送故障码给外围设备记录仪，然后记录仪广播回传数据，具体内容下面详细介绍~

iOS BLE开发调用的是CoreBluetooth系统原生库，基本用到的类有：
>CBCentralManager //系统蓝牙设备管理对象
>CBPeripheral //外围设备
>CBService //外围设备的服务或者服务中包含的服务
>CBCharacteristic //服务的特性
>CBDescriptor //特性的描述符

他们之间的关系如图:
 ![常用类别结构图](https://raw.githubusercontent.com/Jupengpeng/ImagesResourse/master/CoreBluetoothStructure.png)


###下面开始代码部分：


#####1、初始化：

```
_manager = [[CBCentralManager alloc]initWithDelegate:self queue:dispatch_get_main_queue()];
```

#####2、调用蓝牙，走协议方法：

开始扫描外围设备
```
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
            //开始扫描周围的外设
            [central scanForPeripheralsWithServices:nil options:nil];
            /*
             第一个参数nil就是扫描周围所有的外设，扫描到外设后会进入
             */
            break;
        default:
            break;
    }
}
```
管理者central有state属性，
```
CBCentralManagerStateUnknown = 0,
CBCentralManagerStateResetting,
CBCentralManagerStateUnsupported,//不支持蓝牙
CBCentralManagerStateUnauthorized,//未获取权限
CBCentralManagerStatePoweredOff,//蓝牙关
CBCentralManagerStatePoweredOn//蓝牙开
```
状态为 CBCentralManagerStatePoweredOn 开始扫描周围设备：
```
[central scanForPeripheralsWithServices:@[] options:nil];
```
第一个参数类型为CBUUID 的数组，可以通过UUID来筛选设备,
传nill扫描周围所有设备，
#####3、找到设备就会调用如下方法
```
-(void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI{
    //这里自己去设置下连接规则
    if ([peripheral.name hasPrefix:@"F"]){
    //[peripheral.name isEqualToString:@""]
      
    //找到的设备必须持有它，否则CBCentralManager中也不会保存peripheral，那么CBPeripheralDelegate中的方法也不会被调用！！
        [_discoverPeripherals addObject:peripheral];
    }
}
```
_discoverPeripherals是我自己的成员变量数组；
一个主设备最多能连7个外设，每个外设最多只能给一个主设备连接,连接成功，失败，断开会进入各自的委托

连接外设成功的委托：
         - (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral;
外设连接失败的委托：
         - (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error;
断开外设的委托：
         - (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error;
#####4、连接上后我们就停止扫描，并查找Peripheral的service
```
-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{
    _peripheral = peripheral;
    //外设寻找 services
    [peripheral discoverServices:nil];
    [peripheral setDelegate:self];
    [_manager stopScan];
}
```
#####5、扫描到service，我们走协议方法
```
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    //  NSLog(@">>>扫描到服务：%@",peripheral.services);
    if (error)
    {
        NSLog(@">>>Discovered services for %@ with error: %@", peripheral.name, [error localizedDescription]);
        return;
    }
    for (CBService *service in peripheral.services) {
//serviceId筛选
        if ([service.UUID.UUIDString isEqualToString:ServiceUUID1]) {
            [peripheral discoverCharacteristics:nil forService:service];
        }
    }
}
```
在做该类项目时，外设需求往往有一个UUID来确定需要连接的服务，对应这边service的UUID，而不是peripheral的UUID
（在使用lightblue模拟测试时，可以添加service并设置其UUID来模拟测试,如下图）

 ![lightblue service设置界面](https://github.com/Jupengpeng/ImagesResourse/blob/master/FullSizeRender.jpg?raw=true)

#####6、读取和设置characteristic
获取到service会走
```
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{
    if (error) {
        NSLog(@"error Discovered characteristics for %@ with error: %@", service.UUID, [error localizedDescription]);
        return;
    }
    for (CBCharacteristic *characteristic in service.characteristics){
        NSLog(@"service:%@ 的 Characteristic: %@",service.UUID,characteristic.UUID);
    }
    //获取Characteristic的值，读到数据会进入方法：
-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
    for (CBCharacteristic *characteristic in service.characteristics){
        [peripheral readValueForCharacteristic:characteristic];
        [self notifyCharacteristic:peripheral characteristic:characteristic];
    }
}
```
[self notifyCharacteristic:peripheral characteristic:characteristic] 是用来设置characteristic的一个notifying属性，设置为YES可以接受外围的通知
我们项目的场景是，设置notifying = Yes后，发送某些字符串，然后通过方法
```
-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error;
```
不断获取新数据。
#####7、获取到characteristic后就走方法
```
-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    //打印出characteristic的UUID和值
    //!注意，value的类型是NSData，具体开发时，会根据外设协议制定的方式去解析数据
    NSString *result = [[NSString alloc] initWithData:characteristic.value  encoding:NSASCIIStringEncoding];
    NSLog(@"characteristic uuid:%@  value:%@",[NSString stringWithFormat:@"%@",characteristic.UUID],result);
    if ([_lastString isEqualToString:result]) {
        return;
    }
  NSString *str = @"Hello world";
  NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
   [self writeCharacteristic:peripheral characteristic:characteristic value:data];
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
```
写数据会回调方法：
```
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
```
这个地方要注意，因为写入成功后仍然会调用：
```
-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error;
```
可能会导致数据无限发送，要加个发送完之后的阻塞。

此时可以通过lightblue进行测试，测试前为了方便，先将右上角的hex改为我们常用的编码方式UTF-8，每次写入成功都会将此处的value改变，如图：
 ![characteristic value 改变](https://github.com/Jupengpeng/ImagesResourse/blob/master/IMG_0446.PNG?raw=true)

##### 我的BLE开发大概写到这，欢迎下载Demo 
