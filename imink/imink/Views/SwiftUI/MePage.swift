//
//  MePage.swift
//  imink
//
//  Created by Jone Wang on 2020/10/11.
//

import SwiftUI
import SDWebImageSwiftUI

struct MePage: View {
    
    @StateObject private var meViewModel = MeViewModel()
    
    @State var showLogoutAlert = false
    
    var udemaeData: [(LocalizedStringKey, SP2Player.Udemae)] {
        guard let player = meViewModel.records?.records.player else {
            return []
        }
        
        var data = [(LocalizedStringKey, SP2Player.Udemae)]()
        if let udemaeZones = player.udemaeZones, udemaeZones.name != nil {
            data.append(("splat_zones_title", udemaeZones))
        }
        if let udemaeTower = player.udemaeTower, udemaeTower.name != nil {
            data.append(("tower_control_title", udemaeTower))
        }
        if let udemaeRainmaker = player.udemaeRainmaker, udemaeRainmaker.name != nil {
            data.append(("rainmaker_title", udemaeRainmaker))
        }
        if let udemaeClam = player.udemaeClam, udemaeClam.name != nil {
            data.append(("clam_blitz_title", udemaeClam))
        }
        
        return data
    }
    
    var body: some View {
        NavigationView {
            
            List {
                Section {
                    HStack {
                        if let player = meViewModel.records?.records.player,
                           let nicknameAndIcon = meViewModel.nicknameAndIcons?.nicknameAndIcons.first {
                            VStack {
                                HStack(alignment: .top) {
                                    WebImage(url: nicknameAndIcon.avatarURL)
                                        .resizable()
                                        .frame(width: 60, height: 60)
                                        .background(Color.secondary)
                                        .clipShape(Capsule())
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(alignment: .lastTextBaseline) {
                                            Text(player.nickname)
                                                .sp2Font(size: 20, color: Color.primary)
                                                .minimumScaleFactor(0.5)
                                            
                                            Text("\(player.playerRank)")
                                                .sp2Font(size: 16, color: AppColor.spLightGreen)
                                            
                                            HStack(spacing: 0) {
                                            Text("★")
                                                .sp1Font(size: 18, color: AppColor.spYellow)
                                            
                                                Text("\(player.starRank)")
                                                .sp2Font(size: 16, color: Color.primary)
                                            }
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 0) {
                                            ForEach(udemaeData.indices) { index in
                                                let (gameMode, udemae) = udemaeData[index]
                                                
                                                HStack {
                                                    Text(gameMode)
                                                        .sp2Font(size: 13, color: Color.primary)
                                                    
                                                    HStack(alignment: .lastTextBaseline, spacing: 0) {
                                                        Text(udemae.name!)
                                                            .sp1Font(size: 16, color: AppColor.spPink)
                                                        if let sPlusNumber = udemae.sPlusNumber {
                                                            Text("\(sPlusNumber)")
                                                                .sp1Font(size: 12)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.leading, 4)
                                    }
                                }
                                .padding(.vertical)
                            }
                        } else {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
                
                Section {
                    makeRow(image: "chevron.left.slash.chevron.right", text: "me_source_code_title", link: URL(string: "https://github.com/JoneWang/imink"), color: .accentColor)
                    makeRow(image: "questionmark.circle", text: "me_faq_title", link: URL(string: "https://github.com/JoneWang/imink/wiki/FAQ"), color: .accentColor)
                    makeDetailRow(image: "tag", text: "me_version_title", detail: "\(Bundle.main.appVersionShort) (\(Bundle.main.appVersionLong))", color: .accentColor)
                }
                
                Section {
                    HStack {
                        Spacer()
                        
                        Text("me_logout_title")
                            .foregroundColor(.red)
                        
                        Spacer()
                    }
                    .onTapGesture {
                        showLogoutAlert = true
                    }
                    .alert(isPresented: $showLogoutAlert) {
                        Alert(
                            title: Text("me_logout_title"),
                            message: Text("Are you sure you want to logout?"),
                            primaryButton: .destructive(Text("button_yes_title"), action: {
                                AppUserDefaults.shared.user = nil
                            }),
                            secondaryButton: .cancel(Text("button_no_title"))
                        )
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle("tabbar_me_title", displayMode: .inline)
            .navigationBarHidden(false)
            
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    func makeRow(image: String,
                 text: LocalizedStringKey,
                 link: URL? = nil,
                 color: Color) -> some View {
        HStack {
            Image(systemName: image)
                .imageScale(.medium)
                .foregroundColor(color)
                .frame(width: 30)
            Group {
                if let link = link {
                    Link(text, destination: link)
                        .foregroundColor(.primary)
                } else {
                    Text(text)
                }
            }
            
            Spacer()
            Image(systemName: "chevron.right").imageScale(.medium)
        }
    }
    
    func makeDetailRow(image: String, text: LocalizedStringKey, detail: String, color: Color) -> some View {
        HStack {
            Image(systemName: image)
                .imageScale(.medium)
                .foregroundColor(color)
                .frame(width: 30)
            Text(text)
            Spacer()
            Text(detail)
                .foregroundColor(.gray)
                .font(.callout)
        }
    }
}

struct MePage_Previews: PreviewProvider {
    static var previews: some View {
        MePage()
            .preferredColorScheme(.dark)
        MePage()
    }
}
