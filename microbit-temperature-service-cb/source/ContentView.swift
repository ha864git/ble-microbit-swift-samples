// ContentView.swift

import SwiftUI

struct ContentView: View {

    @StateObject var bluetoothManager = BluetoothManager()

    var body: some View {
        VStack(spacing: 20) {
            Text("micro:bit Temperature").font(.largeTitle).fontWeight(.black)
            if bluetoothManager.isScanning {
                Button("Cancel") {
                    bluetoothManager.cancel()
                }.font(.title).fontWeight(.black).foregroundColor(.blue)
                Text(" ").font(.title)
                Text(" ").font(.title)
            } else {
                if let name = bluetoothManager.connectedPeripheral?.name {
                    Button("Disconnect") {
                        bluetoothManager.disconnect()
                    }.font(.title).fontWeight(.black).foregroundColor(.blue)
                    Text(name).font(.title)
                    if let value = bluetoothManager.temperatureValue {
                        Text("\(String(value))℃").font(.title)
                    } else {
                        Text(" ").font(.title)
                    }
                } else {
                    Button("Connect") {
                        bluetoothManager.connect()
                    }.font(.title).fontWeight(.black).foregroundColor(.blue)
                    Text(" ").font(.title)
                    Text(" ").font(.title)
                }
            }

            List {
                bluetoothManager.periodBlink ? Text("Temperature Period +") : Text("Temperature Period")
                ForEach(0..<5, id: \.self) { index in
                    let valuePeriod = (index + 1) * 1000
                    HStack {
                        Text("\(valuePeriod)msec")
                        Spacer()
                    }
                    .listRowBackground(bluetoothManager.temperaturePeriod == valuePeriod ? Color(red: 0.3, green: 0.5, blue: 0.2,opacity:0.1) : Color.white)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        bluetoothManager.writeTemperaturePeriod(period: valuePeriod)
                    }
                }
            }
            .frame(width: 250, height: 325)
            .opacity(bluetoothManager.temperaturePeriod == nil ? 0 : 1)

        }
    }
}