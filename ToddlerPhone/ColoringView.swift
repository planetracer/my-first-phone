import SwiftUI

// MARK: - Path helpers
//
// Every picture is hand authored in a 0...1 unit square and scaled to the
// canvas at draw time. The canvas is always square, so shapes keep their
// proportions on any phone and the same code draws the tiny thumbnails.

enum Art {
    /// Unit point to canvas point.
    static func p(_ x: CGFloat, _ y: CGFloat, _ s: CGSize) -> CGPoint {
        CGPoint(x: x * s.width, y: y * s.height)
    }

    /// Smooth closed curve through the given unit points (Catmull-Rom turned
    /// into cubic Beziers). This is what gives the pictures their soft
    /// hand-drawn outlines.
    static func blob(_ pts: [(CGFloat, CGFloat)], _ s: CGSize, smooth: CGFloat = 1) -> Path {
        var path = Path()
        guard pts.count >= 3 else { return path }
        let q = pts.map { p($0.0, $0.1, s) }
        let n = q.count
        path.move(to: q[0])
        for i in 0..<n {
            let a = q[(i - 1 + n) % n]
            let b = q[i]
            let c = q[(i + 1) % n]
            let d = q[(i + 2) % n]
            let c1 = CGPoint(x: b.x + (c.x - a.x) / 6 * smooth, y: b.y + (c.y - a.y) / 6 * smooth)
            let c2 = CGPoint(x: c.x - (d.x - b.x) / 6 * smooth, y: c.y - (d.y - b.y) / 6 * smooth)
            path.addCurve(to: c, control1: c1, control2: c2)
        }
        path.closeSubpath()
        return path
    }

    /// Straight sided closed shape.
    static func poly(_ pts: [(CGFloat, CGFloat)], _ s: CGSize) -> Path {
        var path = Path()
        guard let first = pts.first else { return path }
        path.move(to: p(first.0, first.1, s))
        for q in pts.dropFirst() { path.addLine(to: p(q.0, q.1, s)) }
        path.closeSubpath()
        return path
    }

    /// Ellipse from four cubic segments, optionally rotated.
    static func oval(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat,
                     _ s: CGSize, rotation: CGFloat = 0) -> Path {
        let k: CGFloat = 0.5523
        let co = cos(rotation)
        let si = sin(rotation)
        func at(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint {
            p(cx + dx * co - dy * si, cy + dx * si + dy * co, s)
        }
        var path = Path()
        path.move(to: at(rx, 0))
        path.addCurve(to: at(0, ry), control1: at(rx, ry * k), control2: at(rx * k, ry))
        path.addCurve(to: at(-rx, 0), control1: at(-rx * k, ry), control2: at(-rx, ry * k))
        path.addCurve(to: at(0, -ry), control1: at(-rx, -ry * k), control2: at(-rx * k, -ry))
        path.addCurve(to: at(rx, 0), control1: at(rx * k, -ry), control2: at(rx, -ry * k))
        path.closeSubpath()
        return path
    }

    /// Rounded rectangle built from lines and corner arcs.
    static func box(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat,
                    _ s: CGSize, r: CGFloat = 0.02) -> Path {
        let rect = CGRect(x: x0 * s.width, y: y0 * s.height,
                          width: (x1 - x0) * s.width, height: (y1 - y0) * s.height)
        let rr = max(0.5, min(r * min(s.width, s.height), min(rect.width, rect.height) / 2))
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rr, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - rr, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - rr, y: rect.minY + rr), radius: rr,
                    startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - rr))
        path.addArc(center: CGPoint(x: rect.maxX - rr, y: rect.maxY - rr), radius: rr,
                    startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + rr, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + rr, y: rect.maxY - rr), radius: rr,
                    startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rr))
        path.addArc(center: CGPoint(x: rect.minX + rr, y: rect.minY + rr), radius: rr,
                    startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }

    /// Pointy star, used for sun rays and night sky.
    static func star(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ s: CGSize,
                     points: Int = 5, inner: CGFloat = 0.45, rotation: CGFloat = -.pi / 2) -> Path {
        var pts: [(CGFloat, CGFloat)] = []
        let step = CGFloat.pi / CGFloat(max(3, points))
        for i in 0..<(max(3, points) * 2) {
            let radius = i % 2 == 0 ? r : r * inner
            let angle = rotation + step * CGFloat(i)
            pts.append((cx + cos(angle) * radius, cy + sin(angle) * radius))
        }
        return poly(pts, s)
    }

    /// Gently bending band, used for stems, seaweed and the fire hose.
    static func stem(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat,
                     _ s: CGSize, bend: CGFloat = 0, width: CGFloat = 0.02, taper: CGFloat = 0.6) -> Path {
        let mx = (x0 + x1) / 2 + bend
        let my = (y0 + y1) / 2
        let w1 = width * taper
        var path = Path()
        path.move(to: p(x0 - width, y0, s))
        path.addQuadCurve(to: p(x1 - w1, y1, s), control: p(mx - width, my, s))
        path.addLine(to: p(x1 + w1, y1, s))
        path.addQuadCurve(to: p(x0 + width, y0, s), control: p(mx + width, my, s))
        path.closeSubpath()
        return path
    }

    /// Teardrop petal growing out of a flower center.
    static func petal(_ cx: CGFloat, _ cy: CGFloat, _ s: CGSize,
                      angle: CGFloat, len: CGFloat, wid: CGFloat) -> Path {
        let dx = cos(angle)
        let dy = sin(angle)
        func at(_ along: CGFloat, _ across: CGFloat) -> CGPoint {
            p(cx + dx * along - dy * across, cy + dy * along + dx * across, s)
        }
        var path = Path()
        path.move(to: at(len * 0.1, 0))
        path.addCurve(to: at(len, 0),
                      control1: at(len * 0.25, wid), control2: at(len * 0.96, wid * 0.8))
        path.addCurve(to: at(len * 0.1, 0),
                      control1: at(len * 0.96, -wid * 0.8), control2: at(len * 0.25, -wid))
        path.closeSubpath()
        return path
    }

    /// Ground or water line with a soft rise in the middle.
    static func ground(_ y: CGFloat, _ s: CGSize, dip: CGFloat = 0.02) -> Path {
        var path = Path()
        path.move(to: p(0, y, s))
        path.addQuadCurve(to: p(1, y - dip * 0.6, s), control: p(0.5, y - dip * 2, s))
        path.addLine(to: p(1, 1, s))
        path.addLine(to: p(0, 1, s))
        path.closeSubpath()
        return path
    }

    /// Slice of a squashed ring, used for the planet ring.
    static func ringArc(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ s: CGSize,
                        from: CGFloat, to: CGFloat, thickness: CGFloat,
                        squash: CGFloat, rotation: CGFloat) -> Path {
        let k = min(s.width, s.height)
        var local = Path()
        local.addArc(center: .zero, radius: r * k,
                     startAngle: .radians(Double(from)), endAngle: .radians(Double(to)), clockwise: false)
        local.addArc(center: .zero, radius: (r - thickness) * k,
                     startAngle: .radians(Double(to)), endAngle: .radians(Double(from)), clockwise: true)
        local.closeSubpath()
        var t = CGAffineTransform.identity
        t = t.translatedBy(x: cx * s.width, y: cy * s.height)
        t = t.rotated(by: rotation)
        t = t.scaledBy(x: 1, y: squash)
        return local.applying(t)
    }
}

// MARK: - Page model

struct ColorRegion: Identifiable {
    let id: Int
    let build: (CGSize) -> Path
}

struct ColoringPage: Identifiable {
    let id: String
    let name: String
    let regions: [ColorRegion]

    init(id: String, name: String, shapes: [(CGSize) -> Path]) {
        self.id = id
        self.name = name
        self.regions = shapes.enumerated().map { ColorRegion(id: $0.offset, build: $0.element) }
    }
}

// MARK: - The pictures

extension ColoringPage {
    static let all: [ColoringPage] = [cat, fireTruck, dinosaur, rocket, fishTank, garden]

    // Cat sitting on the floor, 20 regions.
    static let cat = ColoringPage(id: "cat", name: "Cat", shapes: [
        { (s: CGSize) -> Path in Art.ground(0.87, s, dip: 0.015) },
        { (s: CGSize) -> Path in
            Art.blob([(0.66, 0.86), (0.80, 0.89), (0.90, 0.79), (0.88, 0.64), (0.79, 0.60),
                      (0.74, 0.66), (0.81, 0.70), (0.82, 0.77), (0.75, 0.81), (0.66, 0.80)], s) },
        { (s: CGSize) -> Path in
            Art.blob([(0.50, 0.40), (0.62, 0.46), (0.68, 0.62), (0.70, 0.80), (0.62, 0.87),
                      (0.50, 0.89), (0.38, 0.87), (0.30, 0.80), (0.32, 0.62), (0.38, 0.46)], s) },
        { (s: CGSize) -> Path in Art.oval(0.50, 0.70, 0.13, 0.15, s) },
        { (s: CGSize) -> Path in
            Art.blob([(0.36, 0.74), (0.33, 0.82), (0.34, 0.88), (0.42, 0.88), (0.43, 0.80), (0.42, 0.74)], s) },
        { (s: CGSize) -> Path in
            Art.blob([(0.64, 0.74), (0.67, 0.82), (0.66, 0.88), (0.58, 0.88), (0.57, 0.80), (0.58, 0.74)], s) },
        { (s: CGSize) -> Path in Art.oval(0.378, 0.885, 0.055, 0.032, s) },
        { (s: CGSize) -> Path in Art.oval(0.622, 0.885, 0.055, 0.032, s) },
        { (s: CGSize) -> Path in
            Art.blob([(0.34, 0.415), (0.50, 0.475), (0.66, 0.415), (0.65, 0.375),
                      (0.50, 0.435), (0.35, 0.375)], s) },
        { (s: CGSize) -> Path in Art.oval(0.50, 0.495, 0.036, 0.036, s) },
        { (s: CGSize) -> Path in Art.poly([(0.330, 0.225), (0.300, 0.045), (0.470, 0.132)], s) },
        { (s: CGSize) -> Path in Art.poly([(0.670, 0.225), (0.700, 0.045), (0.530, 0.132)], s) },
        { (s: CGSize) -> Path in Art.poly([(0.352, 0.192), (0.330, 0.082), (0.436, 0.130)], s) },
        { (s: CGSize) -> Path in Art.poly([(0.648, 0.192), (0.670, 0.082), (0.564, 0.130)], s) },
        { (s: CGSize) -> Path in
            Art.blob([(0.50, 0.11), (0.66, 0.15), (0.71, 0.27), (0.66, 0.39),
                      (0.50, 0.44), (0.34, 0.39), (0.29, 0.27), (0.34, 0.15)], s) },
        { (s: CGSize) -> Path in Art.oval(0.437, 0.338, 0.077, 0.056, s) },
        { (s: CGSize) -> Path in Art.oval(0.563, 0.338, 0.077, 0.056, s) },
        { (s: CGSize) -> Path in Art.poly([(0.500, 0.330), (0.541, 0.281), (0.459, 0.281)], s) },
        { (s: CGSize) -> Path in Art.oval(0.425, 0.245, 0.045, 0.056, s) },
        { (s: CGSize) -> Path in Art.oval(0.575, 0.245, 0.045, 0.056, s) },
    ])

    // Fire truck on the road, 28 regions.
    static let fireTruck = ColoringPage(id: "truck", name: "Fire truck", shapes: [
        { (s: CGSize) -> Path in Art.ground(0.845, s, dip: 0) },
        { (s: CGSize) -> Path in Art.box(0.06, 0.900, 0.26, 0.935, s, r: 0.014) },
        { (s: CGSize) -> Path in Art.box(0.38, 0.900, 0.58, 0.935, s, r: 0.014) },
        { (s: CGSize) -> Path in Art.box(0.70, 0.900, 0.90, 0.935, s, r: 0.014) },
        { (s: CGSize) -> Path in Art.box(0.30, 0.500, 0.94, 0.745, s, r: 0.025) },
        { (s: CGSize) -> Path in
            Art.poly([(0.07, 0.745), (0.07, 0.530), (0.15, 0.400), (0.32, 0.400), (0.32, 0.745)], s) },
        { (s: CGSize) -> Path in Art.box(0.56, 0.545, 0.78, 0.665, s, r: 0.018) },
        { (s: CGSize) -> Path in Art.oval(0.865, 0.610, 0.052, 0.052, s) },
        { (s: CGSize) -> Path in Art.box(0.145, 0.575, 0.300, 0.720, s, r: 0.018) },
        { (s: CGSize) -> Path in Art.box(0.250, 0.628, 0.292, 0.656, s, r: 0.012) },
        { (s: CGSize) -> Path in Art.box(0.145, 0.435, 0.300, 0.545, s, r: 0.018) },
        { (s: CGSize) -> Path in Art.box(0.030, 0.690, 0.130, 0.775, s, r: 0.015) },
        { (s: CGSize) -> Path in Art.box(0.905, 0.660, 0.975, 0.755, s, r: 0.015) },
        { (s: CGSize) -> Path in Art.poly([(0.372, 0.545), (0.528, 0.545), (0.498, 0.478), (0.402, 0.478)], s) },
        { (s: CGSize) -> Path in Art.box(0.355, 0.445, 0.945, 0.478, s, r: 0.012) },
        { (s: CGSize) -> Path in Art.box(0.355, 0.342, 0.945, 0.375, s, r: 0.012) },
        { (s: CGSize) -> Path in Art.box(0.422, 0.372, 0.458, 0.448, s, r: 0.008) },
        { (s: CGSize) -> Path in Art.box(0.522, 0.372, 0.558, 0.448, s, r: 0.008) },
        { (s: CGSize) -> Path in Art.box(0.622, 0.372, 0.658, 0.448, s, r: 0.008) },
        { (s: CGSize) -> Path in Art.box(0.722, 0.372, 0.758, 0.448, s, r: 0.008) },
        { (s: CGSize) -> Path in Art.box(0.822, 0.372, 0.858, 0.448, s, r: 0.008) },
        { (s: CGSize) -> Path in Art.box(0.130, 0.318, 0.300, 0.372, s, r: 0.020) },
        { (s: CGSize) -> Path in Art.oval(0.172, 0.305, 0.024, 0.024, s) },
        { (s: CGSize) -> Path in Art.oval(0.258, 0.305, 0.024, 0.024, s) },
        { (s: CGSize) -> Path in Art.oval(0.300, 0.755, 0.090, 0.090, s) },
        { (s: CGSize) -> Path in Art.oval(0.760, 0.755, 0.090, 0.090, s) },
        { (s: CGSize) -> Path in Art.oval(0.300, 0.755, 0.038, 0.038, s) },
        { (s: CGSize) -> Path in Art.oval(0.760, 0.755, 0.038, 0.038, s) },
    ])

    // Dinosaur in the sunshine, 24 regions.
    static let dinosaur = ColoringPage(id: "dino", name: "Dinosaur", shapes: [
        { (s: CGSize) -> Path in Art.star(0.16, 0.17, 0.155, s, points: 10, inner: 0.62) },
        { (s: CGSize) -> Path in Art.oval(0.16, 0.17, 0.090, 0.090, s) },
        { (s: CGSize) -> Path in
            Art.blob([(0.62, 0.17), (0.67, 0.10), (0.76, 0.10), (0.82, 0.16), (0.77, 0.22), (0.65, 0.22)], s) },
        { (s: CGSize) -> Path in
            Art.blob([(0.40, 0.18), (0.44, 0.12), (0.51, 0.12), (0.56, 0.18), (0.51, 0.235), (0.43, 0.235)], s) },
        { (s: CGSize) -> Path in Art.ground(0.80, s, dip: 0.02) },
        { (s: CGSize) -> Path in
            Art.blob([(0.84, 0.81), (0.87, 0.73), (0.93, 0.71), (0.97, 0.76), (0.96, 0.82)], s) },
        { (s: CGSize) -> Path in
            Art.blob([(0.38, 0.66), (0.43, 0.68), (0.44, 0.79), (0.37, 0.80), (0.34, 0.72)], s) },
        { (s: CGSize) -> Path in
            Art.blob([(0.34, 0.585), (0.22, 0.615), (0.11, 0.655), (0.05, 0.705), (0.13, 0.705),
                      (0.24, 0.675), (0.34, 0.665)], s) },
        { (s: CGSize) -> Path in
            Art.blob([(0.36, 0.50), (0.50, 0.455), (0.62, 0.49), (0.68, 0.58), (0.66, 0.70),
                      (0.54, 0.755), (0.40, 0.745), (0.315, 0.665), (0.31, 0.57)], s) },
        { (s: CGSize) -> Path in Art.oval(0.50, 0.665, 0.130, 0.072, s) },
        { (s: CGSize) -> Path in
            Art.blob([(0.40, 0.70), (0.47, 0.72), (0.475, 0.82), (0.40, 0.83), (0.365, 0.75)], s) },
        { (s: CGSize) -> Path in
            Art.blob([(0.56, 0.70), (0.63, 0.72), (0.635, 0.82), (0.56, 0.83), (0.525, 0.75)], s) },
        { (s: CGSize) -> Path in Art.poly([(0.325, 0.505), (0.355, 0.425), (0.400, 0.495)], s) },
        { (s: CGSize) -> Path in Art.poly([(0.400, 0.485), (0.440, 0.380), (0.490, 0.465)], s) },
        { (s: CGSize) -> Path in Art.poly([(0.480, 0.462), (0.530, 0.355), (0.580, 0.452)], s) },
        { (s: CGSize) -> Path in Art.poly([(0.570, 0.462), (0.612, 0.375), (0.652, 0.480)], s) },
        { (s: CGSize) -> Path in Art.poly([(0.645, 0.500), (0.682, 0.430), (0.712, 0.522)], s) },
        { (s: CGSize) -> Path in Art.poly([(0.205, 0.640), (0.205, 0.552), (0.268, 0.616)], s) },
        { (s: CGSize) -> Path in Art.poly([(0.115, 0.672), (0.098, 0.588), (0.180, 0.646)], s) },
        { (s: CGSize) -> Path in
            Art.blob([(0.615, 0.520), (0.665, 0.435), (0.735, 0.375), (0.800, 0.385),
                      (0.760, 0.465), (0.700, 0.550)], s) },
        { (s: CGSize) -> Path in
            Art.blob([(0.745, 0.390), (0.800, 0.315), (0.890, 0.315), (0.935, 0.375),
                      (0.900, 0.445), (0.800, 0.455)], s) },
        { (s: CGSize) -> Path in Art.oval(0.848, 0.365, 0.024, 0.026, s) },
        { (s: CGSize) -> Path in
            Art.poly([(0.862, 0.422), (0.932, 0.398), (0.930, 0.424), (0.868, 0.442)], s) },
        { (s: CGSize) -> Path in Art.oval(0.912, 0.352, 0.013, 0.013, s) },
    ])

    // Rocket in space, 24 regions.
    static let rocket = ColoringPage(id: "rocket", name: "Rocket", shapes: [
        { (s: CGSize) -> Path in Art.star(0.09, 0.16, 0.055, s) },
        { (s: CGSize) -> Path in Art.star(0.30, 0.08, 0.042, s) },
        { (s: CGSize) -> Path in Art.star(0.93, 0.42, 0.048, s) },
        { (s: CGSize) -> Path in Art.star(0.07, 0.45, 0.038, s) },
        { (s: CGSize) -> Path in Art.star(0.68, 0.09, 0.036, s, points: 4, inner: 0.38) },
        { (s: CGSize) -> Path in
            Art.ringArc(0.190, 0.865, 0.170, s, from: .pi, to: 2 * .pi,
                        thickness: 0.040, squash: 0.34, rotation: -0.28) },
        { (s: CGSize) -> Path in Art.oval(0.190, 0.865, 0.115, 0.115, s) },
        { (s: CGSize) -> Path in Art.oval(0.152, 0.835, 0.036, 0.025, s, rotation: -0.3) },
        { (s: CGSize) -> Path in Art.oval(0.232, 0.905, 0.028, 0.020, s, rotation: -0.3) },
        { (s: CGSize) -> Path in
            Art.ringArc(0.190, 0.865, 0.170, s, from: 0, to: .pi,
                        thickness: 0.040, squash: 0.34, rotation: -0.28) },
        { (s: CGSize) -> Path in Art.oval(0.845, 0.165, 0.105, 0.105, s) },
        { (s: CGSize) -> Path in Art.oval(0.812, 0.128, 0.028, 0.024, s) },
        { (s: CGSize) -> Path in Art.oval(0.885, 0.198, 0.022, 0.019, s) },
        { (s: CGSize) -> Path in Art.oval(0.808, 0.215, 0.018, 0.016, s) },
        { (s: CGSize) -> Path in
            Art.blob([(0.385, 0.750), (0.440, 0.870), (0.500, 0.975), (0.560, 0.870),
                      (0.615, 0.750), (0.500, 0.720)], s) },
        { (s: CGSize) -> Path in Art.blob([(0.450, 0.775), (0.500, 0.885), (0.550, 0.775), (0.500, 0.748)], s) },
        { (s: CGSize) -> Path in Art.poly([(0.420, 0.660), (0.580, 0.660), (0.618, 0.748), (0.382, 0.748)], s) },
        { (s: CGSize) -> Path in Art.poly([(0.425, 0.480), (0.270, 0.690), (0.270, 0.748), (0.430, 0.672)], s) },
        { (s: CGSize) -> Path in Art.poly([(0.575, 0.480), (0.730, 0.690), (0.730, 0.748), (0.570, 0.672)], s) },
        { (s: CGSize) -> Path in
            Art.blob([(0.500, 0.200), (0.575, 0.300), (0.600, 0.500), (0.585, 0.660),
                      (0.500, 0.700), (0.415, 0.660), (0.400, 0.500), (0.425, 0.300)], s) },
        { (s: CGSize) -> Path in Art.box(0.415, 0.545, 0.585, 0.600, s, r: 0.010) },
        { (s: CGSize) -> Path in Art.blob([(0.500, 0.070), (0.588, 0.285), (0.412, 0.285)], s, smooth: 0.6) },
        { (s: CGSize) -> Path in Art.oval(0.500, 0.400, 0.100, 0.100, s) },
        { (s: CGSize) -> Path in Art.oval(0.500, 0.400, 0.068, 0.068, s) },
    ])

    // Fish tank scene, 27 regions.
    static let fishTank = ColoringPage(id: "tank", name: "Fish tank", shapes: [
        { (s: CGSize) -> Path in Art.box(0.04, 0.08, 0.96, 0.94, s, r: 0.06) },
        { (s: CGSize) -> Path in Art.stem(0.10, 0.86, 0.085, 0.560, s, bend: 0.05, width: 0.022, taper: 0.5) },
        { (s: CGSize) -> Path in Art.stem(0.16, 0.86, 0.180, 0.620, s, bend: -0.05, width: 0.020, taper: 0.5) },
        { (s: CGSize) -> Path in Art.stem(0.90, 0.86, 0.905, 0.500, s, bend: 0.05, width: 0.024, taper: 0.5) },
        { (s: CGSize) -> Path in
            var path = Path()
            path.move(to: Art.p(0.05, 0.835, s))
            path.addQuadCurve(to: Art.p(0.50, 0.790, s), control: Art.p(0.26, 0.760, s))
            path.addQuadCurve(to: Art.p(0.95, 0.825, s), control: Art.p(0.74, 0.750, s))
            path.addLine(to: Art.p(0.95, 0.884, s))
            path.addQuadCurve(to: Art.p(0.892, 0.938, s), control: Art.p(0.944, 0.932, s))
            path.addLine(to: Art.p(0.108, 0.938, s))
            path.addQuadCurve(to: Art.p(0.05, 0.884, s), control: Art.p(0.056, 0.932, s))
            path.closeSubpath()
            return path },
        { (s: CGSize) -> Path in Art.box(0.600, 0.610, 0.870, 0.820, s, r: 0.020) },
        { (s: CGSize) -> Path in Art.box(0.588, 0.500, 0.665, 0.625, s, r: 0.014) },
        { (s: CGSize) -> Path in Art.box(0.805, 0.500, 0.882, 0.625, s, r: 0.014) },
        { (s: CGSize) -> Path in Art.box(0.688, 0.455, 0.782, 0.620, s, r: 0.014) },
        { (s: CGSize) -> Path in Art.poly([(0.575, 0.500), (0.678, 0.500), (0.627, 0.430)], s) },
        { (s: CGSize) -> Path in Art.poly([(0.792, 0.500), (0.895, 0.500), (0.844, 0.430)], s) },
        { (s: CGSize) -> Path in Art.poly([(0.675, 0.455), (0.795, 0.455), (0.735, 0.372)], s) },
        { (s: CGSize) -> Path in Art.box(0.700, 0.690, 0.770, 0.820, s, r: 0.035) },
        { (s: CGSize) -> Path in Art.star(0.205, 0.862, 0.058, s, points: 5, inner: 0.45, rotation: -.pi / 2) },
        { (s: CGSize) -> Path in
            Art.blob([(0.430, 0.895), (0.395, 0.855), (0.440, 0.828), (0.487, 0.855)], s) },
        { (s: CGSize) -> Path in Art.poly([(0.262, 0.442), (0.150, 0.340), (0.172, 0.442), (0.150, 0.552)], s) },
        { (s: CGSize) -> Path in
            Art.blob([(0.260, 0.420), (0.340, 0.340), (0.460, 0.330), (0.552, 0.400),
                      (0.570, 0.462), (0.470, 0.532), (0.340, 0.522), (0.250, 0.470)], s) },
        { (s: CGSize) -> Path in Art.blob([(0.340, 0.345), (0.400, 0.248), (0.492, 0.335)], s, smooth: 0.7) },
        { (s: CGSize) -> Path in Art.blob([(0.338, 0.516), (0.382, 0.602), (0.452, 0.522)], s, smooth: 0.7) },
        { (s: CGSize) -> Path in Art.poly([(0.375, 0.338), (0.432, 0.336), (0.415, 0.528), (0.358, 0.520)], s) },
        { (s: CGSize) -> Path in Art.oval(0.492, 0.405, 0.026, 0.028, s) },
        { (s: CGSize) -> Path in Art.poly([(0.688, 0.262), (0.615, 0.212), (0.636, 0.262), (0.615, 0.312)], s) },
        { (s: CGSize) -> Path in Art.oval(0.762, 0.262, 0.080, 0.052, s) },
        { (s: CGSize) -> Path in Art.oval(0.545, 0.222, 0.028, 0.028, s) },
        { (s: CGSize) -> Path in Art.oval(0.588, 0.152, 0.021, 0.021, s) },
        { (s: CGSize) -> Path in Art.oval(0.542, 0.104, 0.015, 0.015, s) },
        { (s: CGSize) -> Path in Art.oval(0.478, 0.268, 0.018, 0.018, s) },
    ])

    // Flower garden with a butterfly, 30 regions.
    static let garden = ColoringPage(id: "garden", name: "Garden", shapes: [
        { (s: CGSize) -> Path in Art.ground(0.78, s, dip: 0.03) },
        { (s: CGSize) -> Path in Art.star(0.84, 0.16, 0.150, s, points: 12, inner: 0.63) },
        { (s: CGSize) -> Path in Art.oval(0.84, 0.16, 0.092, 0.092, s) },
        { (s: CGSize) -> Path in
            Art.blob([(0.060, 0.155), (0.115, 0.072), (0.215, 0.068), (0.292, 0.135),
                      (0.245, 0.202), (0.105, 0.212)], s) },
        { (s: CGSize) -> Path in Art.stem(0.52, 0.880, 0.52, 0.400, s, bend: 0.025, width: 0.018) },
        { (s: CGSize) -> Path in
            Art.blob([(0.510, 0.660), (0.420, 0.605), (0.330, 0.650), (0.420, 0.712)], s) },
        { (s: CGSize) -> Path in Art.petal(0.52, 0.34, s, angle: -.pi / 2, len: 0.150, wid: 0.065) },
        { (s: CGSize) -> Path in Art.petal(0.52, 0.34, s, angle: -.pi / 2 + .pi * 2 / 5, len: 0.150, wid: 0.065) },
        { (s: CGSize) -> Path in Art.petal(0.52, 0.34, s, angle: -.pi / 2 + .pi * 4 / 5, len: 0.150, wid: 0.065) },
        { (s: CGSize) -> Path in Art.petal(0.52, 0.34, s, angle: -.pi / 2 + .pi * 6 / 5, len: 0.150, wid: 0.065) },
        { (s: CGSize) -> Path in Art.petal(0.52, 0.34, s, angle: -.pi / 2 + .pi * 8 / 5, len: 0.150, wid: 0.065) },
        { (s: CGSize) -> Path in Art.oval(0.52, 0.34, 0.058, 0.058, s) },
        { (s: CGSize) -> Path in Art.stem(0.155, 0.880, 0.130, 0.600, s, bend: -0.035, width: 0.015) },
        { (s: CGSize) -> Path in
            Art.blob([(0.145, 0.735), (0.225, 0.690), (0.300, 0.730), (0.220, 0.782)], s) },
        { (s: CGSize) -> Path in Art.petal(0.13, 0.575, s, angle: -.pi / 2, len: 0.105, wid: 0.050) },
        { (s: CGSize) -> Path in Art.petal(0.13, 0.575, s, angle: 0, len: 0.105, wid: 0.050) },
        { (s: CGSize) -> Path in Art.petal(0.13, 0.575, s, angle: .pi / 2, len: 0.105, wid: 0.050) },
        { (s: CGSize) -> Path in Art.petal(0.13, 0.575, s, angle: .pi, len: 0.105, wid: 0.050) },
        { (s: CGSize) -> Path in Art.oval(0.13, 0.575, 0.045, 0.045, s) },
        { (s: CGSize) -> Path in Art.stem(0.75, 0.880, 0.75, 0.620, s, bend: 0.02, width: 0.016) },
        { (s: CGSize) -> Path in
            Art.blob([(0.740, 0.780), (0.660, 0.720), (0.590, 0.762), (0.675, 0.822)], s) },
        { (s: CGSize) -> Path in
            Art.blob([(0.762, 0.752), (0.840, 0.690), (0.905, 0.732), (0.822, 0.792)], s) },
        { (s: CGSize) -> Path in
            Art.blob([(0.700, 0.462), (0.722, 0.548), (0.682, 0.622), (0.630, 0.552), (0.652, 0.470)], s) },
        { (s: CGSize) -> Path in
            Art.blob([(0.800, 0.462), (0.850, 0.470), (0.870, 0.552), (0.818, 0.622), (0.778, 0.548)], s) },
        { (s: CGSize) -> Path in
            Art.blob([(0.750, 0.435), (0.812, 0.500), (0.802, 0.622), (0.698, 0.622), (0.688, 0.500)], s) },
        { (s: CGSize) -> Path in
            Art.blob([(0.225, 0.295), (0.175, 0.235), (0.128, 0.262), (0.142, 0.318), (0.200, 0.320)], s) },
        { (s: CGSize) -> Path in
            Art.blob([(0.235, 0.295), (0.285, 0.235), (0.332, 0.262), (0.318, 0.318), (0.260, 0.320)], s) },
        { (s: CGSize) -> Path in
            Art.blob([(0.225, 0.330), (0.178, 0.380), (0.145, 0.356), (0.168, 0.330)], s) },
        { (s: CGSize) -> Path in
            Art.blob([(0.235, 0.330), (0.282, 0.380), (0.315, 0.356), (0.292, 0.330)], s) },
        { (s: CGSize) -> Path in Art.oval(0.230, 0.318, 0.019, 0.054, s) },
    ])
}

// MARK: - Fills that survive leaving the screen

final class ColoringStore: ObservableObject {
    static let shared = ColoringStore()

    struct Step {
        let region: Int
        let previous: Color?
    }

    @Published var fills: [String: [Int: Color]] = [:]
    @Published var steps: [String: [Step]] = [:]
    @Published var finished: Set<String> = []

    private init() {}
}

// MARK: - Screen

struct ColoringView: View {
    @StateObject private var store = ColoringStore.shared
    @State private var pageIndex = 0
    @State private var crayonIndex: Int? = 0        // nil means rainbow
    @State private var bounceRegion: Int?
    @State private var showConfetti = false
    @State private var confettiToken = 0

    static let crayons: [Color] = [
        Palette.red, Palette.orange, Palette.yellow, Palette.green,
        Palette.teal, Palette.blue, Palette.indigo, Palette.purple,
        Palette.pink, Palette.brown,
        Color(red: 0.55, green: 0.78, blue: 0.92),
        Color(red: 0.95, green: 0.80, blue: 0.64),
    ]

    private static let cheers = [
        "Wow, you finished the whole picture",
        "Every single part is colored in",
        "That looks beautiful, well done",
        "You are a real artist",
        "All done, what lovely colors",
    ]

    private var page: ColoringPage { ColoringPage.all[pageIndex] }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 10) {
                TopBar(title: "Coloring")
                pagePicker
                canvas
                crayonBox
            }

            if showConfetti {
                ConfettiBurst(count: 32, spread: 210, duration: 1.8)
                    .id(confettiToken)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: Page picker

    private var pagePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(ColoringPage.all.enumerated()), id: \.element.id) { index, item in
                    Button {
                        Sfx.tap()
                        Sfx.bump(.light)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            pageIndex = index
                        }
                    } label: {
                        PageThumb(page: item, selected: index == pageIndex)
                    }
                    .buttonStyle(BouncyButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
        }
        .frame(height: 92)
    }

    // MARK: Canvas

    private var canvas: some View {
        GeometryReader { geo in
            let side = max(1, min(geo.size.width, geo.size.height))
            let box = CGSize(width: side, height: side)
            ZStack {
                ForEach(page.regions) { region in
                    RegionView(
                        path: region.build(box),
                        canvas: box,
                        color: store.fills[page.id]?[region.id],
                        bouncing: bounceRegion == region.id
                    ) {
                        paint(region)
                    }
                }
            }
            .id(page.id)
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(14)
        .card(cornerRadius: 28)
        .padding(.horizontal, 18)
    }

    // MARK: Crayons

    private var crayonBox: some View {
        VStack(spacing: 10) {
            HStack(spacing: 11) {
                ForEach(0..<6, id: \.self) { swatch($0) }
            }
            HStack(spacing: 11) {
                ForEach(6..<12, id: \.self) { swatch($0) }
            }
            HStack(spacing: 16) {
                rainbowButton
                toolButton("arrow.uturn.backward", label: "Undo", action: undo)
                toolButton("trash.fill", label: "Start over", action: clearPage)
            }
            .padding(.top, 2)
        }
        .padding(.bottom, 14)
    }

    private func swatch(_ index: Int) -> some View {
        let color = Self.crayons[index]
        let chosen = crayonIndex == index
        return Button {
            Sfx.tap()
            Sfx.bump(.light)
            crayonIndex = index
        } label: {
            Circle()
                .fill(color)
                .frame(width: 42, height: 42)
                .overlay(Circle().stroke(Color.white, lineWidth: chosen ? 4 : 0))
                .overlay(Circle().stroke(Palette.ink.opacity(chosen ? 0.35 : 0.12), lineWidth: 2))
                .scaleEffect(chosen ? 1.14 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: chosen)
                .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
                .frame(width: 50, height: 50)
                .contentShape(Rectangle())
        }
        .buttonStyle(BouncyButtonStyle())
    }

    private var rainbowButton: some View {
        let chosen = crayonIndex == nil
        return Button {
            Sfx.tap()
            Sfx.bump(.light)
            crayonIndex = nil
        } label: {
            ZStack {
                Circle()
                    .fill(AngularGradient(colors: Self.crayons + [Self.crayons[0]], center: .center))
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 2)
            }
            .frame(width: 48, height: 48)
            .overlay(Circle().stroke(Color.white, lineWidth: chosen ? 4 : 0))
            .overlay(Circle().stroke(Palette.ink.opacity(chosen ? 0.35 : 0.12), lineWidth: 2))
            .scaleEffect(chosen ? 1.12 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: chosen)
            .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
        }
        .buttonStyle(BouncyButtonStyle())
        .accessibilityLabel("Rainbow color")
    }

    private func toolButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Palette.inkSoft)
                .frame(width: 52, height: 48)
                .card(cornerRadius: 16)
        }
        .buttonStyle(BouncyButtonStyle())
        .accessibilityLabel(label)
    }

    // MARK: Actions

    private func paint(_ region: ColorRegion) {
        let color = crayonIndex.map { Self.crayons[$0] }
            ?? (Self.crayons.randomElement() ?? Palette.pink)
        let key = page.id
        let previous = store.fills[key]?[region.id]

        store.steps[key, default: []].append(ColoringStore.Step(region: region.id, previous: previous))
        store.fills[key, default: [:]][region.id] = color

        Sfx.pop()
        Sfx.bump(.light)

        bounceRegion = region.id
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.24))
            if bounceRegion == region.id { bounceRegion = nil }
        }

        if (store.fills[key]?.count ?? 0) == page.regions.count, !store.finished.contains(key) {
            store.finished.insert(key)
            confettiToken += 1
            showConfetti = true
            Speaker.shared.cheer(Self.cheers.randomElement() ?? "You did it")
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.2))
                showConfetti = false
            }
        }
    }

    private func undo() {
        let key = page.id
        guard var stack = store.steps[key], let step = stack.popLast() else { return }
        store.steps[key] = stack
        Sfx.tap()
        Sfx.bump(.light)
        store.finished.remove(key)
        withAnimation(.easeOut(duration: 0.2)) {
            if let previous = step.previous {
                store.fills[key, default: [:]][step.region] = previous
            } else {
                store.fills[key]?.removeValue(forKey: step.region)
            }
        }
    }

    private func clearPage() {
        let key = page.id
        Sfx.pop()
        Sfx.bump()
        store.steps[key] = []
        store.finished.remove(key)
        withAnimation(.easeOut(duration: 0.25)) {
            store.fills[key] = [:]
        }
    }
}

// MARK: - One fillable region

private struct RegionView: View {
    let path: Path
    let canvas: CGSize
    let color: Color?
    let bouncing: Bool
    let onTap: () -> Void

    var body: some View {
        let bounds = path.boundingRect
        let anchor = UnitPoint(
            x: canvas.width > 0 ? bounds.midX / canvas.width : 0.5,
            y: canvas.height > 0 ? bounds.midY / canvas.height : 0.5
        )
        return ZStack {
            path.fill(color ?? Color.white)
            path.stroke(
                Palette.ink.opacity(0.75),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )
        }
        .contentShape(path)
        .onTapGesture(perform: onTap)
        .scaleEffect(bouncing ? 1.07 : 1, anchor: anchor)
        .animation(.spring(response: 0.24, dampingFraction: 0.45), value: bouncing)
        .animation(.easeOut(duration: 0.18), value: color)
    }
}

// MARK: - Small unfilled preview of a page

private struct PageThumb: View {
    let page: ColoringPage
    let selected: Bool

    var body: some View {
        Canvas { context, size in
            for region in page.regions {
                let path = region.build(size)
                context.fill(path, with: .color(.white))
                context.stroke(path, with: .color(Palette.ink.opacity(0.75)), lineWidth: 0.9)
            }
        }
        .frame(width: 58, height: 58)
        .padding(6)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(selected ? Palette.pink : Palette.ink.opacity(0.08), lineWidth: selected ? 3.5 : 1.5)
        )
        .shadow(color: .black.opacity(0.07), radius: 6, y: 3)
        .scaleEffect(selected ? 1.06 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
    }
}
