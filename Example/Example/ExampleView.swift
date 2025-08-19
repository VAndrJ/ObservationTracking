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
        addAutolayoutSubviews(titleLabel, actionButton)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            actionButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            actionButton.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }

    override func configure() {
        backgroundColor = .systemBackground
    }

    @ObservationTracking
    override func bind() {
        titleLabel.text = "Count: \(viewModel.count)"
    }
}

@Observable
final class ExampleViewModel {
    var count = 0
}
