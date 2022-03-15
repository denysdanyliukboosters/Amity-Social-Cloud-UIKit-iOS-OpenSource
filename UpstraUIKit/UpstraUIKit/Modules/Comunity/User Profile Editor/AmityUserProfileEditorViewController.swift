//
//  AmityEditUserProfileViewController.swift
//  AmityUIKit
//
//  Created by Nontapat Siengsanor on 15/10/2563 BE.
//  Copyright © 2563 Amity. All rights reserved.
//

import Photos
import UIKit

final public class AmityUserProfileEditorViewController: AmityViewController {
    
    @IBOutlet private weak var userAvatarView: AmityAvatarView!
    @IBOutlet private weak var avatarButton: UIButton!
    @IBOutlet private weak var cameraImageView: UIView!
    @IBOutlet private weak var displayNameLabel: UILabel!
    @IBOutlet private weak var displayNameCounterLabel: UILabel!
    @IBOutlet private weak var displayNameTextField: AmityTextField!
    @IBOutlet private weak var aboutLabel: UILabel!
    @IBOutlet private weak var aboutCounterLabel: UILabel!
    @IBOutlet private weak var aboutTextView: AmityTextView!
    @IBOutlet private weak var aboutSeparatorView: UIView!
    @IBOutlet private weak var displaynameSeparatorView: UIView!
    private var saveBarButtonItem: UIBarButtonItem!
    
    private var screenViewModel: AmityUserProfileEditorScreenViewModelType?
    
    private var isPhotoChanged = false
    private var isNameChanged = false
    private var isBioChanged = false
    private var isNeedToCheckChanges = false
    
    // To support reuploading image
    // use this variable to store a new image
    private var uploadingAvatarImage: UIImage?
    private var completion: (() -> Void)?
    
    private var isValueChanged: Bool {
        guard let user = screenViewModel?.dataSource.user else {
            return false
        }
        let isValueChanged = (displayNameTextField.text != user.displayName) || (aboutTextView.text != user.about) || (uploadingAvatarImage != nil)
        let isValueExisted = !displayNameTextField.text!.isEmpty
        return isValueChanged && isValueExisted
    }
    
    private enum Constant {
        static let maxCharactor: Int = 100
    }
    
    private init() {
        self.screenViewModel = AmityUserProfileEditorScreenViewModel()
        super.init(nibName: AmityUserProfileEditorViewController.identifier, bundle: AmityUIKitManager.bundle)
        
        title = AmityLocalizedStringSet.editUserProfileTitle.localizedString
        screenViewModel?.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public static func make(completion: (() -> Void)?) -> AmityUserProfileEditorViewController {
        let controller = AmityUserProfileEditorViewController()
        controller.completion = completion
        return controller
    }
    
    // MARK: - view's life cycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupView()
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.isNeedToCheckChanges = true
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.completion?()
    }
    
    private func setupNavigationBar() {
        saveBarButtonItem = UIBarButtonItem(title: AmityLocalizedStringSet.General.save.localizedString, style: .done, target: self, action: #selector(saveButtonTap))
        saveBarButtonItem.isEnabled = false
        navigationItem.rightBarButtonItem = saveBarButtonItem
    }
    
    private func setupView() {
        // avatar
        userAvatarView.placeholder = AmityIconSet.defaultAvatar
        cameraImageView.backgroundColor = AmityColorSet.secondary.blend(.shade4)
        cameraImageView.layer.borderColor = AmityColorSet.backgroundColor.cgColor
        cameraImageView.layer.borderWidth = 1.0
        cameraImageView.layer.cornerRadius = 14.0
        cameraImageView.clipsToBounds = true
        
        // display name
        displayNameLabel.text = AmityLocalizedStringSet.editUserProfileDisplayNameTitle.localizedString + "*"
        displayNameLabel.font = AmityFontSet.title
        displayNameLabel.textColor = AmityColorSet.base
        displayNameCounterLabel.font = AmityFontSet.caption
        displayNameCounterLabel.textColor = AmityColorSet.base.blend(.shade1)
        displayNameTextField.delegate = self
        displayNameTextField.borderStyle = .none
        displayNameTextField.addTarget(self, action: #selector(textFieldEditingChanged), for: .editingChanged)
        displayNameTextField.maxLength = Constant.maxCharactor
        
        // about
        aboutLabel.text = AmityLocalizedStringSet.createCommunityAboutTitle.localizedString
        aboutLabel.font = AmityFontSet.title
        aboutLabel.textColor = AmityColorSet.base
        aboutCounterLabel.font = AmityFontSet.caption
        aboutCounterLabel.textColor = AmityColorSet.base.blend(.shade1)
        aboutTextView.customTextViewDelegate = self
        aboutTextView.maxCharacters = Constant.maxCharactor
        
        // separator
        aboutSeparatorView.backgroundColor = AmityColorSet.secondary.blend(.shade4)
        displaynameSeparatorView.backgroundColor = AmityColorSet.secondary.blend(.shade4)
        
        updateViewState()
    }
    
    @objc private func saveButtonTap() {
        view.endEditing(true)
        AmityEventHandler.shared.trackCommunitySaveProfile(name: String(self.isNameChanged), bio: String(self.isBioChanged), photo: String(self.isPhotoChanged))
        // Update display name and about
        screenViewModel?.action.update(displayName: displayNameTextField.text ?? "", about: aboutTextView.text ?? "")
        self.isBioChanged = false
        self.isNameChanged = false
        self.isPhotoChanged = false
        // Update user avatar
        if let avatar = uploadingAvatarImage {
            userAvatarView.state = .loading
            screenViewModel?.action.update(avatar: avatar) { [weak self] success in
                if success {
                    AmityHUD.show(.success(message: AmityLocalizedStringSet.HUD.successfullyUpdated.localizedString))
                    self?.userAvatarView.image = avatar
                } else {
                    AmityHUD.show(.error(message: AmityLocalizedStringSet.HUD.somethingWentWrong.localizedString))
                }
                self?.userAvatarView.state = .idle
                self?.uploadingAvatarImage = nil
                self?.updateViewState()
            }
        } else {
            // when there is no image update
            // directly show success message after updated
            AmityHUD.show(.success(message: AmityLocalizedStringSet.HUD.successfullyUpdated.localizedString))
        }
    }
    
    @IBAction private func avatarButtonTap(_ sender: Any) {
        view.endEditing(true)
        // Show camera
        var cameraOption = TextItemOption(title: AmityLocalizedStringSet.General.camera.localizedString)
        cameraOption.completion = { [weak self] in
            self?.presentMediaPickerCamera()
        }
        
        // Show image picker
        var galleryOption = TextItemOption(title: AmityLocalizedStringSet.General.imageGallery.localizedString)
        galleryOption.completion = { [weak self] in
            let imagePicker = AmityImagePickerController(selectedAssets: [])
            imagePicker.settings.theme.selectionStyle = .checked
            imagePicker.settings.fetch.assets.supportedMediaTypes = [.image]
            imagePicker.settings.selection.max = 1
            imagePicker.settings.selection.unselectOnReachingMax = true
            
            self?.presentImagePicker(imagePicker, select: nil, deselect: nil, cancel: nil, finish: { assets in
                guard let asset = assets.first else { return }
                asset.getImage { result in
                    switch result {
                    case .success(let image):
                        self?.handleImage(image)
                    case .failure:
                        break
                    }
                }
            })
        }
        
        let bottomSheet = BottomSheetViewController()
        let contentView = ItemOptionView<TextItemOption>()
        contentView.configure(items: [cameraOption, galleryOption], selectedItem: nil)
        contentView.didSelectItem = { _ in
            bottomSheet.dismissBottomSheet()
        }
        
        bottomSheet.sheetContentView = contentView
        bottomSheet.isTitleHidden = true
        bottomSheet.modalPresentationStyle = .overFullScreen
        present(bottomSheet, animated: false, completion: nil)
    }
    
    @objc private func textFieldEditingChanged(_ textView: AmityTextView) {
        updateViewState()
    }
    
    private func handleImage(_ image: UIImage?) {
        uploadingAvatarImage = image
        userAvatarView.image = image
        updateViewState()
    }
    
    private func updateViewState() {
        saveBarButtonItem?.isEnabled = isValueChanged
        
        if self.isNeedToCheckChanges {
            if displayNameCounterLabel?.text != "\(displayNameTextField.text?.count ?? 0)/\(displayNameTextField.maxLength)" {
                self.isNameChanged = true
            }
            if aboutCounterLabel?.text != "\(aboutTextView.text.utf16.count)/\(aboutTextView.maxCharacters)" {
                self.isBioChanged = true
            }
        }
        
        displayNameCounterLabel?.text = "\(displayNameTextField.text?.count ?? 0)/\(displayNameTextField.maxLength)"
        aboutCounterLabel?.text = "\(aboutTextView.text.utf16.count)/\(aboutTextView.maxCharacters)"
    }
    
    private func showCameraPicker() {
        let cameraPicker = UIImagePickerController()
        cameraPicker.sourceType = .camera
        // Currently users can only select one media type when create a post.
        // After users choose the media, we will not `presentAskMediaTypeDialogue` after that.
        // We automatically choose media type based on last media pick.
        cameraPicker.delegate = self
        self.present(cameraPicker, animated: true, completion: nil)
    }
    
    private func presentMediaPickerCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.showCameraPicker()
        case .notDetermined:
            AmityEventHandler.shared.trackCommunityViewCameraRequest()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { [weak self] granted in
                DispatchQueue.main.async {
                    AmityEventHandler.shared.trackCommunityClickCameraRequest(access: granted ? "authorized" : "denied")
                    if granted {
                        self?.showCameraPicker()
                    }
                }
            })
        case .denied, .restricted:
            DispatchQueue.main.async {
                AmityEventHandler.shared.trackCommunityViewCameraReminder()
                self.presentAlertController()
            }
        }
    }

    private func presentAlertController() {
        let alertController = UIAlertController (title: AmityUIKitManagerInternal.shared.cameraPermissionDeniedText, message: "", preferredStyle: .alert)

        let settingsAction = UIAlertAction(title: AmityUIKitManagerInternal.shared.settingsString, style: .default) { (_) -> Void in

            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                return
            }

            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                    print("Settings opened: \(success)") // Prints true
                })
            }
        }
        alertController.addAction(settingsAction)
        let cancelAction = UIAlertAction(title: AmityUIKitManagerInternal.shared.cancelString, style: .default, handler: nil)
        alertController.addAction(cancelAction)

        self.present(alertController, animated: true, completion: nil)
    }

}

extension AmityUserProfileEditorViewController: AmityUserProfileEditorScreenViewModelDelegate {
    
    func screenViewModelDidUpdate(_ viewModel: AmityUserProfileEditorScreenViewModelType) {
        guard let user = screenViewModel?.dataSource.user else { return }
        
        displayNameTextField?.text = user.displayName
        aboutTextView?.text = user.about
        
        if let image = uploadingAvatarImage {
            // While uploading avatar, view model will get call once with an old image.
            // To prevent image view showing an old image, checking if it nil here.
            userAvatarView.image = image
        } else {
            userAvatarView?.setImage(withImageURL: user.avatarURL, placeholder: AmityIconSet.defaultAvatar)
        }
        
        updateViewState()
    }
    
}

extension AmityUserProfileEditorViewController: UITextFieldDelegate {
    
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return displayNameTextField.verifyFields(shouldChangeCharactersIn: range, replacementString: string)
    }
    
}

extension AmityUserProfileEditorViewController: AmityTextViewDelegate {
    
    public func textViewDidChange(_ textView: AmityTextView) {
        updateViewState()
    }
    
}

extension AmityUserProfileEditorViewController: UIImagePickerControllerDelegate & UINavigationControllerDelegate {
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true) { [weak self] in
            let image = info[.originalImage] as? UIImage
            self?.isPhotoChanged = true
            self?.handleImage(image)
        }
    }
    
}
