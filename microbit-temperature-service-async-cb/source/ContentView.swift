import SwiftUI

struct ContentView: View {

    @StateObject var viewModel = ViewModel()

    var body: some View {

        VStack(spacing: 40) {
            Text("micro:bit Temperature").font(.largeTitle).fontWeight(.black)

            if viewModel.isScanning {
                Button("Cancel") {
                    viewModel.cancel()
                }.font(.system(size: 20, weight: .black, design: .default))
                Text(" ").font(.title)
                Text(" ").font(.title)
            } else {
                if let name = viewModel.peripheral?.name {
                    Button("Disconnect") {
                        viewModel.disconnect()
                    }.font(.system(size: 20, weight: .black, design: .default))
                    Text(name).font(.title)
                    if let value = viewModel.temperatureValue {
                        Text("\(String(value))℃").font(.title)
                    } else {
                        Text(" ").font(.title)
                    }
                } else {
                    Button("Connect") {
                        viewModel.connect()
                    }.font(.system(size: 20, weight: .black, design: .default))
                    Text(" ").font(.title)
                    Text(" ").font(.title)
                }
            }    
            
            List {
                viewModel.periodBlink ? Text("Temperature Period +") : Text("Temperature Period")
                ForEach(0..<5, id: \.self) { index in
                    let valuePeriod = (index + 1) * 1000
                    HStack {
                        Text("\(valuePeriod)msec")
                        Spacer()
                    }
                    .listRowBackground(viewModel.temperaturePeriod == valuePeriod ? Color(red: 0.3, green: 0.5, blue: 0.2,opacity:0.1) : Color.white)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.writeTemperaturePeriod(period: valuePeriod)
                    }
                }
            }
            .frame(width: 250, height: 325)
            .opacity(viewModel.temperaturePeriod == nil ? 0 : 1)
        }
    }
}