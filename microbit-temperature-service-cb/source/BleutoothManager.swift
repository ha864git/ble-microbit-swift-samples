// BleutoothManager.swift

import CoreBluetooth

class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, ObservableObject {

    @Published private(set) var connectedPeripheral: CBPeripheral?
    @Published private(set) var temperatureCharacteristic : CBCharacteristic?
    @Published private(set) var temperaturePeriodCharacteristic : CBCharacteristic?
    @Published private(set) var temperatureValue: Int?
    @Published private(set) var temperaturePeriod: Int?
    @Published private(set) var periodBlink = false
    @Published private(set) var isScanning = false

    let TEMPERATURE_CHARACTERISTIC = CBUUID(string: "E95D9250-251D-470A-A062-FA1922DFA9A8")
    let TEMPERATURE_PERIOD_CHARACTERISTIC = CBUUID(string: "E95D1B25-251D-470A-A062-FA1922DFA9A8")
    let MICROBIT_PREFIX = "BBC micro:bit"

    private var centralManager: CBCentralManager!

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            //centralManager.scanForPeripherals(withServices: nil, options: nil)
        }
    }

    func startScan() {
        if centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let name = peripheral.name {
            if name.hasPrefix(MICROBIT_PREFIX) {
                self.centralManager.stopScan()
                self.isScanning = false
                self.connectedPeripheral = peripheral
                self.centralManager.connect(peripheral, options: nil)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if let name = peripheral.name {
            print("Connected: \(name)")
        }
        self.connectedPeripheral?.discoverServices(nil)
        self.connectedPeripheral?.delegate = self
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }  
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for charac in service.characteristics! {  
            if charac.uuid == TEMPERATURE_CHARACTERISTIC {
                self.temperatureCharacteristic = charac
                print("Discovered a characteristic UUID: \(TEMPERATURE_CHARACTERISTIC)")
                self.connectedPeripheral?.setNotifyValue(true, for: charac)
                self.connectedPeripheral?.readValue(for: charac)
            }
            if charac.uuid == TEMPERATURE_PERIOD_CHARACTERISTIC {
                self.temperaturePeriodCharacteristic = charac
                print("Discovered a characteristic UUID: \(TEMPERATURE_PERIOD_CHARACTERISTIC)")
                self.connectedPeripheral?.readValue(for: charac)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print(error)
            return
        }
        guard let data = characteristic.value else {
            return
        }   
        if characteristic.uuid == TEMPERATURE_CHARACTERISTIC {
            let value = Int(Int8(data[0]))
            print("micro:bit Temperature: \(String(describing: value))")
            self.temperatureValue = value
            self.periodBlink.toggle()
        }
        if characteristic.uuid == TEMPERATURE_PERIOD_CHARACTERISTIC {
            let bytes = [UInt8](data)
            let value = Int(bytes[1]) * 256 + Int(bytes[0])  
            print("micro:bit Temperature Period: \(String(describing: value))mSec")
            self.temperaturePeriod = value
        }
    }

    func writeTemperaturePeriod(period: Int) {
        let value16 = UInt16(period)
        let values = [UInt8(value16 & 0xff), UInt8((value16 >> 8) & 0xff)]
        let data = Data(values)
        if let charac = self.temperaturePeriodCharacteristic {
            self.connectedPeripheral?.writeValue(data, for: charac, type: .withResponse)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print(error)
            return
        }
        if characteristic.uuid == TEMPERATURE_PERIOD_CHARACTERISTIC {
            if let charac = self.temperaturePeriodCharacteristic {
                self.connectedPeripheral?.readValue(for: charac)
            }
        }
    }

    func connect() {
        if centralManager.state == .poweredOn {
            self.connectedPeripheral = nil
            self.temperatureValue = nil
            self.temperaturePeriod = nil
            startScan()
            self.isScanning = true
        }
    }

    func disconnect() {
        if let peripheral = self.connectedPeripheral {
            self.connectedPeripheral = nil
            self.temperatureValue = nil
            self.temperaturePeriod = nil
            self.centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    func cancel() {
        disconnect()
        self.centralManager.stopScan()
        self.isScanning = false
    }

}