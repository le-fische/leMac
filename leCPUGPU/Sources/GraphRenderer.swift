import AppKit

public enum GraphStyle: Int, CaseIterable {
    case stackedSparklinesWithText = 0
    case stackedWaveforms = 1
    case stackedBarsWithText = 2
    case stackedBarsCompact = 3
    case stackedTextOnly = 4
    case sideBySideSparklines = 5
    
    public var title: String {
        switch self {
        case .stackedSparklinesWithText:
            return "Stacked Sparklines + Text (Default)"
        case .stackedWaveforms:
            return "Stacked Waveforms (Top & Bottom Graphic)"
        case .stackedBarsWithText:
            return "Stacked Horizontal Bars + Text"
        case .stackedBarsCompact:
            return "Stacked Horizontal Bars (Compact)"
        case .stackedTextOnly:
            return "Stacked Numbers (C on Top, G on Bottom)"
        case .sideBySideSparklines:
            return "Side-by-Side Dual Sparklines"
        }
    }
}

public enum ColorTheme: Int, CaseIterable {
    case vibrant = 0      // Cyan for CPU, Orange for GPU
    case monochrome = 1   // System adaptive
    case dynamicAlert = 2 // Green -> Yellow -> Red based on load
    
    public var title: String {
        switch self {
        case .vibrant: return "Vibrant (Cyan CPU / Orange GPU)"
        case .monochrome: return "Monochrome (System Theme)"
        case .dynamicAlert: return "Dynamic Alert (Green/Yellow/Red)"
        }
    }
}

public class GraphRenderer {
    public static let shared = GraphRenderer()
    
    public var currentStyle: GraphStyle {
        get {
            let val = UserDefaults.standard.integer(forKey: "leCPUGPU.GraphStyle")
            return GraphStyle(rawValue: val) ?? .stackedSparklinesWithText
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "leCPUGPU.GraphStyle")
        }
    }
    
    public var currentTheme: ColorTheme {
        get {
            let val = UserDefaults.standard.integer(forKey: "leCPUGPU.ColorTheme")
            return ColorTheme(rawValue: val) ?? .vibrant
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "leCPUGPU.ColorTheme")
        }
    }
    
    private init() {}
    
    // MARK: - Color Resolution
    
    private func cpuColor(for load: Double) -> NSColor {
        switch currentTheme {
        case .vibrant:
            return NSColor(calibratedRed: 0.12, green: 0.74, blue: 1.0, alpha: 1.0)
        case .monochrome:
            return NSColor.labelColor
        case .dynamicAlert:
            return alertColor(for: load)
        }
    }
    
    private func gpuColor(for load: Double) -> NSColor {
        switch currentTheme {
        case .vibrant:
            return NSColor(calibratedRed: 1.0, green: 0.58, blue: 0.16, alpha: 1.0)
        case .monochrome:
            return NSColor.secondaryLabelColor
        case .dynamicAlert:
            return alertColor(for: load)
        }
    }
    
    private func alertColor(for load: Double) -> NSColor {
        if load >= 80.0 {
            return NSColor(calibratedRed: 1.0, green: 0.28, blue: 0.28, alpha: 1.0)
        } else if load >= 50.0 {
            return NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.18, alpha: 1.0)
        } else {
            return NSColor(calibratedRed: 0.24, green: 0.82, blue: 0.44, alpha: 1.0)
        }
    }
    
    private func metricText(percentage: Double, temp: Double) -> String {
        let mode = ThermalMonitor.shared.metricMode
        switch mode {
        case .percentages:
            return String(format: "%2.0f%%", min(99, percentage))
        case .temperatures:
            return ThermalMonitor.shared.format(celsius: temp, includeSymbol: false, short: true)
        case .percentagesAndTemperatures:
            let tStr = ThermalMonitor.shared.format(celsius: temp, includeSymbol: false, short: true)
            return String(format: "%2.0f%% %@", min(99, percentage), tStr)
        }
    }
    
    // MARK: - Main Render Entrypoint
    
    public func renderImage(cpu: Double,
                            gpu: Double,
                            cpuHistory: [Double],
                            gpuHistory: [Double],
                            cpuTemp: Double = 0.0,
                            gpuTemp: Double = 0.0) -> NSImage {
        switch currentStyle {
        case .stackedSparklinesWithText:
            return renderStackedSparklinesWithText(cpu: cpu, gpu: gpu, cpuHistory: cpuHistory, gpuHistory: gpuHistory, cpuTemp: cpuTemp, gpuTemp: gpuTemp)
        case .stackedWaveforms:
            return renderStackedWaveforms(cpu: cpu, gpu: gpu, cpuHistory: cpuHistory, gpuHistory: gpuHistory)
        case .stackedBarsWithText:
            return renderStackedBarsWithText(cpu: cpu, gpu: gpu, cpuTemp: cpuTemp, gpuTemp: gpuTemp)
        case .stackedBarsCompact:
            return renderStackedBarsCompact(cpu: cpu, gpu: gpu)
        case .stackedTextOnly:
            return renderStackedTextOnly(cpu: cpu, gpu: gpu, cpuTemp: cpuTemp, gpuTemp: gpuTemp)
        case .sideBySideSparklines:
            return renderSideBySideSparklines(cpu: cpu, gpu: gpu, cpuHistory: cpuHistory, gpuHistory: gpuHistory)
        }
    }
    
    // MARK: - Style 0: Stacked Sparklines + Text (Default)
    
    private func renderStackedSparklinesWithText(cpu: Double,
                                                 gpu: Double,
                                                 cpuHistory: [Double],
                                                 gpuHistory: [Double],
                                                 cpuTemp: Double,
                                                 gpuTemp: Double) -> NSImage {
        let isBoth = (ThermalMonitor.shared.metricMode == .percentagesAndTemperatures)
        let width: CGFloat = isBoth ? 70.0 : 53.0
        let height: CGFloat = 18.0
        
        let cpuCol = cpuColor(for: cpu)
        let gpuCol = gpuColor(for: gpu)
        
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            self.drawBackgroundPill(in: rect)
            self.drawDividerLine(in: rect)
            
            let labelFont = NSFont.systemFont(ofSize: 6.2, weight: .heavy)
            let textFont = NSFont.monospacedDigitSystemFont(ofSize: 6.8, weight: .bold)
            
            // TOP: CPU
            let topY: CGFloat = 9.0
            let cAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: cpuCol]
            "C".draw(at: NSPoint(x: 3.0, y: topY), withAttributes: cAttrs)
            
            let cpuBox = CGRect(x: 9.5, y: 10.0, width: 20.0, height: 6.0)
            self.drawSparkline(in: cpuBox, history: cpuHistory, strokeColor: cpuCol)
            
            let cpuText = self.metricText(percentage: cpu, temp: cpuTemp)
            let textAttrs: [NSAttributedString.Key: Any] = [.font: textFont, .foregroundColor: NSColor.labelColor]
            cpuText.draw(at: NSPoint(x: 31.0, y: topY), withAttributes: textAttrs)
            
            // BOTTOM: GPU
            let botY: CGFloat = 1.0
            let gAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: gpuCol]
            "G".draw(at: NSPoint(x: 3.0, y: botY), withAttributes: gAttrs)
            
            let gpuBox = CGRect(x: 9.5, y: 2.0, width: 20.0, height: 6.0)
            self.drawSparkline(in: gpuBox, history: gpuHistory, strokeColor: gpuCol)
            
            let gpuText = self.metricText(percentage: gpu, temp: gpuTemp)
            gpuText.draw(at: NSPoint(x: 31.0, y: botY), withAttributes: textAttrs)
            
            return true
        }
        image.isTemplate = false
        return image
    }
    
    // MARK: - Style 1: Stacked Waveforms (Pure Graphics)
    
    private func renderStackedWaveforms(cpu: Double,
                                        gpu: Double,
                                        cpuHistory: [Double],
                                        gpuHistory: [Double]) -> NSImage {
        let width: CGFloat = 34.0
        let height: CGFloat = 18.0
        
        let cpuCol = cpuColor(for: cpu)
        let gpuCol = gpuColor(for: gpu)
        
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            self.drawBackgroundPill(in: rect)
            self.drawDividerLine(in: rect)
            
            let labelFont = NSFont.systemFont(ofSize: 6.2, weight: .heavy)
            
            // TOP: CPU Waveform
            let cAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: cpuCol]
            "C".draw(at: NSPoint(x: 3.0, y: 9.0), withAttributes: cAttrs)
            let cpuBox = CGRect(x: 9.5, y: 10.0, width: width - 12.5, height: 6.0)
            self.drawSparkline(in: cpuBox, history: cpuHistory, strokeColor: cpuCol)
            
            // BOTTOM: GPU Waveform
            let gAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: gpuCol]
            "G".draw(at: NSPoint(x: 3.0, y: 1.0), withAttributes: gAttrs)
            let gpuBox = CGRect(x: 9.5, y: 2.0, width: width - 12.5, height: 6.0)
            self.drawSparkline(in: gpuBox, history: gpuHistory, strokeColor: gpuCol)
            
            return true
        }
        image.isTemplate = false
        return image
    }
    
    // MARK: - Style 2: Stacked Horizontal Bars + Text
    
    private func renderStackedBarsWithText(cpu: Double,
                                           gpu: Double,
                                           cpuTemp: Double,
                                           gpuTemp: Double) -> NSImage {
        let isBoth = (ThermalMonitor.shared.metricMode == .percentagesAndTemperatures)
        let width: CGFloat = isBoth ? 68.0 : 50.0
        let height: CGFloat = 18.0
        
        let cpuCol = cpuColor(for: cpu)
        let gpuCol = gpuColor(for: gpu)
        
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            self.drawBackgroundPill(in: rect)
            self.drawDividerLine(in: rect)
            
            let labelFont = NSFont.systemFont(ofSize: 6.2, weight: .heavy)
            let textFont = NSFont.monospacedDigitSystemFont(ofSize: 6.8, weight: .bold)
            
            // TOP: CPU
            let topY: CGFloat = 9.0
            let cAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: cpuCol]
            "C".draw(at: NSPoint(x: 3.0, y: topY), withAttributes: cAttrs)
            
            let cpuBar = CGRect(x: 9.5, y: 10.5, width: 17.0, height: 5.0)
            self.drawHorizontalBar(in: cpuBar, value: cpu, color: cpuCol)
            
            let cpuText = self.metricText(percentage: cpu, temp: cpuTemp)
            let textAttrs: [NSAttributedString.Key: Any] = [.font: textFont, .foregroundColor: NSColor.labelColor]
            cpuText.draw(at: NSPoint(x: 28.0, y: topY), withAttributes: textAttrs)
            
            // BOTTOM: GPU
            let botY: CGFloat = 1.0
            let gAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: gpuCol]
            "G".draw(at: NSPoint(x: 3.0, y: botY), withAttributes: gAttrs)
            
            let gpuBar = CGRect(x: 9.5, y: 2.5, width: 17.0, height: 5.0)
            self.drawHorizontalBar(in: gpuBar, value: gpu, color: gpuCol)
            
            let gpuText = self.metricText(percentage: gpu, temp: gpuTemp)
            gpuText.draw(at: NSPoint(x: 28.0, y: botY), withAttributes: textAttrs)
            
            return true
        }
        image.isTemplate = false
        return image
    }
    
    // MARK: - Style 3: Stacked Horizontal Bars (Compact)
    
    private func renderStackedBarsCompact(cpu: Double, gpu: Double) -> NSImage {
        let width: CGFloat = 24.0
        let height: CGFloat = 18.0
        
        let cpuCol = cpuColor(for: cpu)
        let gpuCol = gpuColor(for: gpu)
        
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            self.drawBackgroundPill(in: rect)
            self.drawDividerLine(in: rect)
            
            let barW: CGFloat = width - 6.0
            let cpuBar = CGRect(x: 3.0, y: 10.5, width: barW, height: 5.0)
            let gpuBar = CGRect(x: 3.0, y: 2.5, width: barW, height: 5.0)
            
            self.drawHorizontalBar(in: cpuBar, value: cpu, color: cpuCol)
            self.drawHorizontalBar(in: gpuBar, value: gpu, color: gpuCol)
            
            return true
        }
        image.isTemplate = false
        return image
    }
    
    // MARK: - Style 4: Stacked Text Only
    
    private func renderStackedTextOnly(cpu: Double,
                                       gpu: Double,
                                       cpuTemp: Double,
                                       gpuTemp: Double) -> NSImage {
        let isBoth = (ThermalMonitor.shared.metricMode == .percentagesAndTemperatures)
        let width: CGFloat = isBoth ? 56.0 : 34.0
        let height: CGFloat = 18.0
        
        let cpuCol = cpuColor(for: cpu)
        let gpuCol = gpuColor(for: gpu)
        
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            self.drawBackgroundPill(in: rect)
            self.drawDividerLine(in: rect)
            
            let font = NSFont.monospacedDigitSystemFont(ofSize: 7.0, weight: .bold)
            
            let cStr = "C:" + self.metricText(percentage: cpu, temp: cpuTemp)
            let cAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: cpuCol]
            cStr.draw(at: NSPoint(x: 3.0, y: 9.0), withAttributes: cAttrs)
            
            let gStr = "G:" + self.metricText(percentage: gpu, temp: gpuTemp)
            let gAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: gpuCol]
            gStr.draw(at: NSPoint(x: 3.0, y: 1.0), withAttributes: gAttrs)
            
            return true
        }
        image.isTemplate = false
        return image
    }
    
    // MARK: - Style 5: Side-by-Side Dual Sparklines (Option)
    
    private func renderSideBySideSparklines(cpu: Double,
                                            gpu: Double,
                                            cpuHistory: [Double],
                                            gpuHistory: [Double]) -> NSImage {
        let width: CGFloat = 62.0
        let height: CGFloat = 18.0
        
        let cpuCol = cpuColor(for: cpu)
        let gpuCol = gpuColor(for: gpu)
        
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            let boxWidth: CGFloat = 27.0
            let boxHeight: CGFloat = 14.0
            let y = (rect.height - boxHeight) / 2.0
            
            let cpuBox = CGRect(x: 2.0, y: y, width: boxWidth, height: boxHeight)
            let gpuBox = CGRect(x: 33.0, y: y, width: boxWidth, height: boxHeight)
            
            self.drawBoxPill(in: cpuBox)
            self.drawBoxPill(in: gpuBox)
            
            let labelFont = NSFont.monospacedSystemFont(ofSize: 6.5, weight: .heavy)
            let cAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: cpuCol.withAlphaComponent(0.85)]
            "C".draw(at: NSPoint(x: cpuBox.minX + 2.0, y: cpuBox.maxY - 7.0), withAttributes: cAttrs)
            
            let gAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: gpuCol.withAlphaComponent(0.85)]
            "G".draw(at: NSPoint(x: gpuBox.minX + 2.0, y: gpuBox.maxY - 7.0), withAttributes: gAttrs)
            
            self.drawSparkline(in: cpuBox, history: cpuHistory, strokeColor: cpuCol)
            self.drawSparkline(in: gpuBox, history: gpuHistory, strokeColor: gpuCol)
            return true
        }
        image.isTemplate = (currentTheme == .monochrome)
        return image
    }
    
    // MARK: - Drawing Helpers
    
    private func drawBackgroundPill(in rect: CGRect) {
        let pillRect = CGRect(x: 1.0, y: 1.0, width: rect.width - 2.0, height: rect.height - 2.0)
        let pill = NSBezierPath(roundedRect: pillRect, xRadius: 3.0, yRadius: 3.0)
        NSColor.black.withAlphaComponent(0.28).setFill()
        pill.fill()
    }
    
    private func drawBoxPill(in rect: CGRect) {
        let pill = NSBezierPath(roundedRect: rect, xRadius: 2.5, yRadius: 2.5)
        NSColor.black.withAlphaComponent(0.25).setFill()
        pill.fill()
    }
    
    private func drawDividerLine(in rect: CGRect) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 3.0, y: 9.0))
        path.line(to: NSPoint(x: rect.width - 3.0, y: 9.0))
        path.lineWidth = 0.5
        NSColor.white.withAlphaComponent(0.12).setStroke()
        path.stroke()
    }
    
    private func drawSparkline(in box: CGRect,
                               history: [Double],
                               strokeColor: NSColor) {
        guard history.count > 1 else { return }
        
        let stepX = box.width / CGFloat(history.count - 1)
        let innerHeight = box.height - 1.0
        let bottomY = box.minY + 0.5
        
        let strokePath = NSBezierPath()
        strokePath.lineWidth = 1.0
        strokePath.lineJoinStyle = .round
        strokePath.lineCapStyle = .round
        
        let fillPath = NSBezierPath()
        fillPath.move(to: NSPoint(x: box.minX, y: bottomY))
        
        for (i, val) in history.enumerated() {
            let clamped = max(0.0, min(100.0, val))
            let normalized = CGFloat(clamped / 100.0)
            let px = box.minX + CGFloat(i) * stepX
            let py = bottomY + normalized * innerHeight
            
            let pt = NSPoint(x: px, y: py)
            if i == 0 {
                strokePath.move(to: pt)
                fillPath.line(to: pt)
            } else {
                strokePath.line(to: pt)
                fillPath.line(to: pt)
            }
        }
        
        fillPath.line(to: NSPoint(x: box.maxX, y: bottomY))
        fillPath.close()
        
        strokeColor.withAlphaComponent(0.28).setFill()
        fillPath.fill()
        
        strokeColor.setStroke()
        strokePath.stroke()
    }
    
    private func drawHorizontalBar(in rect: CGRect, value: Double, color: NSColor) {
        // Track background
        let trackPath = NSBezierPath(roundedRect: rect, xRadius: 1.2, yRadius: 1.2)
        NSColor.black.withAlphaComponent(0.35).setFill()
        trackPath.fill()
        
        let clamped = max(0.0, min(100.0, value))
        let filledWidth = max(1.5, rect.width * CGFloat(clamped / 100.0))
        let fillRect = CGRect(x: rect.minX, y: rect.minY, width: filledWidth, height: rect.height)
        
        let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 1.2, yRadius: 1.2)
        color.setFill()
        fillPath.fill()
    }
}
