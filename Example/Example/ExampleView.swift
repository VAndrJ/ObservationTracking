//
//  ExampleView.swift
//  Example
//
//  Created by VAndrJ on 19.08.2025.
//

import Observation
import ObservationTracking
import UIKit

@CancellableObservation
final class ExampleView: BaseView<ExampleViewModel> {
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private lazy var actionButton = BaseButton(title: "Increment") { [weak self] in
        self?.viewModel.count += 1
    }
    private lazy var stopTimerButton = BaseButton(title: "Stop timer observation") { [weak self] in
        self?.cancelObserveDescriptionLabelText()
    }
    private lazy var continueTimerButton = BaseButton(title: "Continue timer observation") { [weak self] in
        self?.observeDescriptionLabelText()
    }
    private lazy var stopAllButton = BaseButton(title: "Stop all observations") { [weak self] in
        self?.stopObservations()
    }
    private lazy var continueAllButton = BaseButton(title: "Continue all observations") { [weak self] in
        self?.startObservationsIfNeeded()
    }

    override func addElements() {
        addAutolayoutSubviews(
            titleLabel,
            descriptionLabel,
            actionButton,
            stopTimerButton,
            continueTimerButton,
            stopAllButton,
            continueAllButton
        )

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 64),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            actionButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            actionButton.centerXAnchor.constraint(equalTo: centerXAnchor),

            descriptionLabel.topAnchor.constraint(equalTo: actionButton.bottomAnchor, constant: 16),
            descriptionLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            stopTimerButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 16),
            stopTimerButton.centerXAnchor.constraint(equalTo: centerXAnchor),

            continueTimerButton.topAnchor.constraint(equalTo: stopTimerButton.bottomAnchor, constant: 16),
            continueTimerButton.centerXAnchor.constraint(equalTo: centerXAnchor),

            stopAllButton.topAnchor.constraint(equalTo: continueTimerButton.bottomAnchor, constant: 16),
            stopAllButton.centerXAnchor.constraint(equalTo: centerXAnchor),

            continueAllButton.topAnchor.constraint(equalTo: stopAllButton.bottomAnchor, constant: 16),
            continueAllButton.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }

    override func configure() {
        backgroundColor = .systemBackground
    }

    @ObservationTracking
    override func bind() {
        titleLabel.text = "Count: \(viewModel.count)"
        descriptionLabel.text = viewModel.exampleString
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
