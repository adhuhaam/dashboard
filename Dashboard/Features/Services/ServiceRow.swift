//
//  ServiceItem.swift
//  Dashboard
//
//  Created by Patrick Gatewood on 9/11/19.
//  Copyright © 2019 Patrick Gatewood. All rights reserved.
//

import SwiftUI
import Combine

struct ServiceRow: View {
    @Environment(\.editMode) var editMode
    
    @EnvironmentObject var network: NetworkService
    @EnvironmentObject var settings: Settings
    
    @State private var isLoading: Bool = false
    @State private var hasAppeared = false
    @State private var disposables = Set<AnyCancellable>()
    @State private var serverResponse: Result<Int, URLError> = .failure(URLError(.unknown))
    @State private var lastResponseTime: TimeInterval?
    
    @ObservedObject var service: ServiceModel
    
    private let accessoryViewWidth: CGFloat = 80
    
    private var responseLabelText: String {
        guard let responseTime = lastResponseTime else { return "" }
        
        return "\(Int(responseTime * 1000)) ms"
    }
    
    // AnyView type-erasure: https://www.hackingwithswift.com/quick-start/swiftui/how-to-return-different-view-types
    private var accessoryView: AnyView {
        if isLoading {
            return AnyView(
                ActivityIndicatorView()
                    .frame(width: accessoryViewWidth, height: 50)
            )
        } else {
            return AnyView(statusView)
        }
    }
    
    private var statusView: AnyView {
        
        func statusMessageView(image: Image, message: String) -> AnyView {
            return AnyView(
                VStack(spacing: 10) {
                    accessoryImage(from: image)
                    
                    if $settings.showErrorCodes.wrappedValue == true {
                        Text(message)
                            .font(.caption)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: accessoryViewWidth)
            )
        }
        
        switch serverResponse {
        case .success(let statusCode):
            guard statusCode == 200 else {
                return statusMessageView(image: Image(systemName: "exclamationmark.circle.fill"), message: "\(statusCode)")
            }
            
            return statusMessageView(image: Image("check"), message: self.responseLabelText)
        case .failure(let error):
            return statusMessageView(image: Image(systemName: "exclamationmark.circle.fill"), message: error.shortLocalizedDescription)
        }
    }
    
    private func accessoryImage(from image: Image) -> some View {
        image
            .resizable()
            .scaledToFit()
            .frame(width: 80, height: 35)
            .foregroundColor(.red)
    }
    
    var body: some View {
        HStack {
            Image(uiImage: service.image)
                .resizable()
                .scaledToFill()
                .padding(10)
                .frame(width: 80, height: 50)
            
            Spacer()
            
            Text(service.name)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
            
            Spacer()
            
            if self.editMode?.wrappedValue == .inactive {
                accessoryView
                    .animation(.easeInOut)
            }
        }
        .frame(height: 90)
        .frame(minWidth: 0, maxWidth: .infinity)
        .onTapGesture {
            self.fetchServerStatus()
        }
        .onAppear {
            guard !self.hasAppeared else {
                return
            }
            
            self.hasAppeared = true
            self.fetchServerStatus()
        }
    }
    
    func fetchServerStatus() {
        guard self.editMode?.wrappedValue == .inactive else { return }
        
        self.isLoading = true
        let loadingStartDate = Date()
        
        self.network.fetchServerStatusCode(for: service.url)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    // TODO: have the persistence stack update this: the view should not be updating the persisted values.
                    // Instead, we can probably add a type that has the last online date and the response code to the model.
                    self.service.lastOnlineDate = Date()
                case .failure(let error):
                    self.service.lastOnlineDate = .distantPast
                    self.serverResponse = .failure(error)
                }
                
                self.finishLoading(startingDate: loadingStartDate)
            }, receiveValue: { statusCode in
                self.serverResponse = .success(statusCode)
            })
            .store(in: &disposables) // whoops, if we don't retain this cancellable object the network data task will be cancelled
    }
    
    private func finishLoading(startingDate: Date) {
        let timeSpentLoading = Date().timeIntervalSince(startingDate)
        let minimumLoadingTime: TimeInterval = 0.5
        let secondsToContinueLoading = abs(minimumLoadingTime - timeSpentLoading)
        self.lastResponseTime = timeSpentLoading
        print("starting date: \(startingDate), time spent loading: \(timeSpentLoading)")
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + secondsToContinueLoading) {
            self.isLoading = false
        }
    }
}

//#if DEBUG
//struct ServiceItem_Previews: PreviewProvider {
//    static var previews: some View {
//        return ServiceRow(name: "Test Service", url: "test.com", image: UIImage(named: "missing-image")!, statusImage: UIImage(named: "check")!, isLoading: false)
//    }
//}
//#endif


