import KsApi
import Library
import MessageUI
import Prelude
import SafariServices
import UIKit

internal final class BetaToolsViewController: UITableViewController {
  private let viewModel: BetaToolsViewModelType = BetaToolsViewModel()

  // MARK: - Properties

  private let betaFeedbackButton = UIButton(type: .custom)
  private var betaToolsData: BetaToolsData?
  private let helpViewModel: HelpViewModelType = HelpViewModel()

  internal static func instantiate() -> BetaToolsViewController {
    return BetaToolsViewController.init(nibName: nil, bundle: nil)
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    _ = self.tableView
      |> \.dataSource .~ self

    self.configureFooterView()
    self.betaFeedbackButton.addTarget(
      self, action: #selector(self.betaFeedbackButtonTapped),
      for: .touchUpInside
    )

    self.viewModel.inputs.viewDidLoad()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    self.tableView.ksr_sizeHeaderFooterViewsToFit()
  }

  override func bindStyles() {
    _ = self.navigationController
      ?|> UINavigationController.lens.isNavigationBarHidden .~ false

    _ = self.betaFeedbackButton
      |> greenButtonStyle
      |> UIButton.lens.title(for: .normal) .~ "Submit feedback for beta"
  }

  override func bindViewModel() {
    self.viewModel.outputs.reloadWithData
      .observeForUI()
      .observeValues { [weak self] data in
        self?.betaToolsData = data

        self?.tableView.reloadData()
      }

    self.viewModel.outputs.goToPushNotificationTools
      .observeForControllerAction()
      .observeValues { [weak self] in
        self?.goToDebugPushNotifications()
      }

    self.viewModel.outputs.goToFeatureFlagTools
      .observeForControllerAction()
      .observeValues { [weak self] in
        self?.goToFeatureFlagTools()
      }

    self.viewModel.outputs.goToBetaFeedback
      .observeForControllerAction()
      .observeValues { [weak self] in
        self?.goToBetaFeedback()
      }

    self.viewModel.outputs.showChangeEnvironmentSheetWithSourceViewIndex
      .observeForControllerAction()
      .observeValues { [weak self] index in
        self?.showEnvironmentActionSheet(sourceViewIndex: index)
      }

    self.viewModel.outputs.showChangeLanguageSheetWithSourceViewIndex
      .observeForControllerAction()
      .observeValues { [weak self] index in
        self?.showLanguageActionSheet(sourceViewIndex: index)
      }

    self.viewModel.outputs.updateLanguage
      .observeForControllerAction()
      .observeValues { [weak self] language in
        self?.updateLanguage(language: language)
      }

    self.viewModel.outputs.updateEnvironment
      .observeForControllerAction()
      .observeValues { [weak self] environment in
        self?.updateEnvironment(environment: environment)
      }

    self.viewModel.outputs.logoutWithParams
      .observeForControllerAction()
      .observeValues { [weak self] in
        self?.logoutAndDismiss(params: $0)
      }

    self.viewModel.outputs.showMailDisabledAlert
      .observeForControllerAction()
      .observeValues { [weak self] in
        self?.showMailDisabledAlert()
      }
  }

  // MARK: - Selectors

  @objc func betaFeedbackButtonTapped() {
    self.viewModel.inputs.betaFeedbackButtonTapped(canSendMail: MFMailComposeViewController.canSendMail())
  }

  @objc func doneTapped() {
    self.navigationController?.popViewController(animated: true)
  }

  // MARK: Private Helper Functions

  private func configureFooterView() {
    let containerView = UIView(frame: .zero)

    _ = self.tableView
      |> \.tableFooterView .~ containerView

    _ = (self.betaFeedbackButton, containerView)
      |> ksr_addSubviewToParent()
      |> ksr_constrainViewToMarginsInParent()

    let widthConstraint = self.betaFeedbackButton.widthAnchor
      .constraint(equalTo: self.tableView.layoutMarginsGuide.widthAnchor)
      |> \.priority .~ .defaultHigh

    let heightConstraint = self.betaFeedbackButton.heightAnchor
      .constraint(greaterThanOrEqualToConstant: Styles.minTouchSize.height)
      |> \.priority .~ .defaultHigh

    NSLayoutConstraint.activate([widthConstraint, heightConstraint])
  }

  private func goToDebugPushNotifications() {
    self.navigationController?.pushViewController(
      Storyboard.DebugPushNotifications.instantiate(DebugPushNotificationsViewController.self),
      animated: true
    )
  }

  private func goToFeatureFlagTools() {
    let featureFlagToolsViewController = FeatureFlagToolsViewController.insantiate()

    self.navigationController?.pushViewController(featureFlagToolsViewController, animated: true)
  }

  private func showLanguageActionSheet(sourceViewIndex: Int) {
    guard let sourceView = self.tableView
      .cellForRow(at: IndexPath(row: sourceViewIndex, section: 0))?.detailTextLabel else {
      return
    }

    let alert = UIAlertController.alert(
      title: "Change Language",
      preferredStyle: .actionSheet,
      sourceView: sourceView
    )

    Language.allLanguages.forEach { language in
      alert.addAction(
        UIAlertAction(title: language.displayString, style: .default) { [weak self] _ in
          self?.viewModel.inputs.setCurrentLanguage(language)
        }
      )
    }

    alert.addAction(
      UIAlertAction.init(title: "Cancel", style: .cancel)
    )

    self.present(alert, animated: true, completion: nil)
  }

  private func showEnvironmentActionSheet(sourceViewIndex: Int) {
    guard let sourceView = self.tableView
      .cellForRow(at: IndexPath(row: sourceViewIndex, section: 0))?.detailTextLabel else {
      return
    }

    let alert = UIAlertController.alert(
      title: "Change Environment",
      preferredStyle: .actionSheet,
      sourceView: sourceView
    )

    EnvironmentType.allCases.forEach { environment in
      alert.addAction(UIAlertAction(title: environment.rawValue, style: .default) { [weak self] _ in
        self?.viewModel.inputs.setEnvironment(environment)
      })
    }

    alert.addAction(
      UIAlertAction.init(title: "Cancel", style: .cancel)
    )

    self.present(alert, animated: true, completion: nil)
  }

  private func updateLanguage(language: Language) {
    AppEnvironment.updateLanguage(language)

    NotificationCenter.default.post(
      name: Notification.Name.ksr_userLocalePreferencesChanged,
      object: nil,
      userInfo: nil
    )

    self.navigationController?.popViewController(animated: true)
  }

  private func updateEnvironment(environment: EnvironmentType) {
    let serverConfig = ServerConfig.config(for: environment)

    AppEnvironment.updateServerConfig(serverConfig)

    self.viewModel.inputs.didUpdateEnvironment()
  }

  private func goToBetaFeedback() {
    let userName = AppEnvironment.current.currentUser?.name ?? "Logged out user"
    let userId = AppEnvironment.current.currentUser?.id ?? 0
    let version = AppEnvironment.current.mainBundle.version
    let shortVersion = AppEnvironment.current.mainBundle.shortVersionString
    let device = UIDevice.current

    let controller = MFMailComposeViewController()
    controller.setToRecipients([Secrets.fieldReportEmail])
    controller.setSubject("Field report: ")
    controller.setMessageBody(
      "\(userName) | \(userId) | \(version) | \(shortVersion) | " +
        "\(device.systemVersion) | \(device.modelCode)\n\n" +
        "Describe the bug here. Attach images if it helps!\n" +
        "---------------------------\n\n\n\n\n\n",
      isHTML: false
    )

    controller.mailComposeDelegate = self
    self.present(controller, animated: true, completion: nil)
  }

  private func showMailDisabledAlert() {
    let alert = UIAlertController(
      title: "Cannot send mail",
      message: "Mail is disabled. Please set up mail and try again.",
      preferredStyle: .alert
    )

    alert.addAction(
      UIAlertAction.init(title: "Ok", style: .cancel)
    )

    self.present(alert, animated: true, completion: nil)
  }

  private func logoutAndDismiss(params _: DiscoveryParams) {
    AppEnvironment.logout()

    NotificationCenter.default.post(.init(name: .ksr_sessionEnded))
    // Refresh the discovery screens
    NotificationCenter.default.post(.init(name: .ksr_environmentChanged))

    self.navigationController?.popViewController(animated: true)
  }
}

// MARK: - UITableViewDelegate

extension BetaToolsViewController {
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let row = BetaToolsRow(rawValue: indexPath.row) else {
      return
    }

    self.viewModel.inputs.didSelectBetaToolsRow(row)

    tableView.deselectRow(at: indexPath, animated: true)
  }
}

// MARK: - UITableViewDataSource

extension BetaToolsViewController {
  override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
    return BetaToolsRow.allCases.count
  }

  override func numberOfSections(in _: UITableView) -> Int {
    return 1
  }

  override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let row = BetaToolsRow.init(rawValue: indexPath.row), let rowData = self.betaToolsData else {
      fatalError("Cannot create cell")
    }

    let cell = UITableViewCell(style: row.cellStyle, reuseIdentifier: nil)
      |> \.selectionStyle .~ row.selectionStyle

    if let imageName = row.rightIconImageName {
      let image = UIImage(named: imageName)

      _ = cell
        |> \.accessoryView .~ UIImageView(image: image)
    }

    _ = cell.textLabel
      ?|> titleLabelStyle
      ?|> \.text .~ row.titleText

    _ = cell.detailTextLabel
      ?|> detailLabelStyle
      ?|> \.text .~ row.detailText(from: rowData)

    return cell
  }
}

extension BetaToolsViewController: MFMailComposeViewControllerDelegate {
  internal func mailComposeController(
    _ controller: MFMailComposeViewController,
    didFinishWith result: MFMailComposeResult,
    error _: Error?
  ) {
    self.helpViewModel.inputs.mailComposeCompletion(result: result)
    controller.dismiss(animated: true, completion: nil)
  }
}

private let detailLabelStyle: LabelStyle = { label in
  label
    |> \.font .~ .ksr_headline(size: 15)
    |> \.textColor .~ .ksr_text_dark_grey_500
    |> \.lineBreakMode .~ .byWordWrapping
    |> \.textAlignment .~ .right
}

private let titleLabelStyle: LabelStyle = { label in
  label
    |> \.textColor .~ .ksr_soft_black
    |> \.font .~ .ksr_body()
}
