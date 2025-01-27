//
//  AmityUserProfileViewController.swift
//  AmityUIKit
//
//  Created by Nontapat Siengsanor on 29/9/2563 BE.
//  Copyright © 2563 Amity. All rights reserved.
//

import UIKit
import AmitySDK

public struct AmityUserProfilePageSettings {
    
    public let shouldChatButtonHide: Bool
    
    public init(shouldChatButtonHide: Bool = true) {
        self.shouldChatButtonHide = shouldChatButtonHide
    }
    
}

/// User settings
public final class AmityUserProfilePageViewController: AmityProfileViewController {
    
    // MARK: - Properties
    
    private var settings: AmityUserProfilePageSettings!
    private var header: AmityUserProfileHeaderViewController!
    private var bottom: AmityUserProfileBottomViewController!
//    private let postButton: AmityFloatingButton = AmityFloatingButton()
    private var screenViewModel: AmityUserProfileScreenViewModelType!
    // MARK: - Initializer
    
    public static func make(withUserId userId: String, sourceType: String, settings: AmityUserProfilePageSettings = AmityUserProfilePageSettings()) -> AmityUserProfilePageViewController {
        
        let viewModel: AmityUserProfileScreenViewModelType = AmityUserProfileScreenViewModel(userId: userId)
        
        let vc = AmityUserProfilePageViewController()
        vc.header = AmityUserProfileHeaderViewController.make(withUserId: userId, sourceType: sourceType, settings: settings)
        vc.bottom = AmityUserProfileBottomViewController.make(withUserId: userId)
        vc.screenViewModel = viewModel
        
        return vc
    }
    
    // MARK: - View's life cycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
//        setupView()
        setupNavigationItem()
        setupViewModel()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.setBackgroundColor(with: .white)
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.reset()
    }
    
    // MARK: - Private functions
    
//    private func setupView() {
//        guard self.isPostButtonShowed else { return }
//        postButton.image = AmityIconSet.iconCreatePost
//        postButton.add(to: view, position: .bottomRight)
//        postButton.actionHandler = { [weak self] _ in
//            guard let strongSelf = self else { return }
//            AmityEventHandler.shared.createPostBeingPrepared(from: strongSelf, postTarget: .myFeed)
//        }
//        postButton.isHidden = !screenViewModel.isCurrentUser
//    }
    
    private func setupNavigationItem() {
        let item = UIBarButtonItem(image: AmityIconSet.iconOption, style: .plain, target: self, action: #selector(optionTap))
        item.tintColor = AmityColorSet.base
        navigationItem.rightBarButtonItem = item
    }
    
    private func setupViewModel() {
        screenViewModel.delegate = self
    }
    
    // MARK: - AmityProfileDataSource
    override func headerViewController() -> UIViewController {
        return header
    }
    
    override func bottomViewController() -> UIViewController & AmityProfilePagerAwareProtocol {
        return bottom
    }
    
    override func minHeaderHeight() -> CGFloat {
        return topInset
    }
}

private extension AmityUserProfilePageViewController {
    @objc func optionTap() {
        let vc = AmityUserSettingsViewController.make(withUserId: screenViewModel.dataSource.userId)
        navigationController?.pushViewController(vc, animated: true)
    }
}

extension AmityUserProfilePageViewController: AmityUserProfileScreenViewModelDelegate {
    func screenViewModel(_ viewModel: AmityUserProfileScreenViewModelType, failure error: AmityError) {
        switch error {
        case .unknown:
            AmityHUD.show(.error(message: AmityLocalizedStringSet.HUD.somethingWentWrong.localizedString))
        default:
            break
        }
    }
}
