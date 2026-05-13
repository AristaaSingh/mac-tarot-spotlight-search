import SwiftUI

struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
    var speed: Double
    var angle: Double
    var color: Color
}

struct SparkleView: View {
    @State private var particles: [Particle] = []
    @State private var phase: Double = 0
    let colors: [Color] = [.white, Color(red: 1, green: 0.9, blue: 0.5), Color(red: 0.8, green: 0.7, blue: 1)]

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for particle in particles {
                    let px = particle.x + cos(particle.angle + t * particle.speed) * 30
                    let py = particle.y + sin(particle.angle + t * particle.speed) * 30
                    let flicker = (sin(t * particle.speed * 3 + particle.angle) + 1) / 2
                    let op = particle.opacity * flicker
                    let rect = CGRect(x: px - particle.size / 2, y: py - particle.size / 2,
                                      width: particle.size, height: particle.size)
                    context.opacity = op
                    context.fill(starPath(in: rect), with: .color(particle.color))
                }
            }
        }
        .onAppear { spawnParticles() }
    }

    private func spawnParticles() {
        particles = (0..<40).map { _ in
            Particle(
                x: CGFloat.random(in: 0...400),
                y: CGFloat.random(in: 0...600),
                size: CGFloat.random(in: 4...12),
                opacity: Double.random(in: 0.4...1.0),
                speed: Double.random(in: 0.3...1.2),
                angle: Double.random(in: 0...(2 * .pi)),
                color: colors.randomElement()!
            )
        }
    }

    private func starPath(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX, cy = rect.midY
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.4
        let points = 4
        for i in 0..<points * 2 {
            let r = i.isMultiple(of: 2) ? outer : inner
            let angle = Double(i) * .pi / Double(points) - .pi / 2
            let px = cx + r * cos(angle)
            let py = cy + r * sin(angle)
            i == 0 ? path.move(to: CGPoint(x: px, y: py)) : path.addLine(to: CGPoint(x: px, y: py))
        }
        path.closeSubpath()
        return path
    }
}
