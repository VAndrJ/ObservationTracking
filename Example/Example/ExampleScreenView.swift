//
//  ExampleScreenView.swift
//  Example
//
//  Created by VAndrJ on 19.08.2025.
//

import Observation
import ObservationTracking
import UIKit

@CancellableObservation(screen: true)
final class ExampleScreenView: BaseScreenView<ExampleViewModel> {
    private let counterLabel = UILabel()
    private let conditionLabel = UILabel()
    private let exampleLabel = UILabel()
    private let switchLabel = UILabel()
    private let completeCallLabel = UILabel().apply {
        $0.numberOfLines = 0
        $0.textAlignment = .center
    }
    private let trailingClosureLabel = UILabel().apply {
        $0.numberOfLines = 0
        $0.textAlignment = .center
    }
    private lazy var incrementButton = BaseButton(title: "Increment") { [weak self] in
        self?.viewModel.count += 1
    }
    private lazy var toggleSwitchButton = BaseButton(title: "Toggle switch value") { [weak self] in
        self?.viewModel.toggleSomeValue()
    }
    private lazy var stopTimerButton = BaseButton(title: "Stop timer observation") { [weak self] in
        self?.cancelObserveExampleLabelText()
    }
    private lazy var continueTimerButton = BaseButton(title: "Continue timer observation") { [weak self] in
        self?.observeExampleLabelText()
    }
    private lazy var stopAllButton = BaseButton(title: "Stop all observations") { [weak self] in
        self?.stopObservations()
    }
    private lazy var continueAllButton = BaseButton(title: "Continue all observations") { [weak self] in
        self?.startObservationsIfNeeded()
    }
    private lazy var pushNextScreenButton = BaseButton(title: "Push next screen") { [weak self] in
        guard let self else { return }

        push(screen: Example1ScreenView(viewModel: viewModel))
    }
    private lazy var containerStackView = UIStackView(
        arrangedSubviews: [
            counterLabel,
            incrementButton,
            conditionLabel,
            exampleLabel,
            switchLabel,
            completeCallLabel,
            trailingClosureLabel,
            toggleSwitchButton,
            stopTimerButton,
            continueTimerButton,
            stopAllButton,
            continueAllButton,
            pushNextScreenButton,
        ]
    ).apply {
        $0.axis = .vertical
        $0.spacing = 16
        $0.alignment = .center
    }
    private var counterChangeObservation: NSKeyValueObservation?
    private var exampleChangeObservation: NSKeyValueObservation?

    @StartObservations
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        print("ExampleScreenView will appear")
    }

    @StopObservations
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        print("ExampleScreenView did disappear")
    }

    override func addElements() {
        addAutolayoutSubview(containerStackView)

        NSLayoutConstraint.activate([
            containerStackView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16),
            containerStackView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
            containerStackView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
        ])
    }

    override func configure() {
        backgroundColor = .systemBackground
        exampleChangeObservation = exampleLabel.observe(
            \.text,
            options: [.initial, .new]
        ) { label, change in
            if let newValue = change.newValue {
                print("Timer label text changed to: \(newValue ?? "")")
            }
        }
        counterChangeObservation = counterLabel.observe(
            \.text,
            options: [.initial, .new]
        ) { label, change in
            if let newValue = change.newValue {
                print("Counter label text changed to: \(newValue ?? "")")
            }
        }
    }

    @ObservationTracking
    override func bind() {
        counterLabel.text = "Count: \(viewModel.count)"
        updateCounterAppearance(viewModel.count)

        conditionLabel.text = if viewModel.count.isMultiple(of: 2) {
            "The count is even"
        } else {
            "The count is odd"
        }

        if viewModel.count >= 5 {
            showHighCount()
        } else {
            showLowCount()
        }

        exampleLabel.text = viewModel.exampleString

        switchLabel.text = switch viewModel.someValue {
        case .hello: "Hello"
        case .bye: "bye!"
        }

        switch viewModel.someValue {
        case .hello:
            sayHello()
        case .bye:
            sayBye()
        }

        // The complete call is observed, so dependencies can appear in any argument or container.
        renderSummary(
            title: "\(viewModel.exampleString) #\(viewModel.count)",
            count: viewModel.count,
            style: .headline,
            items: [viewModel.exampleString, "Count: \(viewModel.count)"],
            metadata: ["source": viewModel.exampleString],
            pair: (viewModel.count, viewModel.someValue)
        )

        // A no-argument helper can establish dependencies through synchronous reads in its body.
        refreshSummaryAppearance()

        // Trailing closures are preserved as part of the observed call.
        updateUsingClosures {
            trailingClosureLabel.text = "Closure value: \(viewModel.exampleString)"
        } completion: {
            trailingClosureLabel.textColor = switch viewModel.someValue {
            case .hello: .systemGreen
            case .bye: .systemOrange
            }
        }
    }

    private func updateCounterAppearance(_ count: Int) {
        counterLabel.textColor = count.isMultiple(of: 2) ? .systemBlue : .systemPurple
    }

    private func showHighCount() {
        conditionLabel.textColor = .systemRed
    }

    private func showLowCount() {
        conditionLabel.textColor = .secondaryLabel
    }

    private func sayHello() {
        switchLabel.textColor = .systemGreen
    }

    private func sayBye() {
        switchLabel.textColor = .systemOrange
    }

    private func renderSummary(
        title: String,
        count: Int,
        style: UIFont.TextStyle,
        items: [String],
        metadata: [String: String],
        pair: (Int, ExampleViewModel.SomeValue)
    ) {
        let pairValue = switch pair.1 {
        case .hello: "hello"
        case .bye: "bye"
        }
        completeCallLabel.font = .preferredFont(forTextStyle: style)
        completeCallLabel.text = """
            \(title)
            Items: \(items.joined(separator: ", "))
            Source: \(metadata["source"] ?? "")
            Pair: \(pair.0), \(pairValue); count: \(count)
            """
    }

    private func refreshSummaryAppearance() {
        completeCallLabel.textColor = viewModel.count.isMultiple(of: 2) ? .systemBlue : .systemPurple
    }

    private func updateUsingClosures(_ update: () -> Void, completion: () -> Void) {
        update()
        completion()
    }
}

@Observable
final class ExampleViewModel {
    enum SomeValue {
        case hello
        case bye
    }

    weak var store: Store?
    var count = 0
    var exampleString = ""
    var someValue: SomeValue = .hello

    init(store: Store) {
        self.store = store

        bind()
    }

    @ObservationTracking
    private func bind() {
        exampleString = store?.exampleString ?? ""
    }

    func toggleSomeValue() {
        someValue = switch someValue {
        case .hello: .bye
        case .bye: .hello
        }
    }
}

@Observable
final class Store {
    var exampleString = "Example String"
    private var timer: Timer?

    init() {
        startTimer()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.exampleString = "Random: \(Int.random(in: 0...100))"
            }
        }
    }

    isolated deinit {
        timer?.invalidate()
    }
}

final class Example1ScreenView: BaseScreenView<ExampleViewModel> {
    private let titleLabel = UILabel().apply {
        $0.text = "Previous Screen observation should stop (check console)"
        $0.numberOfLines = 0
        $0.textAlignment = .center
    }
    private let counterLabel = UILabel()
    private lazy var incrementButton = BaseButton(title: "Increment") { [weak self] in
        self?.viewModel.count += 1
    }
    private let exampleLabel = UILabel()
    private lazy var containerStackView = UIStackView(
        arrangedSubviews: [
            titleLabel,
            counterLabel,
            incrementButton,
            exampleLabel,
        ]
    ).apply {
        $0.axis = .vertical
        $0.spacing = 16
        $0.alignment = .center
    }

    override func addElements() {
        addAutolayoutSubview(containerStackView)

        NSLayoutConstraint.activate([
            containerStackView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16),
            containerStackView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
            containerStackView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
        ])
    }

    override func configure() {
        backgroundColor = .systemBackground
    }

    @ObservationTracking
    override func bind() {
        counterLabel.text = "Count: \(viewModel.count)"
        exampleLabel.text = viewModel.exampleString
    }
}
