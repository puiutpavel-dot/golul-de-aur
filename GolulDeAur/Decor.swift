import SwiftUI

// Elemente grafice comune: fundalul cu teren, cartonasele, ecusoanele echipelor.

/// Fundal: gazon in dungi, liniile terenului si o lumina aurie de sus.
struct PitchBackground: View {
    var body: some View {
        ZStack {
            Theme.background

            GeometryReader { geo in
                VStack(spacing: 0) {
                    ForEach(0..<12, id: \.self) { index in
                        Rectangle()
                            .fill(Color.white.opacity(index % 2 == 0 ? 0.03 : 0))
                            .frame(height: geo.size.height / 12)
                    }
                }
            }

            PitchLines()
                .stroke(Color.white.opacity(0.08), lineWidth: 2)

            RadialGradient(colors: [Theme.gold.opacity(0.28), Color.clear],
                           center: .top, startRadius: 0, endRadius: 420)
            RadialGradient(colors: [Theme.correct.opacity(0.22), Color.clear],
                           center: .bottom, startRadius: 0, endRadius: 380)
        }
        .ignoresSafeArea()
    }
}

struct PitchLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let field = rect.insetBy(dx: 14, dy: 14)
        path.addRect(field)

        // Linia de centru si cercul de la mijloc.
        path.move(to: CGPoint(x: field.minX, y: field.midY))
        path.addLine(to: CGPoint(x: field.maxX, y: field.midY))
        let radius = field.width * 0.24
        path.addEllipse(in: CGRect(x: field.midX - radius, y: field.midY - radius,
                                   width: radius * 2, height: radius * 2))
        path.addEllipse(in: CGRect(x: field.midX - 4, y: field.midY - 4, width: 8, height: 8))

        // Careurile mari si mici.
        let bigWidth = field.width * 0.58
        let bigHeight = field.height * 0.14
        let smallWidth = field.width * 0.28
        let smallHeight = field.height * 0.05
        path.addRect(CGRect(x: field.midX - bigWidth / 2, y: field.minY, width: bigWidth, height: bigHeight))
        path.addRect(CGRect(x: field.midX - smallWidth / 2, y: field.minY, width: smallWidth, height: smallHeight))
        path.addRect(CGRect(x: field.midX - bigWidth / 2, y: field.maxY - bigHeight, width: bigWidth, height: bigHeight))
        path.addRect(CGRect(x: field.midX - smallWidth / 2, y: field.maxY - smallHeight, width: smallWidth, height: smallHeight))
        return path
    }
}

/// Cartonas cu fond inchis, luciu si contur auriu.
struct CardStyle: ViewModifier {
    var highlighted = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return content
            .padding(18)
            .background(
                ZStack {
                    shape.fill(Theme.cardBase)
                    shape.fill(LinearGradient(
                        colors: [Color.white.opacity(0.14), Color.white.opacity(0.02)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            )
            .overlay(
                shape.stroke(LinearGradient(
                    colors: [Theme.gold.opacity(highlighted ? 0.95 : 0.5), Theme.gold.opacity(highlighted ? 0.35 : 0.06)],
                    startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: highlighted ? 1.5 : 1)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 6)
    }
}

extension View {
    func card(highlighted: Bool = false) -> some View {
        modifier(CardStyle(highlighted: highlighted))
    }
}

/// Titlu de sectiune cu pictograma aurie.
struct SectionTitle: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Theme.gold)
            Text(text.uppercased())
                .font(.caption.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(Color.white.opacity(0.85))
            Rectangle()
                .fill(LinearGradient(colors: [Theme.gold.opacity(0.6), Color.clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
        }
    }
}

/// Ecuson generat din numele echipei (culoare stabila + initiale).
struct TeamBadge: View {
    let name: String
    var size: CGFloat = 66

    private var initials: String {
        let words = name.split(separator: " ").filter { $0.count > 2 }
        if words.count >= 2 {
            return String(words.prefix(3).compactMap { $0.first }).uppercased()
        }
        return String(name.prefix(3)).uppercased()
    }

    private var hue: Double {
        var hash: UInt32 = 5381
        for scalar in name.unicodeScalars {
            hash = hash &* 33 &+ scalar.value
        }
        return Double(hash % 360) / 360
    }

    var body: some View {
        ZStack {
            Image(systemName: "shield.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(LinearGradient(
                    colors: [Color(hue: hue, saturation: 0.75, brightness: 0.85),
                             Color(hue: hue, saturation: 0.9, brightness: 0.4)],
                    startPoint: .top, endPoint: .bottom))
            Image(systemName: "shield")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.white.opacity(0.85))
            Text(initials)
                .font(.system(size: size * 0.27, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white)
                .offset(y: -size * 0.04)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(0.45), radius: 6, x: 0, y: 4)
    }
}

/// Eticheta mica, rotunjita.
struct Pill: View {
    let icon: String?
    let text: String
    var color: Color = Color.white.opacity(0.12)
    var foreground: Color = Color.white.opacity(0.9)

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
            }
            Text(text)
                .lineLimit(1)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color, in: Capsule())
    }
}
