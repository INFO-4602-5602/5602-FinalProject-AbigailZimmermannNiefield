//
//  ClassificationViewController.swift
//  LPC Wearable Toolkit
//
//  Created by Abigail Zimmermann-Niefield on 7/24/18.
//  Copyright © 2018 Varun Narayanswamy LPC. All rights reserved.
//

import UIKit
import Charts
import CoreBluetooth
import AVFoundation

class ClassificationViewController: UIViewController, ChartViewDelegate {
    
    @IBOutlet weak var lineChart: LineChartView!
    @IBOutlet weak var classificationLabel: UILabel!
    @IBOutlet weak var barChart: BarChartView!
    
    var accelerationStore = Accelerations()
    var segmentStore = Segments()
    var segmentList:[Segment]!
    var isCapturing = false
    var classifications:[String]!
    
    var newAccelerations: [(Double,Double,Double)] = []
    var xAccelerations: [ChartDataEntry]!
    var yAccelerations: [ChartDataEntry]!
    var zAccelerations: [ChartDataEntry]!
    var isRecording = false
    var chunkSize = 0
    var model:Model?
    let dtw = DTW()
    var previousClassification: String = "None"
    var colorDictionary:[String: UIColor] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Test \(model?.name ?? "")"
        self.lineChart.delegate = self
        self.segmentList = segmentStore.fetch(model: model!, trainingSet: true)
        //labels = model?.labels
        for segment in segmentList {
            let video = segment.video
            let min_ts = video?.min_ts
            let adjustedStart = segment.start_ts/BluetoothStore.shared.ACCELEROMETER_PERIOD + min_ts!
            let adjustedStop = segment.stop_ts/BluetoothStore.shared.ACCELEROMETER_PERIOD + min_ts!
            let accelerations = self.accelerationStore.fetch(model: model!, start_ts: adjustedStart, stop_ts: adjustedStop)
            let accelerationAsDoubles = accelerations.map({acc in return (acc.xAcceleration, acc.yAcceleration, acc.zAcceleration)})
            dtw.addToTrainingSet(label: segment.rating!, data: accelerationAsDoubles)
        }
        chunkSize = Int(self.getMaxSegmentLength())
        NotificationCenter.default.addObserver(self, selector: #selector(onDidUpdateValueFor(_:)), name: BluetoothNotification.didUpdateValueFor.notification, object: nil)
        classifications = model?.labels
        // setting up color dictionary for label groupings
        let individualLabels = Array(Set(classifications))
        for l in 0..<individualLabels.count {
            colorDictionary[individualLabels[l]] = ChartColorTemplates.joyful()[l]
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func toggleDataCapture(_ sender: UIButton) {
        isCapturing = !isCapturing
        if (isCapturing) {
            if !BluetoothStore.shared.isMicrobitConnected() {
                let alert = UIAlertController(title: "Bluetooth disconnected", message: "AlpacaML detects that your sensor is no longer connected. Please quit the app to reconnect.", preferredStyle: .alert)
            
                alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            } else {
                sender.setTitle("Stop", for: .normal)
                sender.backgroundColor = UIColor(red: 255/255.0, green: 123/255.0, blue: 51/255.0, alpha: 1.0)
            }
        } else {
            sender.setTitle("Go", for: .normal)
            sender.backgroundColor = UIColor(red: 69/255.0, green: 255/255.0, blue: 190/255.0, alpha: 1.0)
            // do all in loops
            for acc in newAccelerations {
                //self.accelerationStore.save(x: acc.0,y: acc.1,z: acc.2, model: model ?? Model(), timestamp: NSDate().timeIntervalSinceReferenceDate, mode: "Testing")
            }
            newAccelerations = []
        }
    }
    
    // skip max length until next identification, add threshold?
    func classifyChunk() {
        DispatchQueue.global(qos: .userInitiated).async {
            let maxIndex = self.newAccelerations.count - 1
            let test = self.newAccelerations[(maxIndex-self.chunkSize)..<maxIndex]
            
            let classificationArray = self.dtw.classify(test: Array(test))
            let classification = classificationArray.min(by: {$0.1 < $1.1})!.0
            
            DispatchQueue.main.async {
                let classified = classification.split(separator: "|")[0].lowercased()
                let labels = classificationArray.map { $0.0 }
                let values = classificationArray.map { round($0.1)/100.00 }
                if (classified == self.previousClassification) || classified.starts(with: "none") {
                    self.classificationLabel.text = ""
                    self.previousClassification = classified
                } else {
                    self.classificationLabel.text = classification // yes I think we do want to show the full string. right? for now
                    self.setBarChart(dataPoints: labels, values: values)
                    // speak the classification
                    let utterance = AVSpeechUtterance(string: classified)
                    let synthesizer = AVSpeechSynthesizer()
                    synthesizer.speak(utterance)
                    // send a message via WebRTC
                    self.sendWebRTCData(dataToSend: String(classification.split(separator: "|")[0]))
                    self.previousClassification = classified
                }
            }
        }
    }
    
    func sendWebRTCData(dataToSend: String) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.webRTCClient.sendData(dataToSend.data(using: .utf8)!)
    }
    
    @IBAction func sendAMessageDidTap(_ sender: UIButton) {
        let alert = UIAlertController(title: "Send a message to your Scratch project",
                                      message: "This mimics the messages your gestures will send.",
                                      preferredStyle: .alert)
        alert.addTextField { (textField) in
            textField.placeholder = "Message to send"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Send", style: .default, handler: { [weak self, unowned alert] _ in
            guard let msg = alert.textFields?.first?.text else {
                return
            }
            self!.sendWebRTCData(dataToSend: msg)
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    // MARK - Chart functions
    
    private func updateLineChart() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.xAccelerations = [ChartDataEntry]()
            self.yAccelerations = [ChartDataEntry]()
            self.zAccelerations = [ChartDataEntry]()
            
            for i in 0..<self.newAccelerations.count {
                self.xAccelerations.append(ChartDataEntry(x: Double(i), y: self.newAccelerations[i].0))
                self.yAccelerations.append(ChartDataEntry(x: Double(i), y: self.newAccelerations[i].1))
                self.zAccelerations.append(ChartDataEntry(x: Double(i), y: self.newAccelerations[i].2))
            }
            
            let xline = LineChartDataSet(values: self.xAccelerations, label: "X Values")
            xline.drawCirclesEnabled = false
            xline.colors = [NSUIColor.black]
            xline.drawValuesEnabled = false
            
            let yline = LineChartDataSet(values: self.yAccelerations, label: "Y Values")
            yline.drawValuesEnabled = false
            yline.drawCirclesEnabled = false
            yline.colors = [NSUIColor.blue]
            
            let zline = LineChartDataSet(values: self.zAccelerations, label: "Z Values")
            zline.drawValuesEnabled = false
            zline.drawCirclesEnabled = false
            zline.colors = [NSUIColor.cyan]
            
            let data = LineChartData()
            data.addDataSet(xline)
            data.addDataSet(yline)
            data.addDataSet(zline)
            DispatchQueue.main.async {
                self.lineChart.data = data
                self.lineChart.setVisibleXRangeMaximum(50)
                self.lineChart.chartDescription?.text = "Acceleration"
                
                self.lineChart.data?.notifyDataChanged()
                self.lineChart.notifyDataSetChanged()
                
                self.lineChart.moveViewToX(Double(self.newAccelerations.count - 25))
            }
        }
    }
    
    @objc func onDidUpdateValueFor(_ notification: Notification) {
        if isCapturing {
            if let userInfo = notification.userInfo {
                if let accelerations = userInfo["acceleration"] as? [(Double, Double, Double)] {
                    newAccelerations.append(contentsOf: accelerations)
                    // TODO: what do we want to save from here?
                    //accelerationStore.save(x: acceleration.0, y: acceleration.1, z: acceleration.2, timestamp: NSDate().timeIntervalSinceReferenceDate, sport: sport,  id: 1)
                    updateLineChart()
                    if newAccelerations.count > chunkSize {
                        classifyChunk()
                    }
                }
            }
        }
    }
    
    // MARK - Gesture recognition code
    
    func getMaxSegmentLength() -> Double {
        let longest = segmentList.max(by: {g1, g2 in (g1.stop_ts - g1.start_ts) < (g2.stop_ts - g2.start_ts)} )
        print("Start: \(String(describing: longest?.start_ts)), Stop: \(String(describing: longest?.stop_ts))")
        return (longest?.stop_ts)! - (longest?.start_ts)!
    }
    
    // MARK - Bar Chart Code, source: https://www.appcoda.com/ios-charts-api-tutorial/
    // Add string labels: https://stackoverflow.com/questions/39049188/how-to-add-strings-on-x-axis-in-ios-charts
    func setBarChart(dataPoints: [String], values: [Double]) {
        let formatter:BarChartFormatter = BarChartFormatter(withLabels: dataPoints)
        let xAxis:XAxis = barChart.xAxis
        barChart.noDataText = "Press go to see a classification."
        
        let reversedValues = values.map( { 10000.0/$0 } )
        
        var dataEntries: [BarChartDataEntry] = []
        
        for i in 0..<dataPoints.count {
            let dataEntry = BarChartDataEntry(x: Double(i), y: reversedValues[i] )
            dataEntries.append(dataEntry)
            _ = formatter.stringForValue(Double(i), axis: xAxis) // why?
        }
        xAxis.valueFormatter = formatter
        
        let chartDataSet = BarChartDataSet(values: dataEntries, label: "Cost")
        // map color array from Joyful colors
        let colorArray:[UIColor] = dataPoints.map({ colorDictionary[$0] ?? UIColor.black })
        
        chartDataSet.colors = colorArray
        let chartData = BarChartData(dataSet: chartDataSet)
        barChart.data = chartData
        
    }
}

@objc(BarChartFormatter)
public class BarChartFormatter: NSObject, IAxisValueFormatter {
    
    var labels: [String]! = []
    
    // init might not work, be ready to create another function
    init(withLabels: [String]) {
        labels = withLabels // could do grouping work in here too
    }
    
    public func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        return labels[Int(value)]
    }
    
}
