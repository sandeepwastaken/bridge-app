import SwiftUI

enum Route: Hashable {
    case speak, translate, talk, phrases, read, words, settings, assist, voice, guide, captions, understand, overlay
    case controlSettings, builtInAccess, importantInformation, mission, sessionNumbers
    case call(String)
}

@MainActor
final class Router: ObservableObject {
    static let shared = Router()
    @Published var path: [Route] = []

    func open(_ route: Route) {
        path = [route]
    }
}

struct HomeView: View {
    @ObservedObject var router: Router
    @ObservedObject var settings: AppSettings
    @ObservedObject var access: AccessController
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize

    @AppStorage("bridge.profileName") private var profileName = ""

    var body: some View {
        GeometryReader { outer in
            content(top: outer.safeAreaInsets.top)
                .ignoresSafeArea(edges: .top)
        }
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func content(top: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "person.fill").font(.title2).foregroundStyle(Theme.onHeroControl)
                            .frame(width: 46, height: 46).background(Theme.heroControl, in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profileName.isEmpty ? greeting : "\(greeting), \(profileName)").font(.subheadline)
                            Text("How can I help?").font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
                        }.foregroundStyle(.white).shadow(color: .black.opacity(0.55), radius: 6, y: 1)
                        Spacer(minLength: 4)
                        Button { router.open(.settings) } label: {
                            Image(systemName: "gearshape").font(.title3).foregroundStyle(Theme.onHeroControl)
                                .frame(width: 46, height: 46).background(Theme.heroControl, in: Circle())
                        }.accessibilityLabel("Settings").accessibilityIdentifier("home.settings")
                            .accessTarget("settings", label: "Settings", order: 7) { router.open(.settings) }
                    }
                    .padding(22)
                    .padding(.top, 8 + top)
                    .padding(.bottom, 56)
                    .frame(maxWidth: .infinity, minHeight: 240 + top, alignment: .topLeading)
                    .background {
                        Image("BridgeHills").resizable().scaledToFill()
                            .overlay {
                                LinearGradient(stops: [.init(color: Color.black.opacity(0.55), location: 0),
                                                       .init(color: Color.black.opacity(typeSize.isAccessibilitySize ? 0.5 : 0.3), location: 0.55),
                                                       .init(color: Color.black.opacity(typeSize.isAccessibilitySize ? 0.35 : 0), location: 1)],
                                               startPoint: .top, endPoint: .bottom)
                            }
                    }
                    .clipped()
                    .padding(.horizontal, -Theme.gutter)
                VStack(spacing: 14) {
                    Button { router.open(.speak) } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "mic").font(.title).foregroundStyle(Theme.onAccent).frame(width: 64,height: 64).background(Theme.accent,in: Circle())
                            VStack(alignment: .leading,spacing: 5) {
                                Text("Speak for me").font(.title3.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                                Text("Your words, spoken clearly").font(.subheadline).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer(minLength: 0)
                        }.card(padding: 18)
                    }.buttonStyle(PressScaleStyle()).accessibilityIdentifier("home.speak")
                        .accessTarget("speak",label:"Speak for me",order:1) { router.open(.speak) }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: typeSize >= .xLarge ? 1 : 3), spacing: 12) {
                        feature("Translate", "Different languages", "character.bubble", .translate)
                        feature("Talk together", "Easier conversations", "person.2", .talk)
                        feature("Read with me", "Text, menus and more", "doc.text", .read)
                    }
                    VStack(alignment:.leading,spacing:10) {
                        Text("Quick phrases").font(.headline)
                        Button("Please give me a moment.") { router.open(.phrases) }.frame(minHeight:44)
                            .accessibilityIdentifier("home.phrases")
                            .accessTarget("phrase-moment", label: "Please give me a moment.", order: 3) { router.open(.phrases) }
                        Divider()
                        Button("Could you say that again?") { router.open(.phrases) }.frame(minHeight:44)
                            .accessTarget("phrase-again", label: "Could you say that again?", order: 3) { router.open(.phrases) }
                    }.frame(maxWidth:.infinity,alignment:.leading).card(padding:18)
                    Button { router.open(.assist) } label: {
                        HStack(spacing:12) {
                            Image("BridgeBuddy").resizable().scaledToFit().frame(width:120,height:92)
                            Text("A little help,\nwhen you need it.").font(.headline).foregroundStyle(Theme.textPrimary)
                            Spacer(minLength:0)
                        }.padding(.vertical, 8).padding(.trailing, 18)
                            .background(Theme.assistantCard,in:RoundedRectangle(cornerRadius:24))
                            .overlay(RoundedRectangle(cornerRadius:24).stroke(Theme.cardBorder,lineWidth:1))
                    }.buttonStyle(PressScaleStyle())
                        .accessTarget("assist", label: "A little help", order: 4) { router.open(.assist) }
                    if settings.control != .touch { handsFree }
                }.padding(.top,-42)
            }.padding(.horizontal,Theme.gutter).padding(.bottom,24).frame(maxWidth:900).frame(maxWidth:.infinity)
        }.accessScrolling().background(Theme.background)
    }

    private func feature(_ title:String,_ detail:String,_ symbol:String,_ route:Route) -> some View {
        Button { router.open(route) } label: {
            VStack(alignment:.leading,spacing:10) {
                Image(systemName:symbol).font(.title3)
                Text(title).font(.subheadline.weight(.semibold)).fixedSize(horizontal:false,vertical:true)
                Text(detail).font(.caption).foregroundStyle(Theme.textSecondary).fixedSize(horizontal:false,vertical:true)
                Spacer(minLength:0)
            }.foregroundStyle(Theme.textPrimary).frame(maxWidth:.infinity,minHeight:112,alignment:.leading).card(padding:12,radius:24)
        }.buttonStyle(PressScaleStyle()).accessibilityIdentifier("home.\(String(describing:route))")
            .accessTarget("feature-\(String(describing: route))", label: title, order: 2) { router.open(route) }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var handsFree: some View {
        let layout = typeSize >= .xxLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Space.sm))
            : AnyLayout(HStackLayout(spacing: Theme.Space.md))

        return layout {
            IconBadge(symbol: settings.control.symbol, color: Theme.badge, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(access.isPaused ? "Hands-free is paused" : "\(settings.control.title) is on")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text(access.isPaused
                     ? "Touch works. Press your switch to resume."
                     : "To use touch again, hold anywhere for 3 seconds.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            if typeSize < .xxLarge { Spacer(minLength: 4) }
            Button(access.isPaused ? "Resume" : "Pause") { access.isPaused.toggle() }
                .font(.headline)
                .frame(minWidth: 72, minHeight: 44)
                .frame(maxWidth: typeSize >= .xxLarge ? .infinity : nil, alignment: .leading)
                .accessTarget("pause", label: access.isPaused ? "Resume" : "Pause", order: 8) { access.isPaused.toggle() }
        }
        .card(padding: Theme.Space.md, radius: Theme.Radius.lg)
        .padding(.top, Theme.Space.sm)
    }
}
