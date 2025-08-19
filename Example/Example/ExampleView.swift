//
//  ExampleView.swift
//  Example
//
//  Created by VAndrJ on 19.08.2025.
//

import Observation
import ObservationTracking
import UIKit

final class ExampleView: BaseView<ExampleViewModel> {
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private lazy var actionButton = UIButton(type: .system).apply {
        $0.setTitle("Increment", for: .normal)
        $0.addAction(
            UIAction { [weak self] _ in
                self?.viewModel.count += 1
            },
            for: .touchUpInside
        )
    }

    override func addElements() {
        addAutolayoutSubviews(titleLabel, descriptionLabel, actionButton)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            actionButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            actionButton.centerXAnchor.constraint(equalTo: centerXAnchor),

            descriptionLabel.topAnchor.constraint(equalTo: actionButton.bottomAnchor, constant: 16),
            descriptionLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
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
