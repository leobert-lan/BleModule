import CoreBluetooth
import RxCBCentral
import RxSwift

public struct BleRxLayerModule {
    public let bluetoothDetector: BluetoothDetectorType
    public let peripheralManager: RxPeripheralManagerType
    public let connectionManager: ConnectionManager
    
    public init() {
        bluetoothDetector = BluetoothDetector(options: BluetoothDetectorOptions(showPowerAlert: false))
        peripheralManager = RxPeripheralManager()
        connectionManager = ConnectionManager(peripheralGattManager: peripheralManager)
    }
    
    /// 搜索Ble蓝牙设备
    func scanTarget(uuids: [CBUUID]? = nil, matcher: ScanMatching? = nil, options: ScanOptions? = nil,
                    scanTimeout: RxTimeInterval = ScanDefaults.defaultScanTimeout) -> Observable<ScanData>
    {
        return connectionManager.scan(for: uuids, scanMatcher: matcher, options: options, scanTimeout: scanTimeout)
    }
    
    /// 连接指定蓝牙设备
    func connect(uuids: [CBUUID]? = nil,
                 scanMatcher: ScanMatching? = nil,
                 options: ScanOptions? = nil,
                 scanTimeout: RxTimeInterval = ScanDefaults.defaultScanTimeout,
                 onSuccess: ((BleRxLayerModule) -> Void?)? = nil) -> Disposable
    {
        return connectionManager
            .connectToPeripheral(with: uuids, scanMatcher: scanMatcher, options: options, scanTimeout: scanTimeout)
            .subscribe { (peripheral: RxPeripheral) in
                // IMPORTANT: inject the RxPeripheral into the manager after connecting
                self.peripheralManager.rxPeripheral = peripheral
                onSuccess?(self)
            }
    }
    
    /// 监听连接状态
    func listenConnectedState(
        onNext: @escaping ((Bool) -> Void),
        onError: ((Swift.Error) -> Void)? = nil,
        onCompleted: (() -> Void)? = nil,
        onDisposed: (() -> Void)? = nil
    ) -> Disposable {
        return peripheralManager.isConnected
            .subscribe(onNext: onNext, onError: onError, onCompleted: onCompleted, onDisposed: onDisposed)
    }
    
    private func listeneNotify(svcUuid: CBUUID, characteristic: CBUUID, receiver: BehaviorSubject<ByteArray>) -> Disposable {
        return peripheralManager
            .isConnected
            .filter { $0 } // wait until we're connected before performing BLE operations
            .flatMapLatest { _ -> Single<Void> in
                // register to listen to peripheral notifications
                let operation = RegisterNotification(service: svcUuid, characteristic: characteristic)
                return self.peripheralManager.queue(operation: operation)
            }
            .flatMapLatest { _ -> Observable<Data> in
                // listen for Heart Rate Measurement events
                self.peripheralManager.receiveNotifications(for: characteristic)
            }
            .subscribe(onNext: { data in
                // do something with Heart Rate Measurement data
                let array = [UInt8](data)
                receiver.onNext(array)
            })
    }
    
    func send(sdu: any ISDU, service: CBUUID, characteristic: CBUUID) -> Single<Write.Element> {
        return peripheralManager.queue(operation: Write(service: service, characteristic: characteristic, data: Data(sdu.content)))
    }
    
    /// 注册 notify、indicate 类型特征码监听
    /// [analyzer] 处理粘包、分包->拼包 的分析器
    func registerNotifyReceiver(
        svcUuid: CBUUID, characteristic: CBUUID,
        analyzer: ISduAnalyzer,
        receiver: BehaviorSubject<any ISDU>
    ) -> Disposable {
        let byteArrayReceiver = BehaviorSubject<ByteArray>.init(value: [])
        let disposable = listeneNotify(svcUuid: svcUuid, characteristic: characteristic, receiver: byteArrayReceiver)
        
        return byteArrayReceiver
            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .userInitiated))
            .observeOn(ConcurrentDispatchQueueScheduler(qos: .userInitiated))
            .subscribe(onNext: { ByteArray in
                let sdus = analyzer.analyze(data: ByteArray)
                sdus.forEach { e in
                    receiver.onNext(e)
                }
            }, onError: { _ in
                // ignore
            }, onDisposed: {
                disposable.dispose()
            })
    }
}

public class DeviceNameScanMatcher: ScanMatching {
    public var match: Observable<ScanData> {
        return scanDataSequence
            .filter { (peripheral: CBPeripheralType, _, _) -> Bool in
                guard let peripheral = peripheral as? CBPeripheral,
                      let name = peripheral.name?.lowercased() else { return false }
                
                return name.contains(self.deviceName.lowercased())
            }
    }
    
    init(deviceName: String) {
        self.deviceName = deviceName
    }
    
    public func accept(_ scanData: ScanData) {
        scanDataSequence.onNext(scanData)
    }
    
    private let deviceName: String
    private let scanDataSequence = ReplaySubject<ScanData>.create(bufferSize: 1)
}

public extension Data {
    func hexEncodedString() -> String {
        return "0x" + map { String(format: "%02hhx", $0) }.joined()
    }
}
