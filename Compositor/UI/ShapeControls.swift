import SwiftUI

struct ShapeControls: View {
    @Bindable var session: EditorSession
    /// The selected shape, when the bar is editing that layer rather than the next shape to be drawn.
    private var inspected: LayerShapeStyle? { session.inspectedShape?.style }
    private var kind: ShapeKind { inspected?.kind ?? session.shapeKind }

    var body: some View {
        HStack(spacing: 12) {
            Text("Shape").font(ToolHeaderStyle.titleFont)
            Picker("Shape", selection: Binding(get: { kind }, set: { kind in
                session.cancelShape()
                if session.inspectedShape != nil { session.updateSelectedShape { $0.kind = kind } }
                else { session.shapeKind = kind }
            })) {
                ForEach(ShapeKind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
            .help("Shift-U (or Tab) steps through Rectangle, Ellipse and Line")
            HStack(spacing: 6) {
                Text("Color")
                Button {
                    if session.inspectedShape != nil { session.openShapeColorPicker() }
                    else { session.openColorPicker(background: false) }
                } label: {
                    let color = inspected?.color ?? session.foregroundColor
                    ColorSwatch(color: Color(nsColor: color.nsColor))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fill color")
                .help(inspected == nil ? "Shapes fill with the foreground color; click to change it" : "The selected shape's color")
            }
            if kind == .line {
                HStack(spacing: 6) {
                    Text("Width").scrubbable(sensitivity: 1, value: lineWidth, range: 1...5000, onStart: { shapeGesture(true) }, onEnd: { shapeGesture(false) })
                    // The slider covers everyday widths; typing or scrubbing reaches up to 5000.
                    AppSlider(value: Binding(get: { min(50, lineWidth.wrappedValue) },
                                          set: { lineWidth.wrappedValue = $0.rounded() }), in: 1...50,
                              onEditingChanged: shapeGesture)
                        .frame(width: 100)
                    TextField("Width", value: lineWidth, format: .number.precision(.fractionLength(0)))
                        .frame(width: 48).textFieldStyle(.roundedBorder)
                        .arrowSteps(value: { lineWidth.wrappedValue },
                                    change: { lineWidth.wrappedValue = min(5000, max(1, $0)) })
                }
                HStack(spacing: 6) {
                    Text("Style")
                    Picker("Style", selection: lineStyle) {
                        ForEach(ShapeLineStyle.allCases, id: \.self) { style in
                            Image(nsImage: LineSample.style(style)).accessibilityLabel(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.menu).labelsHidden().fixedSize()
                }
                .help("Solid, dashed or dotted; dashes grow with the line's width")
                HStack(spacing: 6) {
                    Text("Cap")
                    Picker("Cap", selection: lineCap) {
                        ForEach(ShapeLineCap.allCases, id: \.self) { cap in
                            Label { Text(cap.rawValue) } icon: { Image(nsImage: LineSample.cap(cap)) }.tag(cap)
                        }
                    }
                    .pickerStyle(.menu).labelsHidden().fixedSize()
                }
                .help("How the line's ends, and each of its dashes and dots, are finished")
            }
            if kind == .rectangle {
                HStack(spacing: 6) {
                    Text("Radius").scrubbable(sensitivity: 1, value: cornerRadius, range: 0...5000, onStart: { shapeGesture(true) }, onEnd: { shapeGesture(false) })
                    AppSlider(value: Binding(get: { min(200, cornerRadius.wrappedValue) },
                                          set: { cornerRadius.wrappedValue = $0.rounded() }), in: 0...200,
                              onEditingChanged: shapeGesture)
                        .frame(width: 100)
                    TextField("Radius", value: cornerRadius, format: .number.precision(.fractionLength(0)))
                        .frame(width: 48).textFieldStyle(.roundedBorder)
                        .arrowSteps(value: { cornerRadius.wrappedValue },
                                    change: { cornerRadius.wrappedValue = min(5000, max(0, $0)) })
                }
                .help("Round the rectangle's corners by this many pixels; 0 keeps them square")
                Toggle("Smooth Corners", isOn: smoothing)
                    .toggleStyle(.checkbox)
                    .fixedSize()
                    .disabled(cornerRadius.wrappedValue <= 0)
                    .help(cornerRadius.wrappedValue <= 0
                          ? "Set a radius above 0 to use smooth corners."
                          : "Use smooth squircle corners at 60% smoothing, matching Figma's iOS setting")
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18).toolHeaderBar().releasesFocusOnCommit(session)
        .disabled(session.showsBusy || session.document == nil)
    }

    /// A slider or scrub on the selected shape is one undo step. The shape color picker owns its own step, so a
    /// slider let go while that picker is open leaves the step to the picker.
    private func shapeGesture(_ editing: Bool) {
        guard session.inspectedShape != nil else { return }
        if editing { session.beginShapeStyleEdit() }
        else if case .shape = session.colorPicker?.target {}
        else { session.finishShapeStyleEdit(commit: true) }
    }

    private var lineWidth: Binding<Double> {
        Binding(get: {
            if let style = session.inspectedShape?.style, style.kind == .line { return Double(style.lineWidth ?? CGFloat(session.shapeLineWidth)) }
            return session.shapeLineWidth
        }, set: { value in
            let width = min(5000, max(1, value.isFinite ? value : session.shapeLineWidth))
            if session.inspectedShape?.style.kind == .line { session.updateSelectedShape { $0.lineWidth = CGFloat(width) } }
            else { session.shapeLineWidth = width }
        })
    }
    private var lineStyle: Binding<ShapeLineStyle> {
        Binding(get: {
            if let style = session.inspectedShape?.style, style.kind == .line { return style.lineStyle ?? .solid }
            return session.shapeLineStyle
        }, set: { value in
            if session.inspectedShape?.style.kind == .line { session.updateSelectedShape { $0.lineStyle = value } }
            else { session.shapeLineStyle = value }
        })
    }
    private var lineCap: Binding<ShapeLineCap> {
        Binding(get: {
            if let style = session.inspectedShape?.style, style.kind == .line { return style.lineCap ?? .round }
            return session.shapeLineCap
        }, set: { value in
            if session.inspectedShape?.style.kind == .line { session.updateSelectedShape { $0.lineCap = value } }
            else { session.shapeLineCap = value }
        })
    }
    private var cornerRadius: Binding<Double> {
        Binding(get: {
            if let style = session.inspectedShape?.style, style.kind == .rectangle { return Double(style.cornerRadius) }
            return session.shapeCornerRadius
        }, set: { value in
            let radius = min(5000, max(0, value.isFinite ? value : 0))
            if session.inspectedShape?.style.kind == .rectangle { session.updateSelectedShape { $0.cornerRadius = CGFloat(radius) } }
            else { session.shapeCornerRadius = radius }
        })
    }
    private var smoothing: Binding<Bool> {
        Binding(get: {
            if let style = session.inspectedShape?.style, style.kind == .rectangle { return style.smoothing == true }
            return session.shapeSmoothing
        }, set: { value in
            if session.inspectedShape?.style.kind == .rectangle { session.updateSelectedShape { $0.smoothing = value ? true : nil } }
            else { session.shapeSmoothing = value }
        })
    }
}

/// Small drawings for the Line shape's menus. Template images, so a menu tints them with its text and highlight.
@MainActor private enum LineSample {
    private static var images: [String: NSImage] = [:]

    /// A stretch of line in `style`, as it looks drawn.
    static func style(_ style: ShapeLineStyle) -> NSImage {
        image("style." + style.rawValue, size: NSSize(width: 84, height: 10)) { context in
            context.strokeShapeLine(from: CGPoint(x: 2, y: 5), to: CGPoint(x: 82, y: 5), width: 2, style: style, cap: .round)
        }
    }

    /// The end of a thick line in outline, with its center line running into the cap.
    static func cap(_ cap: ShapeLineCap) -> NSImage {
        image("cap." + cap.rawValue, size: NSSize(width: 18, height: 14)) { context in
            let center = CGMutablePath()
            center.move(to: CGPoint(x: 0, y: 7))
            center.addLine(to: CGPoint(x: 10, y: 7))
            context.addPath(center.copy(strokingWithWidth: 11, lineCap: cap.cgLineCap, lineJoin: .miter, miterLimit: 10))
            context.setLineWidth(1.5)
            context.strokePath()
            context.addPath(center)
            context.setLineWidth(1.5)
            context.strokePath()
            context.fillEllipse(in: CGRect(x: 8, y: 5, width: 4, height: 4))
        }
    }

    private static func image(_ key: String, size: NSSize, draw: @escaping (CGContext) -> Void) -> NSImage {
        if let image = images[key] { return image }
        let image = NSImage(size: size, flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.setStrokeColor(.black)
            context.setFillColor(.black)
            draw(context)
            return true
        }
        image.isTemplate = true
        images[key] = image
        return image
    }
}
