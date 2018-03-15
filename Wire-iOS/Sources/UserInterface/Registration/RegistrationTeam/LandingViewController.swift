//
// Wire
// Copyright (C) 2017 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import Foundation
import UIKit
import Cartography

@objc protocol LandingViewControllerDelegate {
    func landingViewControllerDidChooseCreateAccount()
    func landingViewControllerDidChooseCreateTeam()
    func landingViewControllerDidChooseLogin()
}

/// Landing screen for choosing create team or personal account
final class LandingViewController: UIViewController {
    weak var delegate: LandingViewControllerDelegate?

    private let tracker = AnalyticsTracker(context: AnalyticsContextRegistrationEmail)

    fileprivate var device: DeviceProtocol

    // MARK: - UI styles

    static let semiboldFont = FontSpec(.large, .semibold).font!
    static let regularFont = FontSpec(.normal, .regular).font!

    static let buttonTitleAttribute: [String: Any] = {
        let alignCenterStyle = NSMutableParagraphStyle()
        alignCenterStyle.alignment = NSTextAlignment.center

        return [NSForegroundColorAttributeName: UIColor.Team.textColor, NSParagraphStyleAttributeName: alignCenterStyle, NSFontAttributeName: semiboldFont]
    }()

    static let buttonSubtitleAttribute: [String: Any] = {
        let alignCenterStyle = NSMutableParagraphStyle()
        alignCenterStyle.alignment = NSTextAlignment.center
        alignCenterStyle.paragraphSpacingBefore = 4

        let lightFont = FontSpec(.normal, .light).font!

        return [NSForegroundColorAttributeName: UIColor.Team.textColor, NSParagraphStyleAttributeName: alignCenterStyle, NSFontAttributeName: lightFont]
    }()

    // MARK: - constraints for iPad

    private var logoAlignTop: NSLayoutConstraint!
    private var loginButtonAlignBottom: NSLayoutConstraint!
    private var loginHintAlignTop: NSLayoutConstraint!
    private var headlineAlignBottom: NSLayoutConstraint!

    // MARK: - subviews

    let logoView: UIImageView = {
        let image = UIImage(named: "wire-logo-black")!
        let imageView = UIImageView(image: image)
        imageView.contentMode = .center
        imageView.tintColor = UIColor.Team.textColor
        return imageView
    }()

    let headline: UILabel = {
        let label = UILabel()
        label.text = "landing.title".localized
        label.font = LandingViewController.regularFont
        label.textColor = UIColor.Team.subtitleColor
        label.setContentCompressionResistancePriority(UILayoutPriorityRequired, for: .horizontal)
        return label
    }()

    let headlineStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.distribution = .fillProportionally
        stackView.alignment = .center
        stackView.spacing = 16
        stackView.axis = .vertical

        return stackView
    }()

    let buttonStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.distribution = .fillEqually
        stackView.spacing = 24
        stackView.axis = .vertical

        return stackView
    }()

    let createAccountButton: LandingButton = {
        let button = LandingButton(title: createAccountButtonTitle, icon: .selfProfile, iconBackgroundColor: UIColor.Team.createAccountBlue)
        button.accessibilityIdentifier = "CreateAccountButton"
        button.addTarget(self, action: #selector(LandingViewController.createAccountButtonTapped(_:)), for: .touchUpInside)

        return button
    }()

    let createTeamButton: LandingButton = {
        let button = LandingButton(title: createTeamButtonTitle, icon: .team, iconBackgroundColor: UIColor.Team.createTeamGreen)
        button.accessibilityIdentifier = "CreateTeamButton"
        button.addTarget(self, action: #selector(LandingViewController.createTeamButtonTapped(_:)), for: .touchUpInside)

        return button
    }()

    let headerContainerView = UIView()

    let loginHintsLabel: UILabel = {
        let label = UILabel()
        label.text = "landing.login.hints".localized
        label.font = LandingViewController.regularFont
        label.textColor = UIColor.Team.subtitleColor

        return label
    }()

    let loginButton: UIButton = {
        let button = UIButton()
        button.setTitle("landing.login.button.title".localized, for: .normal)
        button.accessibilityIdentifier = "LoginButton"
        button.setTitleColor(UIColor.Team.textColor, for: .normal)
        button.titleLabel?.font = LandingViewController.semiboldFont

        button.addTarget(self, action: #selector(LandingViewController.loginButtonTapped(_:)), for: .touchUpInside)

        return button
    }()
    
    let cancelButton: IconButton = {
        let button = IconButton()
        button.setIcon(.cancel, with: .small, for: .normal)
        button.tintColor = .black
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityIdentifier = "CancelButton"
        button.addTarget(self, action: #selector(LandingViewController.cancelButtonTapped(_:)), for: .touchUpInside)
        return button
    }()

    /// init method for injecting mock device
    ///
    /// - Parameter device: Provide this param for testing only
    init(device: DeviceProtocol = UIDevice.current) {
        self.device = device

        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tracker?.tagOpenedLandingScreen()

        self.view.backgroundColor = UIColor.Team.background

        [headerContainerView, buttonStackView, loginHintsLabel, loginButton].forEach(view.addSubview)

        [logoView, headline].forEach(headlineStackView.addArrangedSubview)
        [headlineStackView, cancelButton].forEach(headerContainerView.addSubview)
        
        [createAccountButton, createTeamButton].forEach() { button in
            buttonStackView.addArrangedSubview(button)
        }

        self.createConstraints()
        self.configureAccessibilityElements()

        updateStackViewAxis()
        updateConstraintsForIPad()
        
        cancelButton.isHidden = SessionManager.shared?.firstAuthenticatedAccount == nil

        let cancelButtonInsets = 44 - UIImage.size(for: .tiny)
        cancelButton.contentEdgeInsets = UIEdgeInsetsMake(cancelButtonInsets, cancelButtonInsets, cancelButtonInsets, cancelButtonInsets)

        NotificationCenter.default.addObserver(
            forName: AccountManagerDidUpdateAccountsNotificationName,
            object: SessionManager.shared?.accountManager,
            queue: nil) { _ in self.cancelButton.isHidden = SessionManager.shared?.firstAuthenticatedAccount == nil }
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        updateStackViewAxis()
        updateConstraintsForIPad()
    }

    private func createConstraints() {

        constrain(headlineStackView, logoView, headline, cancelButton, headerContainerView) {
            headlineStackView, logoView, headline, cancelButton, headerContainerView in

            ///reserver space for status bar(20pt)
            headlineStackView.top >= headerContainerView.top + 36
            logoAlignTop = headlineStackView.top == headerContainerView.top + 72 ~ 500.0
            headlineStackView.centerX == headerContainerView.centerX
            logoView.width == 96
            logoView.height == 31

            headline.height >= 18
            headlineStackView.bottom <= headerContainerView.bottom - 16
            
            cancelButton.top == headerContainerView.top + (16 + 20)
            cancelButton.trailing == headerContainerView.trailing - 16
            cancelButton.width == 44
            cancelButton.height == cancelButton.width

            if UIDevice.current.userInterfaceIdiom == .pad {
                headlineAlignBottom = headlineStackView.bottom == headerContainerView.bottom - 80
            }
        }

        constrain(self.view, headerContainerView, buttonStackView) { selfView, headerContainerView, buttonStackView in

            headerContainerView.width == selfView.width
            headerContainerView.centerX == selfView.centerX
            headerContainerView.top == selfView.top

            buttonStackView.centerX == selfView.centerX
            buttonStackView.centerY == selfView.centerY

            headerContainerView.bottom == buttonStackView.top
        }

        constrain(self.view, buttonStackView, loginHintsLabel, loginButton) {
            selfView, buttonStackView, loginHintsLabel, loginButton in
            buttonStackView.bottom <= loginHintsLabel.top - 16

            loginHintsLabel.bottom == loginButton.top - 16
            loginHintsLabel.centerX == selfView.centerX
            if UIDevice.current.userInterfaceIdiom == .pad {
                loginHintAlignTop = loginHintsLabel.top == buttonStackView.bottom + 80
            }


            loginButton.top == loginHintsLabel.bottom + 4
            loginButton.centerX == selfView.centerX
            loginButton.height >= 44
            loginButton.width >= 44
            loginButtonAlignBottom = loginButton.bottom == selfView.bottomMargin - 32 ~ 500.0
        }

        [createAccountButton, createTeamButton].forEach() { button in
            button.setContentCompressionResistancePriority(UILayoutPriorityRequired, for: .vertical)
            button.setContentCompressionResistancePriority(UILayoutPriorityRequired, for: .horizontal)
        }
    }

    fileprivate func updateConstraintsForIPad() {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }

        switch self.traitCollection.horizontalSizeClass {
        case .compact:
            loginHintAlignTop.isActive = false
            headlineAlignBottom.isActive = false
            logoAlignTop.isActive = true
            loginButtonAlignBottom.isActive = true
        default:
            logoAlignTop.isActive = false
            loginButtonAlignBottom.isActive = false
            loginHintAlignTop.isActive = true
            headlineAlignBottom.isActive = true
        }
    }

    func updateStackViewAxis() {
        let userInterfaceIdiom = device.userInterfaceIdiom
        guard userInterfaceIdiom == .pad else { return }

        switch self.traitCollection.horizontalSizeClass {
        case .regular:
            buttonStackView.axis = .horizontal
        default:
            buttonStackView.axis = .vertical
        }
    }

    // MARK: - Accessibility

    private func configureAccessibilityElements() {

        logoView.isAccessibilityElement = false
        headline.isAccessibilityElement = false
        cancelButton.accessibilityLabel = "general.cancel".localized

        headlineStackView.isAccessibilityElement = true
        headlineStackView.accessibilityLabel = "landing.app_name".localized + "\n" + "landing.title".localized
        headlineStackView.accessibilityTraits = UIAccessibilityTraitHeader
        headlineStackView.shouldGroupAccessibilityChildren = true

        headerContainerView.accessibilityElements = [headlineStackView, cancelButton]

        createAccountButton.isAccessibilityElement = true
        createAccountButton.accessibilityLabel = (LandingViewController.createAccountButtonTitle.string)

        createTeamButton.isAccessibilityElement = true
        createTeamButton.accessibilityLabel = (LandingViewController.createTeamButtonTitle.string)

    }

    private static let createAccountButtonTitle: NSAttributedString = {
        let title = "landing.create_account.title".localized && LandingViewController.buttonTitleAttribute
        let subtitle = ("\n" + "landing.create_account.subtitle".localized) && LandingViewController.buttonSubtitleAttribute

        return title + subtitle
    }()

    private static let createTeamButtonTitle: NSAttributedString = {
        let title = "landing.create_team.title".localized && LandingViewController.buttonTitleAttribute
        let subtitle = ("\n" + "landing.create_team.subtitle".localized) && LandingViewController.buttonSubtitleAttribute

        return title + subtitle
    }()

    override func accessibilityPerformEscape() -> Bool {
        guard SessionManager.shared?.firstAuthenticatedAccount != nil else {
            return false
        }

        cancelButtonTapped(cancelButton)
        return true
    }

    // MARK: - Button tapped target

    @objc public func createAccountButtonTapped(_ sender: AnyObject!) {
        tracker?.tagOpenedUserRegistration()
        delegate?.landingViewControllerDidChooseCreateAccount()
    }

    @objc public func createTeamButtonTapped(_ sender: AnyObject!) {
        tracker?.tagOpenedTeamCreation()
        delegate?.landingViewControllerDidChooseCreateTeam()
    }

    @objc public func loginButtonTapped(_ sender: AnyObject!) {
        tracker?.tagOpenedLogin()
        delegate?.landingViewControllerDidChooseLogin()
    }
    
    @objc public func cancelButtonTapped(_ sender: AnyObject!) {
        guard let account = SessionManager.shared?.firstAuthenticatedAccount else { return }
        SessionManager.shared!.select(account)
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

}

