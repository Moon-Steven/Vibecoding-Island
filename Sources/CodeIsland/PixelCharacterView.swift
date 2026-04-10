import SwiftUI
import CodeIslandCore

/// Clawd — Claude mascot, adapted from clawd-on-desk SVG pixel art.
/// Renders SVG rects proportionally via Canvas + TimelineView animations.
/// Tool category — drives animation style, color, and floating keywords
private enum ToolCategory {
    case terminal, fileRead, fileWrite, web, thinking

    init(tool: String?) {
        guard let t = tool?.lowercased() else { self = .thinking; return }
        switch t {
        case "bash":                              self = .terminal
        case "read", "grep", "glob", "ls":        self = .fileRead
        case "edit", "write", "notebookedit":     self = .fileWrite
        case "webfetch", "websearch":             self = .web
        default:
            if t.contains("bash") || t.contains("shell") { self = .terminal }
            else if t.contains("read") || t.contains("grep") || t.contains("glob") { self = .fileRead }
            else if t.contains("edit") || t.contains("write") { self = .fileWrite }
            else if t.contains("web") || t.contains("fetch") { self = .web }
            else { self = .thinking }
        }
    }

    /// Accent color per tool type
    var color: Color {
        switch self {
        case .terminal:  return Color(red: 0.3, green: 1.0, blue: 0.5)   // neon green
        case .fileRead:  return Color(red: 0.4, green: 0.75, blue: 1.0)  // sky blue
        case .fileWrite: return Color(red: 1.0, green: 0.65, blue: 0.2)  // amber
        case .web:       return Color(red: 0.7, green: 0.45, blue: 1.0)  // violet
        case .thinking:  return Color(red: 0.75, green: 0.75, blue: 0.85) // silver
        }
    }

    /// Rotating keywords — short, punchy, one-word
    var words: [String] {
        switch self {
        case .terminal:  return ["exec", "run", "brew", "pipe", "sudo", "bash"]
        case .fileRead:  return ["scan", "grep", "find", "peek", "read", "seek"]
        case .fileWrite: return ["edit", "code", "fix", "craft", "type", "save"]
        case .web:       return ["fetch", "ping", "curl", "load", "sync", "pull"]
        case .thinking:  return ["hmm", "idea", "plan", "think", "wait", "..."]
        }
    }
}

struct ClawdView: View {
    let status: AgentStatus
    var size: CGFloat = 27
    var currentTool: String? = nil
    @State private var alive = false
    @Environment(\.mascotSpeed) private var speed

    // Colors from clawd-on-desk
    private static let bodyC  = Color(red: 0.871, green: 0.533, blue: 0.427) // #DE886D
    private static let eyeC   = Color.black
    private static let alertC = Color(red: 1.0, green: 0.24, blue: 0.0)     // #FF3D00
    private static let kbBase = Color(red: 0.38, green: 0.44, blue: 0.50)  // lighter base
    private static let kbKey  = Color(red: 0.60, green: 0.66, blue: 0.72)  // visible keys
    private static let kbHi   = Color.white                                 // bright flash

    var body: some View {
        ZStack {
            switch status {
            case .idle:                 sleepScene
            case .processing, .running: workScene
            case .waitingApproval, .waitingQuestion: alertScene
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .onAppear { alive = true }
        .onChange(of: status) {
            alive = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { alive = true }
        }
    }

    // ── Coordinate helper: maps SVG units to view points ──
    private struct V {
        let ox: CGFloat, oy: CGFloat, s: CGFloat
        let y0: CGFloat

        init(_ sz: CGSize, svgW: CGFloat = 15, svgH: CGFloat = 10, svgY0: CGFloat = 6) {
            s = min(sz.width / svgW, sz.height / svgH)
            ox = (sz.width - svgW * s) / 2
            oy = (sz.height - svgH * s) / 2
            y0 = svgY0
        }
        func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, dy: CGFloat = 0) -> CGRect {
            CGRect(x: ox + x * s, y: oy + (y - y0 + dy) * s, width: w * s, height: h * s)
        }
    }

    // ── Rotated arm: returns polygon path for a rect rotated around pivot ──
    private func armPath(_ v: V, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                         pivotX: CGFloat, pivotY: CGFloat, angle: CGFloat, dy: CGFloat) -> Path {
        let a = angle * .pi / 180
        let ca = cos(a), sa = sin(a)
        let corners: [(CGFloat, CGFloat)] = [
            (x - pivotX, y - pivotY),
            (x + w - pivotX, y - pivotY),
            (x + w - pivotX, y + h - pivotY),
            (x - pivotX, y + h - pivotY),
        ]
        var path = Path()
        for (i, (cx, cy)) in corners.enumerated() {
            let rx = cx * ca - cy * sa + pivotX
            let ry = cx * sa + cy * ca + pivotY
            let pt = CGPoint(x: v.ox + rx * v.s, y: v.oy + (ry - v.y0 + dy) * v.s)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // Draw sleeping character (sploot pose from clawd-sleeping.svg)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    private func drawSleeping(_ ctx: GraphicsContext, v: V, breathe: CGFloat) {
        // Shadow (wider for sploot, pulses with breath)
        let shadowScale: CGFloat = 1.0 + breathe * 0.03
        ctx.fill(Path(v.r(-1, 15, 17 * shadowScale, 1)),
                 with: .color(.black.opacity(0.35 + breathe * 0.08)))

        // Legs pointing up from behind (wider 1×2 blocks for visibility)
        for x: CGFloat in [3, 5, 9, 11] {
            ctx.fill(Path(v.r(x, 8.5, 1, 1.5)), with: .color(Self.bodyC))
        }

        // Flattened torso — big puff on inhale (25% from SVG)
        let puff = max(0, breathe) * 0.25
        let torsoH: CGFloat = 5 * (1.0 + puff)
        let torsoY: CGFloat = 15 - torsoH
        let torsoW: CGFloat = 13 * (1.0 + breathe * 0.015) // slight width pulse
        let torsoX: CGFloat = 1 - (torsoW - 13) / 2
        ctx.fill(Path(v.r(torsoX, torsoY, torsoW, torsoH)), with: .color(Self.bodyC))

        // Arms spread flat on the ground
        ctx.fill(Path(v.r(-1, 13, 2, 2)), with: .color(Self.bodyC))
        ctx.fill(Path(v.r(14, 13, 2, 2)), with: .color(Self.bodyC))

        // Shut eyes (thicker for visibility, move with puff)
        let eyeY: CGFloat = 12.2 - puff * 2.5
        ctx.fill(Path(v.r(3, eyeY, 2.5, 1.0)), with: .color(Self.eyeC))
        ctx.fill(Path(v.r(9.5, eyeY, 2.5, 1.0)), with: .color(Self.eyeC))
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // SLEEP — sploot pose, breathing, floating z's
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    private var sleepScene: some View {
        ZStack {
            // Character body (behind)
            TimelineView(.periodic(from: .now, by: 0.06)) { ctx in
                sleepCanvas(t: ctx.date.timeIntervalSinceReferenceDate * speed)
            }

            // Z's — continuous float-up loop, staggered timing
            TimelineView(.periodic(from: .now, by: 0.05)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate * speed
                floatingZs(t: t)
            }
        }
    }

    private func floatingZs(t: Double) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                floatingZ(t: t, index: i)
            }
        }
    }

    private func floatingZ(t: Double, index: Int) -> some View {
        let ci = Double(index)
        let cycle = 2.8 + ci * 0.3
        let delay = ci * 0.9
        let phase = ((t - delay).truncatingRemainder(dividingBy: cycle)) / cycle
        let p = max(0, phase)
        let fontSize = max(6, size * CGFloat(0.18 + p * 0.10))
        let baseOpacity = 0.7 - ci * 0.1
        let opacity = p < 0.8 ? baseOpacity : (1.0 - p) * 3.5 * baseOpacity
        let xOff = size * CGFloat(0.08 + ci * 0.06 + sin(p * .pi * 2) * 0.03)
        let yOff = -size * CGFloat(0.15 + p * 0.38)
        return Text("z")
            .font(.system(size: fontSize, weight: .black, design: .monospaced))
            .foregroundStyle(.white.opacity(opacity))
            .offset(x: xOff, y: yOff)
    }

    private func sleepCanvas(t: Double) -> some View {
        let phase = t.truncatingRemainder(dividingBy: 4.5) / 4.5
        let breathe: CGFloat = phase < 0.4 ? sin(phase / 0.4 * .pi) : 0

        return Canvas { c, sz in
            let v = V(sz, svgW: 17, svgH: 7, svgY0: 9)
            drawSleeping(c, v: v, breathe: breathe)
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // WORK — typing character + tool-specific ambient effects + rotating word
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    private var workScene: some View {
        TimelineView(.periodic(from: .now, by: 0.03)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate * speed
            workCanvas(t: t, cat: ToolCategory(tool: currentTool))
        }
    }

    private func workCanvas(t: Double, cat: ToolCategory) -> some View {
        let bounce = sin(t * 2 * .pi / 0.35) * 1.2
        let breathe = sin(t * 2 * .pi / 3.2)
        let armLRaw = sin(t * 2 * .pi / 0.15)
        let armL = armLRaw * 22.5 - 32.5
        let armRRaw = sin(t * 2 * .pi / 0.12)
        let armR = armRRaw * 22.5 + 32.5
        let leftHit = armLRaw > 0.3
        let rightHit = armRRaw > 0.3
        let leftKeyCol = Int(t / 0.15) % 3
        let rightKeyCol = 3 + Int(t / 0.12) % 3
        let scanPhase = t.truncatingRemainder(dividingBy: 10.0)
        let eyeScale: CGFloat = (scanPhase > 5.7 && scanPhase < 6.9) ? 1.0 : 0.5
        let eyeDY: CGFloat = eyeScale < 0.8 ? 1.0 : -0.5
        let blinkPhase = t.truncatingRemainder(dividingBy: 3.5)
        let finalEyeScale = (blinkPhase > 1.4 && blinkPhase < 1.55) ? 0.1 : eyeScale
        let accent = cat.color

        return Canvas { c, sz in
            let v = V(sz, svgW: 16, svgH: 11, svgY0: 5.5)
            let dy = bounce

            // ── Tool-specific ambient effect (behind character) ──
            switch cat {
            case .terminal:
                // Matrix rain — falling green dots
                for i in 0..<6 {
                    let seed = Double(i) * 3.7
                    let col = CGFloat(1 + i * 2 + Int(sin(seed) * 1.5))
                    let fallPhase = (t * 4.0 + seed).truncatingRemainder(dividingBy: 3.0) / 3.0
                    let fy = CGFloat(4 + fallPhase * 12)
                    let fOp = fallPhase < 0.8 ? 0.6 : (1.0 - fallPhase) * 3.0
                    c.fill(Path(v.r(col, fy, 0.6, 0.6)),
                           with: .color(accent.opacity(fOp * 0.5)))
                    // Trail
                    if fallPhase > 0.1 {
                        c.fill(Path(v.r(col, fy - 1.2, 0.6, 0.6)),
                               with: .color(accent.opacity(fOp * 0.2)))
                    }
                }

            case .fileRead:
                // Scanning beam — horizontal sweep
                let sweepPhase = (t * 1.5).truncatingRemainder(dividingBy: 2.0)
                let sweepY = CGFloat(6 + sweepPhase * 4.5)
                c.fill(Path(v.r(0, sweepY, 15, 0.4)),
                       with: .color(accent.opacity(0.25)))
                c.fill(Path(v.r(0, sweepY - 0.2, 15, 0.8)),
                       with: .color(accent.opacity(0.08)))

            case .fileWrite:
                // Warm sparks rising from keyboard
                for i in 0..<4 {
                    let seed = Double(i) * 2.3 + t * 3.0
                    let sparkPhase = seed.truncatingRemainder(dividingBy: 2.0) / 2.0
                    let sx = CGFloat(3 + sin(seed * 0.7) * 5)
                    let sy = CGFloat(12.0 - sparkPhase * 8.0)
                    let sOp = sparkPhase < 0.6 ? 0.8 : (1.0 - sparkPhase) * 2.0
                    let sparkSize: CGFloat = 0.5 + CGFloat(sin(seed * 2.0)) * 0.3
                    c.fill(Path(v.r(sx, sy, sparkSize, sparkSize)),
                           with: .color(accent.opacity(max(0, sOp) * 0.7)))
                }

            case .web:
                // Pulsing signal rings from character center
                for i in 0..<3 {
                    let ringPhase = (t * 1.2 + Double(i) * 0.8).truncatingRemainder(dividingBy: 2.4) / 2.4
                    let ringR = CGFloat(2 + ringPhase * 6)
                    let ringOp = max(0, 0.4 - ringPhase * 0.5)
                    let cx = v.ox + 7.5 * v.s
                    let cy = v.oy + (9 - v.y0 + dy) * v.s
                    c.stroke(Path(ellipseIn: CGRect(x: cx - ringR * v.s, y: cy - ringR * v.s,
                                                     width: ringR * 2 * v.s, height: ringR * 2 * v.s)),
                             with: .color(accent.opacity(ringOp)), lineWidth: 0.4)
                }

            case .thinking:
                // Soft orbiting dots
                for i in 0..<3 {
                    let angle = t * 1.5 + Double(i) * 2.094
                    let orbR: CGFloat = 4
                    let ox = CGFloat(7.5 + cos(angle) * Double(orbR))
                    let oy = CGFloat(8 + sin(angle) * Double(orbR) * 0.5 + dy)
                    let dotOp = 0.3 + sin(t * 2.0 + Double(i)) * 0.2
                    c.fill(Path(v.r(ox, oy, 0.8, 0.8)),
                           with: .color(accent.opacity(dotOp)))
                }
            }

            // ── Base character ──

            // Shadow
            let shadowW: CGFloat = 9 - abs(dy) * 0.3
            c.fill(Path(v.r(3 + (9 - shadowW) / 2, 15, shadowW, 1)),
                   with: .color(.black.opacity(max(0.1, 0.4 - abs(dy) * 0.03))))

            // Legs
            for x: CGFloat in [3, 5, 9, 11] {
                c.fill(Path(v.r(x, 13, 1, 2)), with: .color(Self.bodyC))
            }

            // Torso
            let bScale = 1.0 + breathe * 0.015
            let torsoW = 11 * bScale
            c.fill(Path(v.r(2 - (torsoW - 11) / 2, 6, torsoW, 7, dy: dy)),
                   with: .color(Self.bodyC))

            // Eyes
            let eyeH: CGFloat = 2 * finalEyeScale
            let eyeY: CGFloat = 8 + (2 - eyeH) / 2 + eyeDY
            c.fill(Path(v.r(4, eyeY, 1, eyeH, dy: dy)), with: .color(Self.eyeC))
            c.fill(Path(v.r(10, eyeY, 1, eyeH, dy: dy)), with: .color(Self.eyeC))

            // Keyboard
            c.fill(Path(v.r(-0.5, 11.8, 16, 3.5)), with: .color(Self.kbBase))
            for row in 0..<3 {
                let ky = 12.2 + CGFloat(row) * 1.0
                for col in 0..<6 {
                    let kx = 0.3 + CGFloat(col) * 2.5
                    let w: CGFloat = (col == 2 && row == 1) ? 4.5 : 2.0
                    c.fill(Path(v.r(kx, ky, w, 0.7)), with: .color(Self.kbKey))
                }
            }
            // Key flashes — colored by tool type
            if leftHit {
                let row = leftKeyCol % 3
                let kx = 0.3 + CGFloat(leftKeyCol) * 2.5
                let ky = 12.2 + CGFloat(row) * 1.0
                c.fill(Path(v.r(kx, ky, 2.0, 0.7)), with: .color(accent.opacity(0.9)))
            }
            if rightHit {
                let row = (rightKeyCol - 3) % 3
                let kx = 0.3 + CGFloat(rightKeyCol) * 2.5
                let ky = 12.2 + CGFloat(row) * 1.0
                c.fill(Path(v.r(kx, ky, 2.0, 0.7)), with: .color(accent.opacity(0.9)))
            }

            // Arms
            c.fill(armPath(v, x: 0, y: 9, w: 2, h: 2, pivotX: 2, pivotY: 10,
                           angle: armL, dy: dy), with: .color(Self.bodyC))
            c.fill(armPath(v, x: 13, y: 9, w: 2, h: 2, pivotX: 13, pivotY: 10,
                           angle: armR, dy: dy), with: .color(Self.bodyC))
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // ALERT — 3.5s cycle: startle → decaying jumps → rest
    // Matches clawd-notification.svg keyframes
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    private var alertScene: some View {
        ZStack {
            Circle()
                .fill(Self.alertC.opacity(alive ? 0.12 : 0))
                .frame(width: size * 0.8)
                .blur(radius: size * 0.05)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: alive)

            TimelineView(.periodic(from: .now, by: 0.03)) { ctx in
                alertCanvas(t: ctx.date.timeIntervalSinceReferenceDate * speed)
            }
        }
    }

    // Interpolate between keyframes: [(pct, value)]
    private func lerp(_ keyframes: [(CGFloat, CGFloat)], at pct: CGFloat) -> CGFloat {
        guard let first = keyframes.first else { return 0 }
        if pct <= first.0 { return first.1 }
        for i in 1..<keyframes.count {
            if pct <= keyframes[i].0 {
                let t = (pct - keyframes[i-1].0) / (keyframes[i].0 - keyframes[i-1].0)
                return keyframes[i-1].1 + (keyframes[i].1 - keyframes[i-1].1) * t
            }
        }
        return keyframes.last?.1 ?? 0
    }

    private func alertCanvas(t: Double) -> some View {
        let cycle = t.truncatingRemainder(dividingBy: 3.5)
        let pct = cycle / 3.5

        // Body jump — smooth interpolation from SVG keyframes
        let jumpY = lerp([
            (0, 0), (0.03, 0), (0.10, -1), (0.15, 1.5),
            (0.175, -10), (0.20, -10), (0.25, 1.5),
            (0.275, -8), (0.30, -8), (0.35, 1.2),
            (0.375, -5), (0.40, -5), (0.45, 1.0),
            (0.475, -3), (0.50, -3), (0.55, 0.5),
            (0.62, 0), (1.0, 0),
        ], at: pct)

        // Squash/stretch on landing (exaggerated for visibility)
        let scaleX: CGFloat = jumpY > 0.5 ? 1.0 + jumpY * 0.05 : 1.0  // squash wider
        let scaleY: CGFloat = jumpY > 0.5 ? 1.0 - jumpY * 0.04 : 1.0  // squash shorter

        // Arm waving — smooth interpolation
        let armL = lerp([
            (0, 0), (0.03, 0), (0.10, 25),
            (0.15, 30), (0.20, 155), (0.25, 115),
            (0.30, 140), (0.35, 100), (0.40, 115),
            (0.45, 80), (0.50, 80), (0.55, 40),
            (0.62, 0), (1.0, 0),
        ], at: pct)
        let armR = -lerp([
            (0, 0), (0.03, 0), (0.10, 30),
            (0.15, 30), (0.20, 155), (0.25, 115),
            (0.30, 140), (0.35, 100), (0.40, 115),
            (0.45, 80), (0.50, 80), (0.55, 40),
            (0.62, 0), (1.0, 0),
        ], at: pct)

        // Eye startle: widen + shift gaze on initial startle
        let eyeScale: CGFloat = (pct > 0.03 && pct < 0.15) ? 1.3 : 1.0
        let eyeDY: CGFloat = (pct > 0.03 && pct < 0.15) ? -0.5 : 0

        // ! mark
        let bangOpacity = lerp([
            (0, 0), (0.03, 1), (0.10, 1), (0.55, 1), (0.62, 0), (1.0, 0),
        ], at: pct)
        let bangScale = lerp([
            (0, 0.3), (0.03, 1.3), (0.10, 1.0), (0.55, 1.0), (0.62, 0.6), (1.0, 0.6),
        ], at: pct)

        return Canvas { c, sz in
            // Taller viewport to fit ! mark above head
            let v = V(sz, svgW: 15, svgH: 12, svgY0: 4)

            // Shadow — reacts to jump height
            let shadowW: CGFloat = 9 * (1.0 - abs(min(0, jumpY)) * 0.04)
            let shadowOp = max(0.08, 0.5 - abs(min(0, jumpY)) * 0.04)
            c.fill(Path(v.r(3 + (9 - shadowW) / 2, 15, shadowW, 1)),
                   with: .color(.black.opacity(shadowOp)))

            // Legs
            for x: CGFloat in [3, 5, 9, 11] {
                c.fill(Path(v.r(x, 11, 1, 4)), with: .color(Self.bodyC))
            }

            // Torso with squash/stretch
            let torsoW = 11 * scaleX
            let torsoH = 7 * scaleY
            let torsoX = 2 - (torsoW - 11) / 2
            let torsoY = 6 + (7 - torsoH)  // stretch from bottom
            c.fill(Path(v.r(torsoX, torsoY, torsoW, torsoH, dy: jumpY)),
                   with: .color(Self.bodyC))

            // Eyes (startled = wider)
            let eyeH = 2 * eyeScale
            let eyeYPos = 8 + (2 - eyeH) / 2 + eyeDY
            c.fill(Path(v.r(4, eyeYPos, 1, eyeH, dy: jumpY)), with: .color(Self.eyeC))
            c.fill(Path(v.r(10, eyeYPos, 1, eyeH, dy: jumpY)), with: .color(Self.eyeC))

            // Arms — correct pivot at body connection
            c.fill(armPath(v, x: 0, y: 9, w: 2, h: 2, pivotX: 2, pivotY: 10,
                           angle: armL, dy: jumpY), with: .color(Self.bodyC))
            c.fill(armPath(v, x: 13, y: 9, w: 2, h: 2, pivotX: 13, pivotY: 10,
                           angle: armR, dy: jumpY), with: .color(Self.bodyC))

            // ! mark — positioned above head, dampened movement (doesn't fly off screen)
            if bangOpacity > 0.01 {
                let bw: CGFloat = 2 * bangScale
                let bx: CGFloat = 13
                let by: CGFloat = 4.5 + jumpY * 0.15 // dampened: only 15% of jump
                c.fill(Path(v.r(bx, by, bw, 3.5 * bangScale, dy: 0)),
                       with: .color(Self.alertC.opacity(bangOpacity)))
                c.fill(Path(v.r(bx, by + 4.0 * bangScale, bw, 1.5 * bangScale, dy: 0)),
                       with: .color(Self.alertC.opacity(bangOpacity)))
            }
        }
    }
}
