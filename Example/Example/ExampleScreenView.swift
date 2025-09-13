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
    private let exampleLabel = UILabel()
    private lazy var incrementButton = BaseButton(title: "Increment") { [weak self] in
        self?.viewModel.count += 1
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
            exampleLabel,
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

    override func addElements() {
        addAutolayoutSubview(containerStackView)

        NSLayoutConstraint.activate([
            containerStackView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16),
            containerStackView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
            containerStackView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
        ])
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        print("ExampleScreenView did disappear")
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
        exampleLabel.text = viewModel.exampleString
    }
}

@Observable
final class ExampleViewModel {
    weak var store: Store?
    var count = 0
    var exampleString = ""

    init(store: Store) {
        self.store = store

        bind()
    }

    @ObservationTracking
    private func bind() {
        exampleString = store?.exampleString ?? ""
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
