import Combine
import Foundation
import AsyncBluetooth
import CoreBluetooth

let TEMPERATURESERVICE_SERVICE_UUID = "E95D6100-251D-470A-A062-FA1922DFA9A8"
let TEMPERATURE_CHARACTERISTIC_UUID = "E95D9250-251D-470A-A062-FA1922DFA9A8"
let TEMPERATURE_PERIOD_CHARACTERISTIC_UUID = "E95D1B25-251D-470A-A062-FA1922DFA9A8"
let strPrefix = "BBC micro:bit"
let temperatureServiceUUID = UUID(uuidString: TEMPERATURESERVICE_SERVICE_UUID)
let temperatureCharacteristicUUID = UUID(uuidString: TEMPERATURE_CHARACTERISTIC_UUID)
let temperatureCharacteristicPeriodUUID = UUID(uuidString: TEMPERATURE_PERIOD_CHARACTERISTIC_UUID)
let temperatureServiceCBUUID = CBUUID(string: TEMPERATURESERVICE_SERVICE_UUID)
let temperatureCharacteristicCBUUID = CBUUID(string: TEMPERATURE_CHARACTERISTIC_UUID)
let temperatureCharacteristicPeriodCBUUID = CBUUID(string: TEMPERATURE_PERIOD_CHARACTERISTIC_UUID)

@MainActor
class ViewModel: ObservableObject {

    private let centralManager = CentralManager()
    
    @Published private(set) var temperatureValue: Int?
    @Published private(set) var temperaturePeriod: Int?
    @Published private(set) var periodBlink = false
    @Published private(set) var isScanning = false
    @Published private(set) var peripheral: Peripheral?
    @Published private(set) var error: String?
    private var cancellables: [AnyCancellable] = []
    
    func connect() {
        self.temperatureValue = nil
        self.temperaturePeriod = nil
        self.periodBlink = false
        self.error = nil
        self.peripheral = nil
        self.isScanning = true

        Task { @MainActor [centralManager] in
            do { 
                try await centralManager.waitUntilReady()
                let scanDataStream = try await centralManager.scanForPeripherals(withServices: nil) 
                for await scanData in scanDataStream {
                    let pname = scanData.peripheral.name ?? "Unknown"
                    if pname.hasPrefix(strPrefix) {
                        do {
                            try await centralManager.connect(scanData.peripheral, options: nil)
                            self.peripheral = scanData.peripheral
                            print("Connected: \(pname)")

                            try await self.peripheral?.discoverServices([temperatureServiceCBUUID])
                            guard let service = scanData.peripheral.discoveredServices?.first else {
                                throw PeripheralError.serviceNotFound
                            }
                            print("Discovered a service UUID: \(temperatureServiceCBUUID)")
                            
                            try await peripheral!.discoverCharacteristics([temperatureCharacteristicCBUUID], for: service)
                            guard (service.discoveredCharacteristics?.first) != nil else {
                                throw PeripheralError.characteristicNotFound
                            }
                            print("Discovered a characteristic \(temperatureCharacteristicCBUUID)")

                            try await peripheral!.discoverCharacteristics([temperatureCharacteristicPeriodCBUUID], for: service)
                            guard (service.discoveredCharacteristics?.first) != nil else {
                                throw PeripheralError.characteristicNotFound
                            }
                            print("Discovered a characteristic \(temperatureCharacteristicPeriodCBUUID)")
                
                            self.temperaturePeriod = try await peripheral!.readValue(
                                forCharacteristicWithUUID: temperatureCharacteristicPeriodUUID!,
                                ofServiceWithUUID: temperatureServiceUUID!
                            )
                            if let value = self.temperaturePeriod {
                                print("micro:bit Temperature Period: \(String(describing: value))mSec")
                            }

                            await self.peripheral!.characteristicValueUpdatedPublisher
                                .filter { $0.uuid == temperatureCharacteristicCBUUID }
                                .map { try? $0.parsedValue() as Int? }
                                .sink { value in
                                    if let newValue = value {
                                        print("micro:bit Temperature: \(String(describing: newValue))")
                                        self.temperatureValue = newValue
                                        self.periodBlink.toggle()
                                    }
                                }
                                .store(in: &cancellables)
                            try await self.peripheral!.setNotifyValue(
                                true,
                                forCharacteristicWithCBUUID: temperatureCharacteristicCBUUID,
                                ofServiceWithCBUUID: temperatureServiceCBUUID
                            )
                            print("Set notify value UUID: \(temperatureCharacteristicCBUUID)")
                            
                            print("Ready!")
                            break
                        } catch {
                            print(error)
                            self.peripheral = nil
                            try await centralManager.cancelPeripheralConnection(scanData.peripheral)
                        }
                    }
                }
            } catch {
                self.error = error.localizedDescription
                print(error)
            }
            await centralManager.stopScan()
            self.isScanning = false
        }
    }
    
    func writeTemperaturePeriod(period: Int) {
        let value16 = UInt16(period)
        let values = [UInt8(value16 & 0xff), UInt8((value16 >> 8) & 0xff)]
        let data = Data(values)
        Task {
            do {
                try await self.peripheral!.writeValue(
                    data,
                    forCharacteristicWithUUID: temperatureCharacteristicPeriodUUID!,
                    ofServiceWithUUID: temperatureServiceUUID!
                )           
                self.temperaturePeriod = try await peripheral!.readValue(
                    forCharacteristicWithUUID: temperatureCharacteristicPeriodUUID!,
                    ofServiceWithUUID: temperatureServiceUUID!
                )
                if let value = self.temperaturePeriod {
                    print("micro:bit Temperature Period: \(String(describing: value))mSec")
                }
            } catch {
                print(error)
            }
        }
    }

    func readTemperaturePeriod() {
        Task {
            do {
                self.temperaturePeriod = try await peripheral!.readValue(
                    forCharacteristicWithUUID: temperatureCharacteristicPeriodUUID!,
                    ofServiceWithUUID: temperatureServiceUUID!
                )
                if let value = self.temperaturePeriod {
                    print("micro:bit Temperature Period: \(String(describing: value))mSec")
                }
            } catch {
                print(error)
            }
        }
    }

    func stopScan() {
        Task {
            if await self.centralManager.isScanning {
                await self.centralManager.stopScan()
            }
            
            DispatchQueue.main.async {
                self.isScanning = false
            }
        }
    }
    
    func cancel() {
        Task {
            if let peripheral = self.peripheral {
                self.peripheral = nil
                self.temperaturePeriod = nil
                try await centralManager.cancelPeripheralConnection(peripheral)
                try await centralManager.cancelAllOperations()
                try await peripheral.cancelAllOperations()
            }
            await centralManager.stopScan()
            self.isScanning = false
        }
    }

    func disconnect() {
        Task {
            do {
                if let peripheral = self.peripheral {
                    self.peripheral = nil
                    self.temperaturePeriod = nil
                    try await centralManager.cancelPeripheralConnection(peripheral)
                }
            } catch {
                print(error)
            }
        }
    }

}

enum PeripheralError: Error {
    case serviceNotFound
    case characteristicNotFound
}
